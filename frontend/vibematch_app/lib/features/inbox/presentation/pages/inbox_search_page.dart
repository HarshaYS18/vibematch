import 'package:flutter/material.dart';

import '../../controllers/inbox_controller.dart';
import '../../models/inbox_models.dart';

class InboxSearchPage extends StatefulWidget {
  const InboxSearchPage({
    super.key,
    required this.controller,
    required this.onOpenConversation,
  });

  final InboxController controller;
  final ValueChanged<InboxConversation> onOpenConversation;

  @override
  State<InboxSearchPage> createState() => _InboxSearchPageState();
}

class _InboxSearchPageState extends State<InboxSearchPage> {
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
    final mutualResults = _results.where((item) => item.matchType == InboxSearchMatchType.mutualFollow).toList();
    final messageResults = _results.where((item) => item.matchType == InboxSearchMatchType.message).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _SearchHeader(
              controller: _searchController,
              onBackTap: () => Navigator.pop(context),
              onChanged: _onSearchChanged,
              onClearTap: _clearSearch,
            ),
            Expanded(
              child: query.isEmpty
                  ? const _SearchEmptyHint()
                  : _results.isEmpty
                      ? _NoSearchResults(query: query)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            _ResultSection(
                              title: 'Chats',
                              results: chatResults,
                              query: query,
                              onOpenConversation: widget.onOpenConversation,
                            ),
                            _ResultSection(
                              title: 'Mutual follows',
                              results: mutualResults,
                              query: query,
                              onOpenConversation: widget.onOpenConversation,
                            ),
                            _ResultSection(
                              title: 'Messages',
                              results: messageResults,
                              query: query,
                              onOpenConversation: widget.onOpenConversation,
                            ),
                          ],
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
      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F1),
        border: Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF251538)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Search chats or messages',
                hintStyle: const TextStyle(
                  color: Color(0xFF9B8CA5),
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7B6A86), size: 20),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: onClearTap,
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF7B6A86), size: 20),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.title,
    required this.results,
    required this.query,
    required this.onOpenConversation,
  });

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
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF7B6A86),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ...results.map(
            (result) => _SearchResultTile(
              result: result,
              query: query,
              onTap: () => onOpenConversation(result.conversation),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.query,
    required this.onTap,
  });

  final InboxSearchResult result;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final conversation = result.conversation;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: conversation.colors),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  conversation.avatarText,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        result.message?.time ?? conversation.time,
                        style: const TextStyle(
                          color: Color(0xFF9B8CA5),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _HighlightedPreview(text: result.preview, query: query),
                  const SizedBox(height: 3),
                  Text(
                    result.matchType.label,
                    style: const TextStyle(
                      color: Color(0xFF8C8198),
                      fontSize: 10.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF7A6B86),
          fontSize: 11.8,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final before = text.substring(0, index);
    final match = text.substring(index, index + query.length);
    final after = text.substring(index + query.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF7A6B86),
          fontSize: 11.8,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontWeight: FontWeight.w900,
            ),
          ),
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
    return const Center(
      child: Text(
        'Search chats, mutual follows, and message text',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF7B6A86),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
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
      child: Text(
        'No results for “$query”',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF7B6A86),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
