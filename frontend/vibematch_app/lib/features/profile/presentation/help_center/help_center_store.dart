import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HelpCenterTicket {
  const HelpCenterTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'category': category,
      'subject': subject,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HelpCenterTicket.fromJson(Map<String, dynamic> json) {
    return HelpCenterTicket(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      subject: json['subject']?.toString() ?? 'Support request',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class HelpCenterStore {
  const HelpCenterStore._();

  static const String _ticketsKey = 'vm_help_center.tickets';

  static Future<List<HelpCenterTicket>> loadTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ticketsKey);
    if (raw == null || raw.trim().isEmpty) return <HelpCenterTicket>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <HelpCenterTicket>[];
      return decoded
          .whereType<Map>()
          .map((item) => HelpCenterTicket.fromJson(Map<String, dynamic>.from(item)))
          .where((ticket) => ticket.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return <HelpCenterTicket>[];
    }
  }

  static Future<void> saveTicket(HelpCenterTicket ticket) async {
    final tickets = await loadTickets();
    tickets.insert(0, ticket);
    await _saveTickets(tickets);
  }

  static Future<void> clearTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ticketsKey);
  }

  static Future<void> _saveTickets(List<HelpCenterTicket> tickets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tickets.map((ticket) => ticket.toJson()).toList());
    await prefs.setString(_ticketsKey, encoded);
  }
}
