import 'package:flutter/material.dart';

import 'help_center_models.dart';
import 'help_center_store.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  String _category = 'All';
  List<HelpCenterTicket> _tickets = <HelpCenterTicket>[];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final tickets = await HelpCenterStore.loadTickets();
    if (!mounted) return;
    setState(() => _tickets = tickets);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  List<HelpFaqItem> get _filteredFaqs {
    final query = _searchController.text.trim().toLowerCase();
    return helpFaqItems.where((item) {
      final categoryMatch = _category == 'All' || item.category == _category;
      final queryMatch = query.isEmpty ||
          item.question.toLowerCase().contains(query) ||
          item.answer.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      return categoryMatch && queryMatch;
    }).toList();
  }

  Future<void> _openTicketSheet({String? category, String? subject}) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTicketSheet(initialCategory: category ?? 'General', initialSubject: subject ?? ''),
    );

    if (created == true) {
      await _loadTickets();
      if (mounted) _toast('Support ticket created.');
    }
  }

  Future<void> _clearTickets() async {
    await HelpCenterStore.clearTickets();
    await _loadTickets();
    if (mounted) _toast('Local ticket history cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final faqs = _filteredFaqs;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _HelpHeader(onBack: () => Navigator.pop(context), onCreateTicket: () => _openTicketSheet()),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _HelpHeroCard(onCreateTicket: () => _openTicketSheet(), onSafetyTap: () => _openTicketSheet(category: 'Safety', subject: 'Report a safety issue')),
                  const SizedBox(height: 12),
                  _HelpSearchField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _CategoryChips(selected: _category, onSelected: (value) => setState(() => _category = value)),
                  const SizedBox(height: 14),
                  _QuickActionsGrid(onActionTap: (action) => _openTicketSheet(category: action.category, subject: action.title)),
                  const SizedBox(height: 14),
                  _SectionTitle(title: 'Frequently asked questions', trailing: '${faqs.length} found'),
                  const SizedBox(height: 10),
                  if (faqs.isEmpty)
                    const _EmptyState(title: 'No help articles found', subtitle: 'Try another search or create a support ticket.')
                  else
                    ...faqs.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _FaqTile(item: item))),
                  const SizedBox(height: 14),
                  _SectionTitle(title: 'My support tickets', trailing: _tickets.isEmpty ? null : 'Clear', onTrailingTap: _tickets.isEmpty ? null : _clearTickets),
                  const SizedBox(height: 10),
                  if (_tickets.isEmpty)
                    const _EmptyState(title: 'No tickets yet', subtitle: 'Tickets created here are saved locally until backend support API is connected.')
                  else
                    ..._tickets.map((ticket) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TicketTile(ticket: ticket))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpHeader extends StatelessWidget {
  const _HelpHeader({required this.onBack, required this.onCreateTicket});

  final VoidCallback onBack;
  final VoidCallback onCreateTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538), size: 28)),
          const Expanded(child: Text('Help Centre', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4))),
          InkWell(
            onTap: onCreateTicket,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(999)),
              child: const Text('Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpHeroCard extends StatelessWidget {
  const _HelpHeroCard({required this.onCreateTicket, required this.onSafetyTap});

  final VoidCallback onCreateTicket;
  final VoidCallback onSafetyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _helpPanelDecoration(radius: 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 50, height: 50, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)])), child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 27)),
          const SizedBox(width: 12),
          const Expanded(child: Text('How can we help?', style: TextStyle(color: Color(0xFF251538), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
        ]),
        const SizedBox(height: 8),
        const Text('Find help for rooms, Inbox, profile, VIP/SVIP, payments, agency rules and safety. Create a ticket when you need support review.', style: TextStyle(color: Color(0xFF7B6A86), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _HeroButton(label: 'Contact support', icon: Icons.edit_note_rounded, filled: true, onTap: onCreateTicket)),
          const SizedBox(width: 10),
          Expanded(child: _HeroButton(label: 'Safety report', icon: Icons.shield_rounded, filled: false, onTap: onSafetyTap)),
        ]),
      ]),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.label, required this.icon, required this.filled, required this.onTap});

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: filled ? const Color(0xFF251538) : const Color(0xFFECE2D8)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: filled ? Colors.white : const Color(0xFF251538), size: 19),
          const SizedBox(width: 7),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: filled ? Colors.white : const Color(0xFF251538), fontSize: 12.5, fontWeight: FontWeight.w900))),
        ]),
      ),
    );
  }
}

class _HelpSearchField extends StatelessWidget {
  const _HelpSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search help articles',
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7B6A86)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF12C7B7))),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: helpCenterCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = helpCenterCategories[index];
          final active = category == selected;
          return InkWell(
            onTap: () => onSelected(category),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: active ? const Color(0xFF251538) : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? const Color(0xFF251538) : const Color(0xFFECE2D8))),
              child: Text(category, style: TextStyle(color: active ? Colors.white : const Color(0xFF4A2A63), fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.onActionTap});

  final ValueChanged<HelpQuickAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: helpQuickActions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55),
      itemBuilder: (context, index) {
        final action = helpQuickActions[index];
        return InkWell(
          onTap: () => onActionTap(action),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: _helpPanelDecoration(radius: 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(action.icon, color: action.color, size: 24),
              const Spacer(),
              Text(action.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(action.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing, this.onTrailingTap});

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final trailingText = trailing;
    return Row(children: [
      Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF251538), fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.3))),
      if (trailingText != null)
        InkWell(
          onTap: onTrailingTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(trailingText, style: const TextStyle(color: Color(0xFF6D5DF6), fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
    ]);
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});

  final HelpFaqItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _helpPanelDecoration(radius: 22),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF6D5DF6).withValues(alpha: 0.10), shape: BoxShape.circle), child: Icon(item.icon, color: const Color(0xFF6D5DF6), size: 20)),
        title: Text(item.question, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
        subtitle: Text(item.category, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11, fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [Text(item.answer, style: const TextStyle(color: Color(0xFF5E5268), fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700))],
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final HelpCenterTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _helpPanelDecoration(radius: 22),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0x1A12C7B7), shape: BoxShape.circle), child: const Icon(Icons.confirmation_number_rounded, color: Color(0xFF12C7B7), size: 21)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ticket.subject, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF251538), fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('${ticket.category} - ${ticket.status}', style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 11.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(ticket.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF5E5268), fontSize: 12, height: 1.25, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _helpPanelDecoration(radius: 22),
      child: Column(children: [
        const Icon(Icons.help_outline_rounded, color: Color(0xFF7B6A86), size: 32),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.3, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _CreateTicketSheet extends StatefulWidget {
  const _CreateTicketSheet({required this.initialCategory, required this.initialSubject});

  final String initialCategory;
  final String initialSubject;

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  late String _category = widget.initialCategory;
  late final TextEditingController _subjectController = TextEditingController(text: widget.initialSubject);
  final TextEditingController _messageController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();

    if (subject.length < 4) {
      _showLocalError('Add a clear subject.');
      return;
    }
    if (message.length < 12) {
      _showLocalError('Add more details so support can understand the issue.');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    await HelpCenterStore.saveTicket(
      HelpCenterTicket(
        id: 'VM-TKT-${now.millisecondsSinceEpoch}',
        category: _category,
        subject: subject,
        message: message,
        status: 'Open',
        createdAt: now,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _showLocalError(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFFE84C72), content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
    final categories = helpCenterCategories.where((item) => item != 'All').toList();
    if (!categories.contains(_category)) _category = categories.first;

    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFECE2D8))),
      child: SafeArea(top: false, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Create support ticket', style: TextStyle(color: Color(0xFF251538), fontSize: 20, fontWeight: FontWeight.w900))),
          IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _category,
          items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: (value) => setState(() => _category = value ?? _category),
          decoration: _ticketInputDecoration('Category'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _subjectController, maxLength: 60, decoration: _ticketInputDecoration('Subject').copyWith(counterText: '')),
        const SizedBox(height: 10),
        TextField(controller: _messageController, minLines: 4, maxLines: 6, maxLength: 500, decoration: _ticketInputDecoration('Details').copyWith(counterText: '')),
        const SizedBox(height: 12),
        InkWell(
          onTap: _saving ? null : _submit,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFF251538), borderRadius: BorderRadius.circular(18)),
            child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)) : const Text('Submit ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ),
      ]))),
    );
  }

  InputDecoration _ticketInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFFAF7F1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFECE2D8))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF12C7B7))),
    );
  }
}

BoxDecoration _helpPanelDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFECE2D8)),
    boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))],
  );
}
