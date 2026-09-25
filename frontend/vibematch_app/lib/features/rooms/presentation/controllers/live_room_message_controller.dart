import 'dart:async';

import '../../../../foundation/realtime/realtime_event_envelope.dart';
import '../../../../realtime/app_realtime_hub.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../../../../room_session/data/room_session_repository.dart';
import '../../data/room_session_legacy_adapter.dart';
import '../../data/live_room_restrictions_service.dart';
import '../../data/live_room_seat_application_event_bus.dart';
import '../../data/live_room_system_event_bus.dart';
import '../live_room_models.dart';
import '../live_room_restore_state.dart';

class LiveRoomMessageController {
  LiveRoomMessageController({
    required String roomId,
    required this.roomSessionRepository,
    required SeatUser currentUser,
    required this.onChanged,
    LiveRoomMessageRestoreState? restoreState,
    AppRealtimeHub? realtimeHub,
  }) : _roomId = roomId.trim(),
       _realtimeHub = realtimeHub ?? AppRealtimeHub.shared,
       currentUser = LiveRoomMediaSignalingService.instance
           .effectiveCurrentUser(currentUser) {
    messages = List<ChatEntry>.from(restoreState?.messages ?? mockChatEntries);
    joinRequestUsers.addAll(restoreState?.joinRequestUsers ?? const []);
    _eventSubscription = _realtimeHub.events.listen(_handleRealtimeEvent);
    unawaited(_realtimeHub.start());
    _activeController = this;
  }

  static const Duration _roomSettingsSystemMessageDuration = Duration(
    seconds: 5,
  );
  static const Duration _giftMessageMergeWindow = Duration(seconds: 20);
  static const Set<String> _allowedRoomSettingsSystemMessages = <String>{
    'Images enabled',
    'Images disabled',
    'Guest messages enabled',
    'Guest messages disabled',
    'Apply mode enabled',
    'Free mode enabled',
  };

  static LiveRoomMessageController? _activeController;

  static void clearActiveRoomChatForEveryone() {
    _activeController?.clearChatForEveryone();
  }

  static void sendActiveRoomImageMessage({
    required String imageUrl,
    required String contentType,
  }) {
    _activeController?.sendImageMessage(
      imageUrl: imageUrl,
      contentType: contentType,
    );
  }

  final SeatUser currentUser;
  final RoomSessionRepository roomSessionRepository;
  final VoidCallbackLike onChanged;

  late List<ChatEntry> messages;
  final List<SeatUser> joinRequestUsers = <SeatUser>[];
  final Set<String> _handledSystemEventIds = <String>{};
  final Map<String, DateTime> _giftMessageUpdatedAt = <String, DateTime>{};
  final String _roomId;
  final AppRealtimeHub _realtimeHub;
  StreamSubscription<RealtimeEventEnvelope>? _eventSubscription;

  bool get _currentUserCanBypassGuestMessageBlock =>
      currentUser.isHost || currentUser.isRoomAdmin;

  bool get _guestMessageAllowed =>
      LiveRoomRestrictionsService.guestMessagesEnabled ||
      _currentUserCanBypassGuestMessageBlock;

  LiveRoomMessageRestoreState snapshotForRestore() {
    return LiveRoomMessageRestoreState(
      messages: List<ChatEntry>.from(messages),
      joinRequestUsers: List<SeatUser>.from(joinRequestUsers),
    );
  }

  void sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (!_guestMessageAllowed) return;
    LiveRoomMediaSignalingService.instance.sendRoomChat(trimmed);
  }

  void sendImageMessage({
    required String imageUrl,
    required String contentType,
  }) {
    final safeUrl = imageUrl.trim();
    if (safeUrl.isEmpty) return;
    if (!LiveRoomRestrictionsService.roomImagesEnabled) return;
    if (!_guestMessageAllowed) return;
  }

  void insertSystemMessage(String message) =>
      insertPersistentSystemMessage(message);

  void insertPersistentSystemMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    messages.insert(
      0,
      ChatEntry(senderName: 'System', senderId: 'system', message: trimmed),
    );
    onChanged();
  }

  void insertTransientSystemMessage(
    String message, {
    Duration duration = const Duration(seconds: 10),
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    final entry = ChatEntry(
      senderName: 'System',
      senderId: 'system',
      message: trimmed,
      autoDismissAt: DateTime.now().add(duration),
    );
    messages.insert(0, entry);
    onChanged();
    _scheduleAutoDismiss(entry);
  }

  void insertUserEnteredSystemEvent(SeatUser user) =>
      _insertUserEnteredByName(user.name, avatarUrl: user.avatarUrl);

  void insertUserRemovedSystemEvent({
    required String actorName,
    required String targetName,
  }) {
    final actor = actorName.trim().isEmpty ? 'Room admin' : actorName.trim();
    final member = targetName.trim().isEmpty ? 'user' : targetName.trim();
    final entry = ChatEntry(
      senderName: 'System',
      senderId: 'system',
      message: '$actor has removed $member from the group',
      systemEventType: RoomSystemEventType.userRemoved,
      autoDismissAt: DateTime.now().add(const Duration(seconds: 10)),
    );
    messages.insert(0, entry);
    onChanged();
    _scheduleAutoDismiss(entry);
  }

  void insertEntry(ChatEntry entry) {
    if (entry.isGift) {
      _insertOrUpdateGiftEntry(entry);
      return;
    }
    messages.insert(0, entry);
    if (entry.shouldAutoDismiss) _scheduleAutoDismiss(entry);
    onChanged();
  }

  void clearChatForEveryone() {
    messages.clear();
    _giftMessageUpdatedAt.clear();
    insertPersistentSystemMessage(
      'Chat cleared for everyone by ${currentUser.name}',
    );
  }

  void requestJoin() {
    final alreadyRequested = joinRequestUsers.any(
      (user) => user.id == currentUser.id,
    );
    if (alreadyRequested) return;
    joinRequestUsers.add(currentUser);
    onChanged();
  }

  void resolveJoinRequest({
    required SeatUser user,
    required bool approved,
    required String roomName,
  }) {
    joinRequestUsers.removeWhere((item) => item.id == user.id);
    messages.insert(
      0,
      ChatEntry(
        senderName: currentUser.name,
        senderId: currentUser.id,
        senderAvatarUrl: currentUser.avatarUrl,
        message: approved
            ? 'approved ${user.name} to join $roomName'
            : 'rejected ${user.name}\'s join request',
        vipLevel: currentUser.vipLevel,
        sendingLevel: currentUser.sendingLevel,
        receivingLevel: currentUser.receivingLevel,
      ),
    );
    onChanged();
  }

  void _handleRealtimeEvent(RealtimeEventEnvelope envelope) {
    final decoded = envelope.toLegacyEvent();
    final type = decoded['type']?.toString() ?? '';
    final rawPayload = decoded['payload'];
    final payload = rawPayload is Map
        ? rawPayload.cast<String, dynamic>()
        : <String, dynamic>{};

    final eventRoomId =
        payload['room_id']?.toString().trim() ??
        payload['room_public_id']?.toString().trim() ??
        decoded['room_id']?.toString().trim() ??
        decoded['room_public_id']?.toString().trim() ??
        '';
    if (eventRoomId.isNotEmpty &&
        _roomId.isNotEmpty &&
        eventRoomId != _roomId) {
      return;
    }

    if (type == 'room/system_event') {
      _handleMediaSystemEvent(LiveRoomSystemEvent.fromJson(payload));
      return;
    }
    if (type == 'seat_application/received') {
      _handleSeatApplicationEvent(
        LiveRoomSeatApplicationEvent.fromJson(payload),
      );
    }
  }

  void _handleSeatApplicationEvent(
    LiveRoomSeatApplicationEvent event,
  ) {
    if (_handledSystemEventIds.contains(event.id) ||
        event.seatIndex < 0) {
      return;
    }
    _handledSystemEventIds.add(event.id);
    _insertSeatApplicationRequest(
      applicantUserId: event.applicantUserId,
      applicantName: event.applicantName,
      applicantAvatarUrl: null,
      seatIndex: event.seatIndex,
      createdAt: event.createdAt,
      expiresAt: event.expiresAt,
    );
  }

  void _insertSeatApplicationRequest({
    required String applicantUserId,
    required String applicantName,
    required String? applicantAvatarUrl,
    required int seatIndex,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) {
    final existingPending = messages.any(
      (message) =>
          message.isSeatApplication &&
          !message.applicationResolved &&
          _sameRoomUserId(message.senderId, applicantUserId) &&
          message.seatIndex == seatIndex,
    );
    if (existingPending) return;
    final applicant = _sameRoomUserId(applicantUserId, currentUser.id)
        ? currentUser
        : RoomSessionLegacyAdapter.findPresenceUser(
            roomSessionRepository.currentState,
            applicantUserId,
          );
    messages.insert(
      0,
      ChatEntry(
        senderName: applicant?.name ?? applicantName,
        senderId: applicantUserId,
        senderAvatarUrl: applicant?.avatarUrl ?? applicantAvatarUrl,
        message: 'has applied for seat ${seatIndex + 1}',
        vipLevel: applicant?.vipLevel ?? 0,
        sendingLevel: applicant?.sendingLevel ?? 0,
        receivingLevel: applicant?.receivingLevel ?? 0,
        isSeatApplication: true,
        seatIndex: seatIndex,
        applicationCreatedAt: createdAt,
        applicationExpiresAt: expiresAt,
      ),
    );
    onChanged();
  }

  void _handleMediaSystemEvent(LiveRoomSystemEvent event) {
    if (_handledSystemEventIds.contains(event.id)) return;
    _handledSystemEventIds.add(event.id);

    if (event.isRoomChatMessage) {
      messages.insert(
        0,
        ChatEntry(
          senderName: event.actorName.trim().isEmpty
              ? 'Vibe User'
              : event.actorName.trim(),
          senderId: event.actorUserId,
          senderAvatarUrl: event.actorAvatarUrl,
          message: event.message,
          vipLevel: event.actorVipLevel,
          sendingLevel: event.actorSendingLevel,
          receivingLevel: event.actorReceivingLevel,
        ),
      );
      onChanged();
      return;
    }

    if (event.isRoomGiftSent) {
      final senderName = event.actorName.trim().isEmpty
          ? 'Vibe User'
          : event.actorName.trim();
      final receiverName = event.targetName.trim().isEmpty
          ? 'user'
          : event.targetName.trim();
      final giftName = event.giftName.trim().isEmpty
          ? 'Gift'
          : event.giftName.trim();
      final quantity = event.giftQuantity <= 0 ? 1 : event.giftQuantity;
      final luckySuffix = event.isLuckyGift && event.luckyMultiplier > 0
          ? ' x${event.luckyMultiplier}'
          : '';
      _insertOrUpdateGiftEntry(
        ChatEntry(
          senderName: senderName,
          senderId: event.actorUserId,
          senderAvatarUrl: event.actorAvatarUrl,
          message: 'sent to $receiverName $giftName$luckySuffix x$quantity',
          vipLevel: event.actorVipLevel,
          sendingLevel: event.actorSendingLevel,
          receivingLevel: event.actorReceivingLevel,
          isGift: true,
          giftAssetPath: event.giftAssetPath,
        ),
      );
      return;
    }

    if (event.isUserEntered) {
      if (event.targetUserId == currentUser.id ||
          event.actorUserId == currentUser.id) {
        return;
      }
      final name = event.targetName.trim().isNotEmpty
          ? event.targetName
          : event.actorName;
      _insertUserEnteredByName(name, avatarUrl: event.actorAvatarUrl);
      return;
    }

    if (event.type == 'seat_application_requested') {
      final seatIndex = event.seatIndex;
      final applicantId = event.actorUserId.trim().isNotEmpty
          ? event.actorUserId
          : event.targetUserId;
      if (seatIndex != null && applicantId.trim().isNotEmpty) {
        _insertSeatApplicationRequest(
          applicantUserId: applicantId,
          applicantName: event.actorName.trim().isEmpty
              ? event.targetName
              : event.actorName,
          applicantAvatarUrl: event.actorAvatarUrl,
          seatIndex: seatIndex,
          createdAt: event.createdAt,
          expiresAt: event.createdAt.add(const Duration(seconds: 20)),
        );
      }
      return;
    }

    if (event.isChatCleared) {
      messages.clear();
      _giftMessageUpdatedAt.clear();
      insertTransientSystemMessage(
        event.message.trim().isEmpty
            ? 'Chat cleared for everyone'
            : event.message.trim(),
      );
      return;
    }

    if (event.isSeatApplicationAgreed || event.isSeatApplicationRejected) {
      _resolveSeatApplicationFromSystemEvent(
        event,
        approved: event.isSeatApplicationAgreed,
      );
      insertTransientSystemMessage(event.message);
      return;
    }

    if (event.isRoomSystemMessage) {
      final cleanMessage = event.message.trim();
      if (cleanMessage.isEmpty) return;
      insertTransientSystemMessage(
        cleanMessage,
        duration: _roomSystemMessageDuration(event),
      );
      return;
    }

    if (event.isUserRemoved) {
      if (event.targetUserId == currentUser.id) return;
      insertTransientSystemMessage(
        event.message.trim().isEmpty
            ? '${event.targetName.trim().isEmpty ? 'User' : event.targetName} was removed from the room'
            : event.message.trim(),
      );
      return;
    }

    if (event.message.trim().isNotEmpty) {
      insertTransientSystemMessage(event.message);
    }
  }

  void _insertOrUpdateGiftEntry(ChatEntry entry) {
    final cleanEntry = ChatEntry(
      senderName: entry.senderName,
      senderId: entry.senderId,
      senderAvatarUrl: entry.senderAvatarUrl,
      senderNameGradientColors: entry.senderNameGradientColors,
      message: _cleanGiftMessage(entry.message),
      vipLevel: entry.vipLevel,
      sendingLevel: entry.sendingLevel,
      receivingLevel: entry.receivingLevel,
      isGift: true,
      giftAssetPath: entry.giftAssetPath,
    );
    final key = _giftMessageKey(cleanEntry);
    final now = DateTime.now();
    final lastUpdatedAt = _giftMessageUpdatedAt[key];
    final shouldMerge =
        lastUpdatedAt != null &&
        now.difference(lastUpdatedAt) <= _giftMessageMergeWindow;
    final oldIndex = shouldMerge
        ? messages.indexWhere(
            (item) => item.isGift && _giftMessageKey(item) == key,
          )
        : -1;
    if (oldIndex >= 0) {
      messages[oldIndex] = cleanEntry;
      if (oldIndex != 0) messages.insert(0, messages.removeAt(oldIndex));
    } else {
      messages.insert(0, cleanEntry);
    }
    _giftMessageUpdatedAt[key] = now;
    onChanged();
  }

  String _cleanGiftMessage(String message) {
    return message
        .trim()
        .replaceAll(RegExp(r'\s+x0(?=\s+x\d+|$)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+0x(?=\s+x\d+|$)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _giftMessageKey(ChatEntry entry) {
    final sender = _canonicalGiftSender(entry);
    final baseMessage = _cleanGiftMessage(entry.message)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+x\d+\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '$sender|$baseMessage';
  }

  String _canonicalGiftSender(ChatEntry entry) {
    final aliases = _identityAliases(entry.senderId);
    for (final alias in aliases) {
      if (RegExp(r'^user_\d+$').hasMatch(alias)) return alias;
    }
    return entry.senderName.trim().toLowerCase();
  }

  void _insertUserEnteredByName(String rawName, {String? avatarUrl}) {
    final name = rawName.trim().isEmpty ? 'User' : rawName.trim();
    final entry = ChatEntry(
      senderName: name,
      senderId: 'system',
      senderAvatarUrl: avatarUrl,
      message: 'entered the room',
      systemEventType: RoomSystemEventType.userEntered,
      autoDismissAt: DateTime.now().add(const Duration(seconds: 10)),
    );
    messages.insert(0, entry);
    onChanged();
    _scheduleAutoDismiss(entry);
  }

  void _resolveSeatApplicationFromSystemEvent(
    LiveRoomSystemEvent event, {
    required bool approved,
  }) {
    var changed = false;
    final entriesToDismiss = <ChatEntry>[];
    for (var i = 0; i < messages.length; i++) {
      final entry = messages[i];
      if (!entry.isSeatApplication ||
          entry.applicationApproved ||
          entry.applicationRejected) {
        continue;
      }
      if (!_sameRoomUserId(entry.senderId, event.targetUserId)) continue;
      final eventSeatIndex = event.seatIndex;
      if (eventSeatIndex != null && entry.seatIndex != eventSeatIndex) continue;
      final seatLabel = entry.seatIndex == null ? '' : ' ${entry.seatIndex! + 1}';
      final updatedEntry = entry.copyWith(
        message: approved
            ? '${entry.senderName} seat$seatLabel request agreed'
            : '${entry.senderName} seat$seatLabel request rejected',
        applicationApproved: approved,
        applicationRejected: !approved,
        autoDismissAt: DateTime.now().add(const Duration(seconds: 10)),
      );
      messages[i] = updatedEntry;
      entriesToDismiss.add(updatedEntry);
      changed = true;
    }
    if (!changed) return;
    onChanged();
    for (final entry in entriesToDismiss) {
      _scheduleAutoDismiss(entry);
    }
  }

  Duration _roomSystemMessageDuration(LiveRoomSystemEvent event) {
    final explicitSeconds = event.autoDismissSeconds;
    if (explicitSeconds != null && explicitSeconds > 0) {
      return Duration(seconds: explicitSeconds);
    }

    final message = event.message.trim().toLowerCase();
    const shortSettingsMessages = <String>{
      'images enabled',
      'images disabled',
      'guest messages enabled',
      'guest messages disabled',
      'apply mode enabled',
      'free mode enabled',
    };
    if (shortSettingsMessages.contains(message)) {
      return const Duration(seconds: 5);
    }
    return const Duration(seconds: 10);
  }

  bool _sameRoomUserId(String? a, String? b) {
    final left = _identityAliases(a);
    final right = _identityAliases(b);
    if (left.isEmpty || right.isEmpty) return false;
    return left.intersection(right).isNotEmpty;
  }

  Set<String> _identityAliases(String? rawId) {
    final value = rawId?.trim();
    if (value == null || value.isEmpty) return <String>{};
    final aliases = <String>{value, value.toLowerCase()};
    final match = RegExp(r'(?:^|_)user_(\d+)$').firstMatch(value);
    if (match != null) {
      aliases.add(match.group(1)!);
      aliases.add('user_${match.group(1)!}');
    }
    final direct = int.tryParse(value);
    if (direct != null) aliases.add('user_$direct');
    return aliases;
  }

  void _scheduleAutoDismiss(ChatEntry entry) {
    final dismissAt = entry.autoDismissAt;
    if (dismissAt == null) return;
    final delay = dismissAt.difference(DateTime.now());
    Timer(delay.isNegative ? Duration.zero : delay, () {
      final removed = messages.remove(entry);
      if (removed) onChanged();
    });
  }

  void dispose() {
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    if (identical(_activeController, this)) {
      _activeController = null;
    }
  }
}
