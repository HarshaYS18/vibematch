import 'package:flutter/material.dart';

import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';

class InboxSearchPage extends StatefulWidget {
  const InboxSearchPage({
    super.key,
    required this.controller,
    required this.onOpenConversation,
    this.onBackTap,
  });

  final InboxController controller;
  final ValueChanged<InboxConversation> onOpenConversation;
  final VoidCallback? onBackTap;

  @override
  State<InboxSearchPage> createState() => _InboxSearchPageState();
}

class _InboxSearchPageState extends State<InboxSearchPage> {
  static const _bg = Color(0xFFFAFAFA);
  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

  final TextEditingController _searchController = TextEditingController();
  List<InboxSearchResult> _results = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _results = widget.controller.searchInbox(value));
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final chatResults = _results.where((item) => item.matchType == InboxSearchMatchType.chat).toList();
    final friendResults = _results.where((item) => item.matchType == InboxSearchMatchType.mutualFollow).toList();
    final messageResults = _results.where((item) => item.matchType == InboxSearchMatchType.message).toList();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _searchController,
              onBackTap: widget.onBackTap ?? () => Navigator.pop(context),
              onChanged: _onSearchChanged,
              onClearTap: _clearSearch,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: query.isEmpty
                    ? const _SearchEmptyHint()
                    : _results.isEmpty
                        ? _NoSearchResults(query: query)
                        : ListView(
                            key: ValueKey(query),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              _ResultSection(title: 'Chats', results: chatResults, query: query, onOpenConversation: widget.onOpenConversation),
                              _ResultSection(title: 'Friends', results: friendResults, query: query, onOpenConversation: widget.onOpenConversation),
                              _ResultSection(title: 'Messages', results: messageResults, query: query, onOpenConversation: widget.onOpenConversation),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.onBackTap,
    required this.onChanged,
    required this.onClearTap,
  });

  final TextEditingController controller;
  final VoidCallback onBackTap;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 10),
      decoration: const BoxDecoration(color: _InboxSearchPageState._bg, border: Border(bottom: BorderSide(color: _InboxSearchPageState._line))),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded, color: _InboxSearchPageState._ink, size: 22),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              style: const TextStyle(color: _InboxSearchPageState._ink, fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(color: _InboxSearchPageState._muted, fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded, color: _InboxSearchPageState._muted, size: 20),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(onPressed: onClearTap, icon: const Icon(Icons.close_rounded, color: _InboxSearchPageState._muted, size: 20)),
                filled: true,
                fillColor: const Color(0xFFF1F1F3),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.results, required this.query, required this.onOpenConversation});

  final String title;
  final List<InboxSearchResult> results;
  final String query;
  final ValueChanged<InboxConversation> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 7),
            child: Text(title, style: const TextStyle(color: _InboxSearchPageState._muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _InboxSearchPageState._line)),
            child: Column(
              children: [
                for (var index = 0; index < results.length; index++) ...[
                  _SearchResultTile(result: results[index], query: query, onTap: () => onOpenConversation(results[index].conversation)),
                  if (index != results.length - 1) const Divider(height: 1, color: _InboxSearchPageState._line, indent: 64),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.query, required this.onTap});

  final InboxSearchResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final conversation = result.conversation;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: const Color(0xFFF1F1F3),
              child: Text(conversation.avatarText, style: const TextStyle(color: _InboxSearchPageState._ink, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _InboxSearchPageState._ink, fontSize: 13.8, fontWeight: FontWeight.w700))),
                      Text(result.message?.time ?? conversation.time, style: const TextStyle(color: _InboxSearchPageState._muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _HighlightedPreview(text: result.preview, query: query),
                  const SizedBox(height: 3),
                  Text(result.matchType.label, style: const TextStyle(color: _InboxSearchPageState._muted, fontSize: 10.4, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _InboxSearchPageState._muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _HighlightedPreview extends StatelessWidget {
  const _HighlightedPreview({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index < 0 || query.isEmpty) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _InboxSearchPageState._muted, fontSize: 12, fontWeight: FontWeight.w500));
    }

    final before = text.substring(0, index);
    final match = text.substring(index, index + query.length);
    final after = text.substring(index + query.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(color: _InboxSearchPageState._muted, fontSize: 12, fontWeight: FontWeight.w500),
        children: [
          TextSpan(text: before),
          TextSpan(text: match, style: const TextStyle(color: _InboxSearchPageState._blue, fontWeight: FontWeight.w800)),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _SearchEmptyHint extends StatelessWidget {
  const _SearchEmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFF1F1F3), shape: BoxShape.circle), child: const Icon(Icons.search_rounded, color: _InboxSearchPageState._muted, size: 30)),
          const SizedBox(height: 14),
          const Text('Search Inbox', style: TextStyle(color: _InboxSearchPageState._ink, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Find chats, friends, and messages.', textAlign: TextAlign.center, style: TextStyle(color: _InboxSearchPageState._muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFF1F1F3), shape: BoxShape.circle), child: const Icon(Icons.search_off_rounded, color: _InboxSearchPageState._muted, size: 30)),
          const SizedBox(height: 14),
          Text('No results for “$query”', textAlign: TextAlign.center, style: const TextStyle(color: _InboxSearchPageState._ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Try a name, message, or keyword.', textAlign: TextAlign.center, style: TextStyle(color: _InboxSearchPageState._muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
