import 'dart:async';

import 'package:flutter/material.dart';

import '../../../social/data/social_api_service.dart';
import '../../data/profile_api_service.dart';
import 'me_shared_widgets.dart';

class MeStatsRow extends StatefulWidget {
  const MeStatsRow({
    super.key,
    required this.userId,
    required this.publicUserId,
    required this.onFollowingTap,
    required this.onFollowersTap,
    required this.onRoomsTap,
    required this.onVisitorsTap,
  });

  final int userId;
  final int publicUserId;
  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onRoomsTap;
  final VoidCallback onVisitorsTap;

  @override
  State<MeStatsRow> createState() => _MeStatsRowState();
}

class _MeStatsRowState extends State<MeStatsRow> {
  final SocialApiService _socialApiService = const SocialApiService();
  StreamSubscription<ProfileRelationshipRealtimeEvent>? _relationshipRealtimeSub;
  int? _followingCount;
  int? _followersCount;

  @override
  void initState() {
    super.initState();
    _relationshipRealtimeSub = ProfileRelationshipRealtimeService.instance.events.listen((_) {
      unawaited(_loadFollowStats());
    });
    unawaited(_loadFollowStats());
  }

  @override
  void didUpdateWidget(covariant MeStatsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.publicUserId != widget.publicUserId) {
      unawaited(_loadFollowStats());
    }
  }

  @override
  void dispose() {
    _relationshipRealtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFollowStats() async {
    try {
      final results = await Future.wait([
        _socialApiService.listFollowingUsers(),
        _socialApiService.listFollowerUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _followingCount = results[0].length;
        _followersCount = results[1].length;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followingCount ??= 0;
        _followersCount ??= 0;
      });
    }
  }

  String _compactCount(int? value) {
    if (value == null) return '...';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MeProfileStat(
            label: 'Following',
            value: _compactCount(_followingCount),
            icon: Icons.people_alt_rounded,
            onTap: widget.onFollowingTap,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: MeProfileStat(
            label: 'Followers',
            value: _compactCount(_followersCount),
            icon: Icons.favorite_rounded,
            onTap: widget.onFollowersTap,
          ),
        ),
      ],
    );
  }
}
