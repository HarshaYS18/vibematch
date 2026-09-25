import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/vm_motion.dart';
import '../../../room_session/data/room_session_repository.dart';
import '../../../room_session/domain/room_session_state.dart';
import '../../auth/models/current_user.dart';
import '../data/live_room_media_signaling_service.dart';
import '../data/live_room_presence_repository.dart';
import '../data/room_session_legacy_adapter.dart';
import 'live_room_models.dart';
import 'live_room_page.dart';
import 'live_room_restore_state.dart';
import 'widgets/live_room_minimized_overlay_service.dart';
import 'widgets/room_theme.dart';

class LiveRoomPresenceShellPage extends ConsumerStatefulWidget {
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
  ConsumerState<LiveRoomPresenceShellPage> createState() =>
      _LiveRoomPresenceShellPageState();
}

class _LiveRoomPresenceShellPageState
    extends ConsumerState<LiveRoomPresenceShellPage> {
  late final RoomSessionRepository _roomSessionRepository;
  late final RoomSessionLegacyRealtimeBridge _roomSessionRealtimeBridge;
  final ValueNotifier<SeatUser?> _enteredUser = ValueNotifier<SeatUser?>(null);
  final ValueNotifier<String?> _livePresenceWarning = ValueNotifier<String?>(
    null,
  );

  Timer? _enteredMessageTimer;
  LiveRoomPresenceSnapshot? _snapshot;
  bool _joining = true;
  bool _autoSeatAttempted = false;
  bool _presenceEstablished = false;
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
    _roomSessionRepository = ref.read(
      roomSessionRepositoryProvider(widget.roomId).notifier,
    );
    _roomSessionRealtimeBridge = RoomSessionLegacyRealtimeBridge(
      roomId: widget.roomId,
      repository: _roomSessionRepository,
      mediaSignalingService: LiveRoomMediaSignalingService.instance,
    )..start();

    final currentUser = widget.currentUser;
    if (currentUser != null) {
      LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(currentUser);
    }

    if (_restoringMinimizedRoom) {
      _restorePresenceWithoutFreshJoin();
    } else {
      unawaited(_joinPresence());
    }
  }

  @override
  void dispose() {
    _enteredMessageTimer?.cancel();
    if (!LiveRoomMinimizedOverlayService.instance.isShowing) {
      _roomSessionRealtimeBridge.deactivate();
      unawaited(_leaveRoomBestEffort());
    }
    _roomSessionRealtimeBridge.dispose();
    _enteredUser.dispose();
    _livePresenceWarning.dispose();
    super.dispose();
  }

  Future<void> _leaveRoomBestEffort() async {
    try {
      await LiveRoomMediaSignalingService.instance.leaveRoom();
    } catch (_) {
      // Media teardown is best effort; durable room state still needs leave.
    }
    try {
      await _roomSessionRepository.leave();
    } catch (_) {
      // Route teardown must not be blocked by a failed leave request.
    }
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
    _presenceEstablished = true;
    _presenceError = null;
    unawaited(_roomSessionRealtimeBridge.activate());
    // A minimized-room restore may render cached visual state immediately.
    // Reconcile once after reconnect; steady-state liveness comes from the
    // authenticated realtime socket lease and room-state deltas.
    unawaited(_refreshAfterRestore());
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
    if (!_joining || _presenceError != null) {
      setState(() {
        _joining = true;
        _presenceError = null;
      });
    }

    try {
      final roomState = await _roomSessionRepository.join(
        lockPassword: widget.lockPassword,
      );
      final snapshot = RoomSessionLegacyAdapter.toPresenceSnapshot(
        roomState,
        currentPublicUserId: widget.currentUser?.publicUserId,
      );
      if (!mounted) return;

      _seedIdentityFromPresence(snapshot);
      _livePresenceWarning.value = null;

      setState(() {
        _snapshot = snapshot;
        _joining = false;
        _presenceEstablished = true;
        _presenceError = null;
      });

      _showEnteredMessageIfNeeded(snapshot);
      _autoSeatIfAllowed(snapshot);
      await _roomSessionRealtimeBridge.activate();
    } catch (error) {
      if (!mounted) return;

      final message = _cleanPresenceError(error);
      if (_presenceEstablished) {
        _joining = false;
        _livePresenceWarning.value = message;
          return;
      }

        setState(() {
        _joining = false;
        _presenceError = message;
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
    _enteredUser.value = joinedUser;
    _enteredMessageTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _enteredUser.value = null;
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

  Future<void> _refreshAfterRestore() async {
    try {
      final roomState = await _roomSessionRepository.refreshAfterReconnect();
      final snapshot = RoomSessionLegacyAdapter.toPresenceSnapshot(
        roomState,
        currentPublicUserId: widget.currentUser?.publicUserId,
      );
      if (!mounted) return;
      _seedIdentityFromPresence(snapshot);
      _livePresenceWarning.value = null;
      setState(() {
        _snapshot = snapshot;
        _presenceError = null;
      });
      _autoSeatIfAllowed(snapshot);
    } catch (error) {
      if (!mounted) return;
      _livePresenceWarning.value = _cleanPresenceError(error);
    }
  }

  Future<void> _retryPresence() async {
    await _joinPresence();
  }

  bool get _shouldBlockRoomWithRetry {
    return !_presenceEstablished && _presenceError != null;
  }

  @override
  Widget build(BuildContext context) {
    final canonicalRoom = ref.watch(
      roomSessionRepositoryProvider(widget.roomId),
    );
    final canonicalOnlineCount = canonicalRoom.isJoined
        ? canonicalRoom.onlineCount
        : _onlineCount;

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
          onlineCount: canonicalOnlineCount,
          initialBackgroundTheme: widget.initialBackgroundTheme,
          restoreState: widget.restoreState,
        ),
        ValueListenableBuilder<SeatUser?>(
          valueListenable: _enteredUser,
          builder: (context, user, child) {
            if (user == null) return const SizedBox.shrink();
            return Positioned(
              top: MediaQuery.paddingOf(context).top + 66,
              left: 18,
              right: 18,
              child: _RoomEnteredSystemToast(user: user),
            );
          },
        ),
        ValueListenableBuilder<String?>(
          valueListenable: _livePresenceWarning,
          builder: (context, message, child) {
            if (message == null || message.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: MediaQuery.paddingOf(context).top + 112,
              left: 18,
              right: 18,
              child: const _RoomPresenceWarningToast(),
            );
          },
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
                          color: const Color(
                            0xFFE84C72,
                          ).withValues(alpha: 0.28),
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
                            onPressed: joining
                                ? null
                                : () => unawaited(onRetry()),
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

class _RoomPresenceWarningToast extends StatelessWidget {
  const _RoomPresenceWarningToast();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF120D1F).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFFFC857).withValues(alpha: 0.30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFFFC857),
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Presence reconnecting. Live audio stays active.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
