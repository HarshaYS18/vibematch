import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  String type = 'sent';
  String period = 'today';
  Future<List<_Entry>>? future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<_Entry>> load() async {
    final res = await http.get(Uri.parse(VmApiConfig.endpoint('/rankings/$type?period=$period&limit=100')));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Backend rankings failed ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = body['entries'] as List<dynamic>? ?? const [];
    return rows.whereType<Map<String, dynamic>>().map(_Entry.fromJson).toList();
  }

  void reload() => setState(() => future = load());
  void setType(String v) => setState(() { type = v; future = load(); });
  void setPeriod(String v) => setState(() { period = v; future = load(); });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF251538),
        title: const Text('Rankings', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          _Chips(value: type, items: const {'sent': 'Sent', 'received': 'Received', 'recharge': 'Recharge'}, onTap: setType),
          _Chips(value: period, items: const {'hourly': 'Hour', 'today': 'Today', 'weekly': 'Week', 'monthly': 'Month'}, onTap: setPeriod),
          Expanded(
            child: FutureBuilder<List<_Entry>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: TextButton(onPressed: reload, child: const Text('Retry backend rankings')));
                final rows = snap.data ?? const [];
                if (rows.isEmpty) return const Center(child: Text('No backend ranking entries yet'));
                return RefreshIndicator(
                  onRefresh: () async => reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _Card(row: rows[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.value, required this.items, required this.onTap});
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      children: items.entries.map((e) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: e.key == value,
          label: Text(e.value),
          onSelected: (_) => onTap(e.key),
        ),
      )).toList(),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.row});
  final _Entry row;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: Row(children: [
      Text('#${row.rank}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC99A3B))),
      const SizedBox(width: 12),
      CircleAvatar(child: Text(row.initials)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text('VIP ${row.vip} · Sent Lv ${row.sentLv} · Receive Lv ${row.receiveLv}', style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
      ])),
      Text(row.score, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF251538))),
    ]),
  );
}

class _Entry {
  const _Entry(this.rank, this.score, this.name, this.initials, this.vip, this.sentLv, this.receiveLv);
  final int rank;
  final String score;
  final String name;
  final String initials;
  final int vip;
  final int sentLv;
  final int receiveLv;
  factory _Entry.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final name = user['display_name']?.toString() ?? 'User';
    return _Entry(_int(json['rank']), json['score_display']?.toString() ?? '${_int(json['score'])}', name, name.characters.take(2).toString().toUpperCase(), _int(user['vip_level']), _int(user['send_level']), _int(user['receive_level']));
  }
}

int _int(Object? v) => v is int ? v : v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
