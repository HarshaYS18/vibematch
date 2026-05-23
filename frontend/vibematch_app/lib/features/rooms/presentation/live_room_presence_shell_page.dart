import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/vm_motion.dart';
import '../../auth/models/current_user.dart';
import '../data/live_room_media_signaling_service.dart';
import '../data/live_room_presence_repository.dart';
import 'live_room_models.dart';
import 'live_room_page.dart';
import 'live_room_restore_state.dart';
import 'widgets/live_room_minimized_overlay_service.dart';
import 'widgets/room_theme.dart';

class LiveRoomPresenceShellPage extends StatefulWidget {
  const LiveRoomPresenceShellPage({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.initialOnlineCount,
    this.currentUser,
    this.lockPassword,
    this.initialBackgroundTheme,
    this.restoreState,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int initialOnlineCount;
  final CurrentUser? currentUser;
  final String? lockPassword;
  final RoomBackgroundTheme? initialBackgroundTheme;
  final LiveRoomRestoreState? restoreState;

  @override
  State<LiveRoomPresenceShellPage> createState() =>
      _LiveRoomPresenceShellPageState();
}

class _LiveRoomPresenceShellPageState extends State<LiveRoomPresenceShellPage> {
  final LiveRoomPresenceRepository _presenceRepository =
      LiveRoomPresenceRepository();
  Timer? _heartbeatTimer;
  Timer? _enteredMessageTimer;
  LiveRoomPresenceSnapshot? _snapshot;
  SeatUser? _enteredUser;
  bool _joining = true;
  bool _autoSeatAttempted = false;
  bool _identitySeeded = false;
  String? _presenceError;

  int get _onlineCount => _snapshot?.onlineCount ?? widget.initialOnlineCount;
  bool get _restoringMinimizedRoom => widget.restoreState != null;

  @override
  void initState() {
    super.initState();
    LiveRoomMediaSignalingService.instance.configureRoom(
      roomId: widget.roomId,
      roomName: widget.roomName,
    );
    final currentUser = widget.currentUser;
    if (currentUser != null) {
      LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(currentUser);
      _identitySeeded = true;
    }

    if (_restoringMinimizedRoom) {
      _restorePresenceWithoutFreshJoin();
    } else {
      unawaited(_joinPresence());
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _enteredMessageTimer?.cancel();
    if (!LiveRoomMinimizedOverlayService.instance.isShowing) {
      unawaited(
        _presenceRepository.leaveRoom(widget.roomId).catchError((_) => 0),
      );
    }
    _presenceRepository.close();
    super.dispose();
  }

  void _restorePresenceWithoutFreshJoin() {
    _seedIdentityFromRestoreState();
    final cachedParticipants =
        LiveRoomPresenceRepository.currentParticipantsForRoom(widget.roomId);
    _snapshot = LiveRoomPresenceSnapshot(
      roomId: widget.roomId,
      onlineCount: widget.initialOnlineCount,
      participants: cachedParticipants,
    );
    _joining = false;
    _identitySeeded = true;
    _presenceError = null;
    _startHeartbeat();
    _restoreSavedSeatIfNeeded();
  }

  void _seedIdentityFromRestoreState() {
    final restoreState = widget.restoreState;
    if (restoreState == null) return;
    final restoredSelf = _restoredCurrentSeatUser(restoreState);
    if (restoredSelf == null) return;
    LiveRoomMediaSignalingService.instance.seedActiveRoomSeatUser(restoredSelf);
  }

  SeatUser? _restoredCurrentSeatUser(LiveRoomRestoreState restoreState) {
    final currentPublicId = widget.currentUser?.publicUserId.toString();
    for (final seat in restoreState.seatState.seats) {
      final user = seat.user;
      if (user == null) continue;
      if (user.isCurrentUser) return user;
      if (currentPublicId != null &&
          _sameRoomUserId(user.id, 'user_$currentPublicId')) {
        return user.copyWith(isCurrentUser: true);
      }
    }
    return null;
  }

  int? _restoredCurrentSeatIndex() {
    final restoreState = widget.restoreState;
    if (restoreState == null) return null;
    final currentPublicId = widget.currentUser?.publicUserId.toString();
    for (final seat in restoreState.seatState.seats) {
      final user = seat.user;
      if (user == null) continue;
      if (user.isCurrentUser) return seat.index;
      if (currentPublicId != null &&
          _sameRoomUserId(user.id, 'user_$currentPublicId')) {
        return seat.index;
      }
    }
    return null;
  }

  void _restoreSavedSeatIfNeeded() {
    final seatIndex = _restoredCurrentSeatIndex();
    if (seatIndex == null || seatIndex < 0) return;
    _autoSeatAttempted = true;
    final media = LiveRoomMediaSignalingService.instance;
    for (final delay in const <Duration>[
      Duration(milliseconds: 120),
      Duration(milliseconds: 650),
      Duration(milliseconds: 1500),
    ]) {
      unawaited(
        Future<void>.delayed(delay, () {
          if (!mounted) return;
          media.takeSeat(seatIndex);
        }),
      );
    }
  }

  bool _sameRoomUserId(String a, String b) {
    final left = _identityAliases(a);
    final right = _identityAliases(b);
    if (left.isEmpty || right.isEmpty) return false;
    return left.intersection(right).isNotEmpty;
  }

  Set<String> _identityAliases(String rawId) {
    final value = rawId.trim();
    if (value.isEmpty) return <String>{};
    final aliases = <String>{value, value.toLowerCase()};
    final userPrefix = RegExp(r'^user_(\d+)$').firstMatch(value);
    if (userPrefix != null) aliases.add(userPrefix.group(1)!);
    final direct = int.tryParse(value);
    if (direct != null) aliases.add('user_$direct');
    return aliases;
  }

  Future<void> _joinPresence() async {
    setState(() {
      _joining = true;
      _presenceError = null;
    });
    try {
      final snapshot = await _presenceRepository.joinRoom(
        widget.roomId,
        lockPassword: widget.lockPassword,
      );
      if (!mounted) return;
      _seedIdentityFromPresence(snapshot);
      setState(() {
        _snapshot = snapshot;
        _joining = false;
        _identitySeeded = true;
        _presenceError = null;
      });
      _showEnteredMessageIfNeeded(snapshot);
      _autoSeatIfAllowed(snapshot);
      _startHeartbeat();
    } catch (error) {
      if (!mounted) return;
      _heartbeatTimer?.cancel();
      setState(() {
        _joining = false;
        _presenceError = _cleanPresenceError(error);
      });
    }
  }

  String _cleanPresenceError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return 'Network is bad or lost. Please check your connection and retry.';
    }
    return message;
  }

  void _seedIdentityFromPresence(LiveRoomPresenceSnapshot snapshot) {
    final currentPublicId = widget.currentUser?.publicUserId.toString();
    SeatUser? self;
    if (currentPublicId != null) {
      self = snapshot.participants
          .where((user) => user.id == 'user_$currentPublicId')
          .firstOrNull;
    }
    self ??= snapshot.joinedUser;
    if (self == null) return;
    LiveRoomMediaSignalingService.instance.seedActiveRoomSeatUser(self);
  }

  void _showEnteredMessageIfNeeded(LiveRoomPresenceSnapshot snapshot) {
    final joinedUser = snapshot.joinedUser;
    if (!snapshot.shouldShowEnteredMessage || joinedUser == null) return;
    final currentPublicId = widget.currentUser?.publicUserId.toString();
    if (currentPublicId != null && joinedUser.id == 'user_$currentPublicId') {
      return;
    }
    _enteredMessageTimer?.cancel();
    setState(() => _enteredUser = joinedUser);
    _enteredMessageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _enteredUser = null);
    });
  }

  void _autoSeatIfAllowed(LiveRoomPresenceSnapshot snapshot) {
    if (_autoSeatAttempted) return;
    if (_restoringMinimizedRoom) return;
    final currentUser = widget.currentUser;
    if (currentUser == null) return;
    final currentPublicId = currentUser.publicUserId.toString();
    final self = snapshot.participants
        .where((user) => user.id == 'user_$currentPublicId')
        .firstOrNull;
    final isRoomHostOrAdmin = self?.isHost == true || self?.isRoomAdmin == true;
    final isOfficialOwner = currentUser.canSeeOwnerControls;
    if (!isRoomHostOrAdmin && !isOfficialOwner) return;

    _autoSeatAttempted = true;
    final media = LiveRoomMediaSignalingService.instance;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        media.takeSeatIfVacant(0);
      }),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1700), () {
        if (!mounted) return;
        media.takeSeatIfVacant(0);
      }),
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(_heartbeat()),
    );
  }

  Future<void> _heartbeat() async {
    try {
      final snapshot = await _presenceRepository.heartbeat(widget.roomId);
      if (!mounted) return;
      _seedIdentityFromPresence(snapshot);
      setState(() {
        _snapshot = snapshot;
        _presenceError = null;
      });
      _autoSeatIfAllowed(snapshot);
    } catch (error) {
      if (!mounted) return;
      _heartbeatTimer?.cancel();
      setState(() {
        _presenceError = _cleanPresenceError(error);
      });
    }
  }

  Future<void> _retryPresence() async {
    _heartbeatTimer?.cancel();
    await _joinPresence();
  }

  bool get _shouldBlockRoomWithRetry {
    return _presenceError != null && !_restoringMinimizedRoom;
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldBlockRoomWithRetry) {
      return _RoomNetworkRetryState(
        message: _presenceError!,
        joining: _joining,
        onRetry: _retryPresence,
        onBack: () => Navigator.maybePop(context),
      );
    }

    return Stack(
      children: [
        LiveRoomPage(
          key: ValueKey(
            'live-room-${widget.roomId}-${LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser?.id ?? 'user'}',
          ),
          roomName: widget.roomName,
          roomId: widget.roomId,
          language: widget.language,
          modeTitle: widget.modeTitle,
          onlineCount: _onlineCount,
          initialBackgroundTheme: widget.initialBackgroundTheme,
          restoreState: widget.restoreState,
        ),
        if (_enteredUser != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 66,
            left: 18,
            right: 18,
            child: _RoomEnteredSystemToast(user: _enteredUser!),
          ),
      ],
    );
  }
}

class _RoomNetworkRetryState extends StatelessWidget {
  const _RoomNetworkRetryState({
    required this.message,
    required this.joining,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final bool joining;
  final Future<void> Function() onRetry;
  final VoidCallback onBack;

  bool get _looksLikeAccessIssue {
    final normalized = message.toLowerCase();
    return normalized.contains('password') ||
        normalized.contains('locked') ||
        normalized.contains('secret') ||
        normalized.contains('invite') ||
        normalized.contains('banned') ||
        normalized.contains('kicked') ||
        normalized.contains('login');
  }

  String get _title =>
      _looksLikeAccessIssue ? 'Room access issue' : 'Network is bad or lost';

  String get _subtitle => _looksLikeAccessIssue
      ? message
      : 'We could not connect to the live room server. Please check your internet connection and retry.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120D1F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: VmFadeSlide(
              beginOffset: const Offset(0, 0.04),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE84C72).withValues(alpha: 0.16),
                        border: Border.all(
                          color: const Color(0xFFE84C72).withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        _looksLikeAccessIssue
                            ? Icons.lock_rounded
                            : Icons.wifi_off_rounded,
                        color: const Color(0xFFE84C72),
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (!_looksLikeAccessIssue && message.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: joining ? null : onBack,
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: joining ? null : () => unawaited(onRetry()),
                            icon: joining
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: Text(joining ? 'Retrying...' : 'Retry'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomEnteredSystemToast extends StatelessWidget {
  const _RoomEnteredSystemToast({required this.user});

  final SeatUser user;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: VmMotion.sheetContentDuration,
        switchInCurve: VmMotion.enterCurve,
        switchOutCurve: VmMotion.exitCurve,
        child: Container(
          key: ValueKey(user.id),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF120D1F).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: user.avatarColors),
                ),
                child: Text(
                  avatarLetter(user.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${user.name} entered the room',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
