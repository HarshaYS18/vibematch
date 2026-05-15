import 'dart:async';

import 'package:flutter/material.dart';

import '../../../relationships/data/relationship_exp_api_service.dart';
import '../../../relationships/presentation/relationship_rankings_sheet.dart';
import '../../data/love_bond_realtime_service.dart';
import '../love_bonds/widgets/love_bond_card.dart';
import '../love_bonds/widgets/love_bond_realtime_cards.dart';
import 'public_profile_shared_widgets.dart';

class PublicLoveBondsPanel extends StatefulWidget {
  const PublicLoveBondsPanel({
    super.key,
    required this.publicUserId,
    required this.onVisitorTap,
  });

  final int publicUserId;
  final VoidCallback onVisitorTap;

  @override
  State<PublicLoveBondsPanel> createState() => _PublicLoveBondsPanelState();
}

class _PublicLoveBondsPanelState extends State<PublicLoveBondsPanel> {
  final RelationshipExpApiService _api = const RelationshipExpApiService();
  RelationshipExpSummary? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRelationshipSummary());
  }

  @override
  void didUpdateWidget(covariant PublicLoveBondsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.publicUserId != widget.publicUserId) {
      unawaited(_loadRelationshipSummary());
    }
  }

  Future<void> _loadRelationshipSummary() async {
    if (widget.publicUserId <= 0) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final summary = await _api.getUserSummary(publicUserId: widget.publicUserId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openRelationshipRankings() {
    RelationshipRankingsSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LoveBondRequest>>(
      valueListenable: LoveBondRealtimeService.requests,
      builder: (context, requests, child) {
        final activeBonds = LoveBondRealtimeService.activeBondsFor(widget.publicUserId);
        final summary = _summary;
        if (activeBonds.isEmpty && summary == null && !_loading) {
          return const SizedBox.shrink();
        }

        final cards = loveBondCardsForProfile(widget.publicUserId);

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: publicProfileWhitePanelDecoration(radius: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Love & Bonds',
                      style: TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _RankButton(onTap: _openRelationshipRankings),
                  const SizedBox(width: 8),
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF5AAA),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFECE2D8)),
                      ),
                      child: Text(
                        summary == null ? 'Public view' : 'Bond Lv.${summary.level}',
                        style: const TextStyle(
                          color: Color(0xFF7A6B86),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              if (summary != null) ...[
                const SizedBox(height: 10),
                _RelationshipExpBar(summary: summary),
              ] else if (_error != null) ...[
                const SizedBox(height: 10),
                _RelationshipErrorPill(
                  message: _error!,
                  onRetry: () => unawaited(_loadRelationshipSummary()),
                ),
              ],
              const SizedBox(height: 13),
              SizedBox(
                height: 156,
                child: Row(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      Expanded(
                        child: LoveBondCard(
                          bond: cards[index],
                          onTap: widget.onVisitorTap,
                        ),
                      ),
                      if (index != cards.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RankButton extends StatelessWidget {
  const _RankButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5AAA).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFF5AAA).withValues(alpha: 0.22)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_rounded, size: 14, color: Color(0xFFFF5AAA)),
              SizedBox(width: 5),
              Text(
                'Rank',
                style: TextStyle(
                  color: Color(0xFFFF5AAA),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelationshipExpBar extends StatelessWidget {
  const _RelationshipExpBar({required this.summary});

  final RelationshipExpSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progress.clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECE2D8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_compact(summary.totalExp)} relationship EXP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFFFF5AAA),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: const Color(0xFFECE2D8),
              color: const Color(0xFFFF5AAA),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipErrorPill extends StatelessWidget {
  const _RelationshipErrorPill({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Text(
          'Relationship EXP unavailable · tap to retry',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7A6B86),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _compact(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
