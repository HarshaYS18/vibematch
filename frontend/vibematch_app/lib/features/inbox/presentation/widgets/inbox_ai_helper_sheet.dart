import 'package:flutter/material.dart';

import '../../data/inbox_ai_api_service.dart';

class InboxAiHelperSheet extends StatefulWidget {
  const InboxAiHelperSheet({
    super.key,
    required this.onSearch,
    required this.onOpenResult,
  });

  final Future<InboxAiSearchResponse> Function(String query) onSearch;
  final ValueChanged<InboxAiSearchResult> onOpenResult;

  @override
  State<InboxAiHelperSheet> createState() => _InboxAiHelperSheetState();
}

class _InboxAiHelperSheetState extends State<InboxAiHelperSheet> {
  final TextEditingController _queryController = TextEditingController();
  InboxAiSearchResponse? _response;
  bool _searching = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 2 || _searching) return;
    setState(() => _searching = true);
    try {
      final response = await widget.onSearch(query);
      if (mounted) setState(() => _response = response);
    } catch (error) {
      if (mounted) _toast(error.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF111114),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    final results = _response?.results ?? const <InboxAiSearchResult>[];
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 16 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEDEDEF)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF4F4F5),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF3797F0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Ask Inbox AI',
                      style: TextStyle(
                        color: Color(0xFF111114),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Search your own allowed chats by asking naturally. Private locked results stay hidden until unlocked.',
                style: TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Find room invite from yesterday',
                        hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w500,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFFEDEDEF),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFFEDEDEF),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFF3797F0),
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF71717A),
                          size: 20,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _searching ? null : _search,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF3797F0),
                      fixedSize: const Size(44, 44),
                    ),
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_response == null)
                const _HelperHint()
              else if (results.isEmpty)
                const _EmptyResult()
              else
                ...results.map(
                  (result) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ResultTile(
                      result: result,
                      onTap: () => widget.onOpenResult(result),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelperHint extends StatelessWidget {
  const _HelperHint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Try “show unread messages from friends” or “find recharge support update”.',
      style: TextStyle(
        color: Color(0xFF71717A),
        fontSize: 12,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No matching chats found.',
        style: TextStyle(
          color: Color(0xFF71717A),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final InboxAiSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEDEF)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: result.isLocked
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFEFF6FF),
              ),
              child: Icon(
                result.isLocked
                    ? Icons.lock_outline_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: result.isLocked
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF3797F0),
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111114),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    result.snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    result.matchReason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF3797F0),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB8B8C0),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
