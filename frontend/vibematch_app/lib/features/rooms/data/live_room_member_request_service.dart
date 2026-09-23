import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../realtime/app_realtime_hub.dart';
import '../presentation/live_room_models.dart';
import 'live_room_membership_service.dart';

class LiveRoomMemberRequestService {
  LiveRoomMemberRequestService._();

  static final LiveRoomMemberRequestService instance =
      LiveRoomMemberRequestService._();

  final ValueNotifier<List<SeatUser>> pendingRequests =
      ValueNotifier<List<SeatUser>>(<SeatUser>[]);

  final AppRealtimeHub _hub = AppRealtimeHub.shared;
  StreamSubscription<dynamic>? _subscription;
  String _roomId = '';
  SeatUser? _currentUser;

  void startRoom({required String roomId, required SeatUser currentUser}) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) return;

    _roomId = cleanRoomId;
    _currentUser = currentUser;
    _subscription ??= _hub.events.listen((event) {
      final legacy = event.toLegacyEvent();
      final eventRoomId =
          legacy['room_id']?.toString().trim() ??
          legacy['room_public_id']?.toString().trim() ??
          '';
      if (eventRoomId.isNotEmpty && eventRoomId != _roomId) return;

      final nestedPayload = _map(legacy['payload']);
      final delta = _map(
        legacy['delta'] ??
            nestedPayload['delta'] ??
            event.payload['delta'],
      );
      if (delta.isNotEmpty) {
        _syncFromRoomSnapshot(delta);
        return;
      }

      final room = _map(
        legacy['room'] ??
            nestedPayload['room'] ??
            event.payload['room'],
      );
      if (room.isNotEmpty) {
        _syncFromRoomSnapshot(room);
      }
    });

    unawaited(_hub.start());
  }

  void requestMembership() {
    if (_currentUser == null || _roomId.isEmpty) return;
    _send('room_member/request');
  }

  void approveMembership(SeatUser user) {
    if (_roomId.isEmpty || user.id.trim().isEmpty) return;
    _send(
      'room_member/approve',
      <String, Object?>{'target_user_id': user.id},
    );
  }

  void rejectMembership(SeatUser user) {
    if (_roomId.isEmpty || user.id.trim().isEmpty) return;
    _send(
      'room_member/reject',
      <String, Object?>{'target_user_id': user.id},
    );
  }

  void removeRoomMember(SeatUser user) {
    if (_roomId.isEmpty || user.id.trim().isEmpty) return;
    _send(
      'room_member/remove',
      <String, Object?>{'target_user_id': user.id},
    );
  }

  void stop() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _roomId = '';
    _currentUser = null;
    pendingRequests.value = <SeatUser>[];
  }

  void _send(
    String type, [
    Map<String, Object?> payload = const <String, Object?>{},
  ]) {
    if (_roomId.isEmpty) return;
    _hub.sendRaw(<String, dynamic>{
      'type': type,
      'room_public_id': _roomId,
      'command_id':
          'room-member-${DateTime.now().microsecondsSinceEpoch}',
      'payload': payload,
    });
  }

  void _syncFromRoomSnapshot(Map<String, dynamic> roomData) {
    final roomId = roomData['room_id']?.toString() ?? _roomId;

    final rawRequests = roomData['pending_room_member_requests'];
    final requestMaps = rawRequests is List
        ? rawRequests
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    if (rawRequests is List) {
      pendingRequests.value = requestMaps
          .map(_pendingRequestToSeatUser)
          .whereType<SeatUser>()
          .toList(growable: false);
    }

    // Durable membership is separate from online peers. Only the full roster
    // is complete enough to reconcile offline members and removals.
    final rawMembershipRoster = roomData['membership_roster'];
    if (rawMembershipRoster is List) {
      final backendMembership = <String, bool>{};
      for (final raw in rawMembershipRoster.whereType<Map>()) {
        final rawMember = raw.cast<String, dynamic>();
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
      final peers = roomData['peers'];
      if (peers is List) {
        final backendMembership = <String, bool>{};
        for (final raw in peers.whereType<Map>()) {
          final rawPeer = raw.cast<String, dynamic>();
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
    final participantType =
        json['participant_type']?.toString() ?? 'visitor';
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
    final backendUserId =
        json['backend_user_id']?.toString() ??
        json['user_id']?.toString() ??
        '';
    if (backendUserId.isEmpty) return null;
    final name =
        json['display_name']?.toString() ??
        json['username']?.toString() ??
        'Vibe User';
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
      avatarColors: const <Color>[
        Color(0xFF12C7B7),
        Color(0xFF6D5DF6),
      ],
      avatarUrl:
          avatarUrl == null || avatarUrl.isEmpty || avatarUrl == 'null'
          ? null
          : avatarUrl,
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}
