import 'package:flutter/material.dart';

import '../data/rankings_api_service.dart';
import '../models/ranking_models.dart';
import 'widgets/rankings_luxury_widgets.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  final RankingsApiService _api = const RankingsApiService();
  String _type = 'sent';
  String _period = 'today';
  late Future<RankingPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RankingPayload> _load() => _api.getRankings(type: _type, period: _period);

  void _reload() => setState(() => _future = _load());
  void _setType(String value) => setState(() { _type = value; _future = _load(); });
  void _setPeriod(String value) => setState(() { _period = value; _future = _load(); });

  String get _title {
    if (_type == 'received') return 'Receiver Kings';
    if (_type == 'recharge') return 'Recharge Royals';
    return 'Sender Legends';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RankingLuxuryTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            RankingTopBar(title: _title, onBack: () => Navigator.of(context).maybePop()),
            RankingPills(
              value: _type,
              items: const {'sent': 'Sent', 'received': 'Received', 'recharge': 'Recharge'},
              onTap: _setType,
            ),
            RankingPills(
              value: _period,
              items: const {'hourly': 'Hour', 'today': 'Today', 'weekly': 'Week', 'monthly': 'Month'},
              onTap: _setPeriod,
            ),
            Expanded(
              child: FutureBuilder<RankingPayload>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: RankingLuxuryTheme.gold));
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: TextButton(
                        onPressed: _reload,
                        child: const Text('Retry backend rankings', style: TextStyle(color: RankingLuxuryTheme.gold, fontWeight: FontWeight.w900)),
                      ),
                    );
                  }
                  final entries = snapshot.data!.entries;
                  if (entries.isEmpty) return const RankingEmptyState();
                  return RefreshIndicator(
                    color: RankingLuxuryTheme.gold,
                    onRefresh: () async => _reload(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      itemCount: entries.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return RankingPodium(rows: entries.take(3).toList());
                        return RankingCard(row: entries[index - 1]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
