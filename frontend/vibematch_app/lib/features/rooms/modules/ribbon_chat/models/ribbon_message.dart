import 'ribbon_background_style.dart';

class RibbonMessage {
  final String id;
  final String roomId;
  final String senderUserId;
  final String senderName;
  final String text;
  final int coinCost;
  final DateTime createdAt;
  final Duration duration;
  final RibbonBackgroundType backgroundType;

  const RibbonMessage({
    required this.id,
    required this.roomId,
    required this.senderUserId,
    required this.senderName,
    required this.text,
    this.coinCost = 1000,
    required this.createdAt,
    this.duration = const Duration(milliseconds: 5200),
    this.backgroundType = RibbonBackgroundType.darkLuxury,
  });

  RibbonMessage copyWith({
    String? id,
    String? roomId,
    String? senderUserId,
    String? senderName,
    String? text,
    int? coinCost,
    DateTime? createdAt,
    Duration? duration,
    RibbonBackgroundType? backgroundType,
  }) {
    return RibbonMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderUserId: senderUserId ?? this.senderUserId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      coinCost: coinCost ?? this.coinCost,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      backgroundType: backgroundType ?? this.backgroundType,
    );
  }
}
