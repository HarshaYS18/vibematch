import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../room_media/domain/room_media_engine.dart';
import '../../data/live_room_media_signaling_service.dart';

class LiveRoomRemoteAudioRenderers extends StatefulWidget {
  const LiveRoomRemoteAudioRenderers({super.key});

  @override
  State<LiveRoomRemoteAudioRenderers> createState() =>
      _LiveRoomRemoteAudioRenderersState();
}

class _LiveRoomRemoteAudioRenderersState
    extends State<LiveRoomRemoteAudioRenderers> {
  Timer? _audioRouteRefreshTimer;
  bool _audioRouteRefreshRunning = false;

  RoomMediaEngine get _mediaEngine =>
      LiveRoomMediaSignalingService.instance.mediaEngine;

  @override
  void initState() {
    super.initState();
    _mediaEngine.remoteAudioRenderers.addListener(_syncAudioRouteRefreshTimer);
    _syncAudioRouteRefreshTimer();
  }

  @override
  void dispose() {
    _mediaEngine.remoteAudioRenderers.removeListener(
      _syncAudioRouteRefreshTimer,
    );
    _audioRouteRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncAudioRouteRefreshTimer() {
    final hasRemoteAudio = _mediaEngine.remoteAudioRenderers.value.isNotEmpty;
    if (!hasRemoteAudio) {
      _audioRouteRefreshTimer?.cancel();
      _audioRouteRefreshTimer = null;
      return;
    }

    // ignore: avoid_print
    print(
      '[VibeMatchAudio] remote renderer count='
      '${_mediaEngine.remoteAudioRenderers.value.length}',
    );
    unawaited(_preferSystemAudioRoute());
    _audioRouteRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_preferSystemAudioRoute()),
    );
  }

  Future<void> _preferSystemAudioRoute() async {
    if (_audioRouteRefreshRunning) return;
    _audioRouteRefreshRunning = true;
    try {
      await _mediaEngine.preferSystemAudioRoute();
    } finally {
      _audioRouteRefreshRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RTCVideoRenderer>>(
      valueListenable: _mediaEngine.remoteAudioRenderers,
      builder: (context, renderers, _) {
        if (renderers.isEmpty) return const SizedBox.shrink();

        // Keep the audio elements mounted inside the visible page tree.
        // On Flutter Web, fully off-screen WebRTC media elements can fail to
        // autoplay or attach audio output in some browser/device combinations.
        return Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.01,
              child: Stack(
                children: [
                  for (final renderer in renderers)
                    SizedBox(
                      width: 1,
                      height: 1,
                      child: RTCVideoView(
                        renderer,
                        mirror: false,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
