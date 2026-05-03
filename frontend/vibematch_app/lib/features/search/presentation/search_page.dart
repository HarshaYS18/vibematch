import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../data/global_search_api_service.dart';
import '../models/global_search_user_result.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalSearchApiService _searchApi = GlobalSearchApiService();

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<GlobalSearchUserResult> _results = const <GlobalSearchUserResult>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _results = const <GlobalSearchUserResult>[];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _searchApi.searchUsers(query);
      if (!mounted || query != _queryController.text.trim()) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || query != _queryController.text.trim()) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _openUser(GlobalSearchUserResult user) {
    VmNavigator.openPublicProfile(
      context,
      userId: user.visibleId,
      displayName: user.visibleName,
      username: user.username,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F1),
        foregroundColor: const Color(0xFF251538),
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Global Search',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _SearchField(
                controller: _queryController,
                focusNode: _focusNode,
                loading: _loading,
                onChanged: _onQueryChanged,
                onClear: () {
                  _queryController.clear();
                  _onQueryChanged('');
                },
              ),
            ),
            Expanded(
              child: _SearchBody(
                query: query,
                loading: _loading,
                error: _error,
                results: _results,
                onRetry: () => _runSearch(_queryController.text),
                onUserTap: _openUser,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFECE2D8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF251538).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onChanged,
        style: const TextStyle(
          color: Color(0xFF251538),
          fontWeight: FontWeight.w900,
        ),
        decoration: InputDecoration(
          hintText: 'Search user ID, custom ID, name, or username',
          hintStyle: const TextStyle(
            color: Color(0xFF9B8CA5),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF12C7B7)),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              : controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF7B6A86)),
                    ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.query,
    required this.loading,
    required this.error,
    required this.results,
    required this.onRetry,
    required this.onUserTap,
  });

  final String query;
  final bool loading;
  final String? error;
  final List<GlobalSearchUserResult> results;
  final VoidCallback onRetry;
  final ValueChanged<GlobalSearchUserResult> onUserTap;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const _SearchIntro();

    if (error != null) {
      return _SearchError(message: error!, onRetry: onRetry);
    }

    if (!loading && results.isEmpty) {
      return _EmptyResults(query: query);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      physics: const BouncingScrollPhysics(),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = results[index];
        return _UserResultCard(user: user, onTap: () => onUserTap(user));
      },
    );
  }
}

class _SearchIntro extends StatelessWidget {
  const _SearchIntro();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: const [
        _SearchTipCard(
          icon: Icons.numbers_rounded,
          title: 'Search numeric IDs',
          subtitle: 'Find users by permanent public ID like 6418xxxxxx or custom display ID.',
        ),
        SizedBox(height: 12),
        _SearchTipCard(
          icon: Icons.person_search_rounded,
          title: 'Search names and usernames',
          subtitle: 'Use display names or usernames. Official @handles remain reserved for staff/system accounts.',
        ),
        SizedBox(height: 12),
        _SearchTipCard(
          icon: Icons.privacy_tip_rounded,
          title: 'Privacy-aware by design',
          subtitle: 'This module is built to stay reusable for Home, Profile, Inbox, rooms, and future mention search.',
        ),
      ],
    );
  }
}

class _SearchTipCard extends StatelessWidget {
  const _SearchTipCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF12C7B7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: const Color(0xFF12C7B7)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700, fontSize: 12.2, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserResultCard extends StatelessWidget {
  const _UserResultCard({required this.user, required this.onTap});

  final GlobalSearchUserResult user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFECE2D8)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.045),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: user.isOfficialOrStaff ? const Color(0xFFFFD36A) : const Color(0xFF12C7B7),
              child: Text(
                user.visibleName.characters.take(1).toString().toUpperCase(),
                style: const TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.visibleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF251538), fontSize: 15.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (user.shouldShowOfficialTick) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.verified_rounded, color: Color(0xFFC99A3B), size: 17),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.2, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: user.isOfficialOrStaff ? const Color(0xFFFFF5D8) : const Color(0xFFE8FAF7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                user.roleLabel,
                style: TextStyle(
                  color: user.isOfficialOrStaff ? const Color(0xFFC99A3B) : const Color(0xFF12A99C),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 42),
            const SizedBox(height: 12),
            const Text('Search failed', style: TextStyle(color: Color(0xFF251538), fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No users found for "$query"',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
  }
}
