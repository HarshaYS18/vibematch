import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/live_room_audio_service.dart';

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

  @override
  void initState() {
    super.initState();
    LiveRoomAudioService.instance.remoteAudioRenderers.addListener(
      _syncAudioRouteRefreshTimer,
    );
    _syncAudioRouteRefreshTimer();
  }

  @override
  void dispose() {
    LiveRoomAudioService.instance.remoteAudioRenderers.removeListener(
      _syncAudioRouteRefreshTimer,
    );
    _audioRouteRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncAudioRouteRefreshTimer() {
    final hasRemoteAudio =
        LiveRoomAudioService.instance.remoteAudioRenderers.value.isNotEmpty;
    if (!hasRemoteAudio) {
      _audioRouteRefreshTimer?.cancel();
      _audioRouteRefreshTimer = null;
      return;
    }

    // ignore: avoid_print
    print('[VibeMatchAudio] remote renderer count=${LiveRoomAudioService.instance.remoteAudioRenderers.value.length}');
    unawaited(_preferSystemAudioRoute());
    _audioRouteRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_preferSystemAudioRoute()),
    );
  }

  Future<void> _preferSystemAudioRoute() async {
    if (kIsWeb) return;
    if (_audioRouteRefreshRunning) return;
    _audioRouteRefreshRunning = true;
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {
      // Audio route calls can fail on web/desktop or unsupported devices.
    } finally {
      _audioRouteRefreshRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RTCVideoRenderer>>(
      valueListenable: LiveRoomAudioService.instance.remoteAudioRenderers,
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
