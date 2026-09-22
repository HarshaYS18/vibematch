import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/vm_media_config.dart';
import '../presentation/live_room_models.dart';
import 'live_room_membership_service.dart';

class LiveRoomMemberRequestService {
  LiveRoomMemberRequestService._();

  static final LiveRoomMemberRequestService instance =
      LiveRoomMemberRequestService._();

  final ValueNotifier<List<SeatUser>> pendingRequests =
      ValueNotifier<List<SeatUser>>(<SeatUser>[]);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String _roomId = '';
  SeatUser? _currentUser;

  void startRoom({required String roomId, required SeatUser currentUser}) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) return;

    final sameSession = _roomId == cleanRoomId && _currentUser?.id == currentUser.id;
    _roomId = cleanRoomId;
    _currentUser = currentUser;

    if (sameSession && _channel != null) {
      _send('room/snapshot', <String, Object?>{});
      return;
    }

    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    _subscription = null;
    _channel = null;

    try {
      final channel = WebSocketChannel.connect(Uri.parse(VmMediaConfig.wsUrl));
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) => _resetSocketOnly(),
        onDone: _resetSocketOnly,
        cancelOnError: true,
      );
      _send('room/snapshot', <String, Object?>{});
    } catch (_) {
      _resetSocketOnly();
    }
  }

  void requestMembership() {
    if (_currentUser == null || _roomId.isEmpty) return;
    _send('room_member/request', <String, Object?>{});
  }

  void approveMembership(SeatUser user) {
    if (_roomId.isEmpty || user.id.trim().isEmpty) return;
    _send('room_member/approve', <String, Object?>{
      'target_user_id': user.id,
    });
  }

  void rejectMembership(SeatUser user) {
    if (_roomId.isEmpty || user.id.trim().isEmpty) return;
    _send('room_member/reject', <String, Object?>{
      'target_user_id': user.id,
    });
  }

  void removeRoomMember(SeatUser user) {
    if (_roomId.isEmpty || user.id.trim().isEmpty) return;
    _send('room_member/remove', <String, Object?>{
      'target_user_id': user.id,
    });
  }

  void stop() {
    unawaited(_subscription?.cancel());
    unawaited(_channel?.sink.close());
    _subscription = null;
    _channel = null;
    _roomId = '';
    _currentUser = null;
    pendingRequests.value = <SeatUser>[];
  }

  void _send(String type, Map<String, Object?> payload) {
    final channel = _channel;
    final roomId = _roomId;
    final user = _currentUser;
    if (channel == null || roomId.isEmpty || user == null) return;

    final messagePayload = <String, Object?>{
      'room_id': roomId,
      'user_id': user.id,
      'display_name': user.name,
      'avatar_url': user.avatarUrl,
      'is_host': user.isHost,
      'is_room_admin': user.isRoomAdmin || user.isHost,
      ...payload,
    };

    channel.sink.add(
      jsonEncode(<String, Object?>{
        'type': type,
        'payload': messagePayload,
      }),
    );
  }

  void _handleMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) return;
      final roomData = payload['room'];
      if (roomData is! Map<String, dynamic>) return;
      _syncFromRoomSnapshot(roomData);
    } catch (_) {
      // Ignore malformed realtime packets.
    }
  }

  void _syncFromRoomSnapshot(Map<String, dynamic> roomData) {
    final roomId = roomData['room_id']?.toString() ?? _roomId;

    final rawRequests = roomData['pending_room_member_requests'];
    final requestMaps = rawRequests is List
        ? rawRequests.whereType<Map<String, dynamic>>().toList(growable: false)
        : const <Map<String, dynamic>>[];
    pendingRequests.value = requestMaps
        .map(_pendingRequestToSeatUser)
        .whereType<SeatUser>()
        .toList(growable: false);

    // Durable membership is separate from online peers. Only this list is
    // complete enough to reconcile offline members and removals.
    final rawMembershipRoster = roomData['membership_roster'];
    if (rawMembershipRoster is List) {
      final backendMembership = <String, bool>{};
      for (final rawMember
          in rawMembershipRoster.whereType<Map<String, dynamic>>()) {
        final isRoomMember = _isRoomMemberRecord(rawMember);
        for (final alias in _identityAliases(rawMember)) {
          backendMembership[alias] = isRoomMember;
        }
      }
      LiveRoomMembershipService.applyBackendMembershipSnapshot(
        roomId: roomId,
        roomMemberByUserId: backendMembership,
        completeRoster: true,
      );
    } else {
      // Older snapshots expose active peers only. They can update known users,
      // but absence here must never remove an offline member.
      final peers = roomData['peers'];
      if (peers is List) {
        final backendMembership = <String, bool>{};
        for (final rawPeer in peers.whereType<Map<String, dynamic>>()) {
          final isRoomMember = _isRoomMemberRecord(rawPeer);
          for (final alias in _identityAliases(rawPeer)) {
            backendMembership[alias] = isRoomMember;
          }
        }
        LiveRoomMembershipService.applyBackendMembershipSnapshot(
          roomId: roomId,
          roomMemberByUserId: backendMembership,
        );
      }
    }

    // pending_room_member_requests is a complete backend snapshot, so absence
    // resolves stale local pending state after approve/reject/remove.
    if (rawRequests is List) {
      final pendingUserIds = <String>{};
      for (final request in requestMaps) {
        pendingUserIds.addAll(_identityAliases(request));
      }
      LiveRoomMembershipService.applyBackendPendingSnapshot(
        roomId: roomId,
        pendingUserIds: pendingUserIds,
      );
    }
  }

  Set<String> _identityAliases(Map<String, dynamic> json) {
    final publicUserId = json['public_user_id']?.toString().trim() ?? '';
    final backendUserId =
        json['backend_user_id']?.toString().trim() ??
        json['user_id']?.toString().trim() ??
        '';
    return <String>{
      if (backendUserId.isNotEmpty) backendUserId,
      if (publicUserId.isNotEmpty) publicUserId,
      if (publicUserId.isNotEmpty) 'user_$publicUserId',
    };
  }

  bool _isRoomMemberRecord(Map<String, dynamic> json) {
    final status = json['membership_request_status']?.toString() ?? 'none';
    final participantType = json['participant_type']?.toString() ?? 'visitor';
    return json['is_room_member'] == true ||
        json['is_member'] == true ||
        json['is_room_admin'] == true ||
        json['is_host'] == true ||
        json['is_room_owner'] == true ||
        status == 'room_member' ||
        participantType == 'room_member' ||
        participantType == 'admin' ||
        participantType == 'owner';
  }

  SeatUser? _pendingRequestToSeatUser(Map<String, dynamic> json) {
    final backendUserId = json['backend_user_id']?.toString() ?? json['user_id']?.toString() ?? '';
    if (backendUserId.isEmpty) return null;
    final name = json['display_name']?.toString() ?? json['username']?.toString() ?? 'Vibe User';
    final avatarUrl = json['avatar_url']?.toString();
    return SeatUser(
      id: backendUserId,
      name: name,
      roleLabel: 'Visitor',
      familyName: '',
      relationshipText: '',
      vipLevel: 0,
      sendingLevel: 0,
      receivingLevel: 0,
      sentExp: 0,
      receivedExp: 0,
      medals: const <String>[],
      avatarColors: const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      avatarUrl: avatarUrl == null || avatarUrl.isEmpty || avatarUrl == 'null' ? null : avatarUrl,
    );
  }

  void _resetSocketOnly() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _channel = null;
  }
}
