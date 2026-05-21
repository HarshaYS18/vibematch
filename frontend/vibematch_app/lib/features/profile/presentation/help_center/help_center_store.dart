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

  factory HelpCenterTicket.fromRemote(Map<String, dynamic> json) {
    final messages = json['messages'];
    var body = json['ai_summary']?.toString() ?? '';
    if (messages is List && messages.isNotEmpty) {
      final userMessage = messages.cast<Object?>().whereType<Map>().firstWhere(
        (item) => item['sender_role']?.toString() == 'user',
        orElse: () => const <String, dynamic>{},
      );
      body = userMessage['body']?.toString() ?? body;
    }
    return HelpCenterTicket(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'other',
      subject: json['subject']?.toString() ?? 'Support request',
      message: body,
      status: json['status']?.toString() ?? 'waiting_cs',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
