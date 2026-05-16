import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/live_room_audio_service.dart';

class LiveRoomRemoteAudioRenderers extends StatefulWidget {
  const LiveRoomRemoteAudioRenderers({super.key});

  @override
  State<LiveRoomRemoteAudioRenderers> createState() => _LiveRoomRemoteAudioRenderersState();
}

class _LiveRoomRemoteAudioRenderersState extends State<LiveRoomRemoteAudioRenderers> {
  Timer? _audioRouteRefreshTimer;
  bool _audioRouteRefreshRunning = false;

  @override
  void initState() {
    super.initState();
    LiveRoomAudioService.instance.remoteAudioRenderers.addListener(_syncAudioRouteRefreshTimer);
    _syncAudioRouteRefreshTimer();
  }

  @override
  void dispose() {
    LiveRoomAudioService.instance.remoteAudioRenderers.removeListener(_syncAudioRouteRefreshTimer);
    _audioRouteRefreshTimer?.cancel();
    super.dispose();
  }

  void _syncAudioRouteRefreshTimer() {
    final hasRemoteAudio = LiveRoomAudioService.instance.remoteAudioRenderers.value.isNotEmpty;
    if (!hasRemoteAudio) {
      _audioRouteRefreshTimer?.cancel();
      _audioRouteRefreshTimer = null;
      return;
    }

    unawaited(_preferBluetoothOrSystemAudioRoute());
    _audioRouteRefreshTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_preferBluetoothOrSystemAudioRoute()),
    );
  }

  Future<void> _preferBluetoothOrSystemAudioRoute() async {
    if (_audioRouteRefreshRunning) return;
    _audioRouteRefreshRunning = true;
    try {
      // Do not force loudspeaker for WebRTC room audio.
      // On Android this lets the OS route audio to a connected Bluetooth headset/speaker.
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {
      // Audio route calls can fail on web/desktop or unsupported devices. Room audio should continue.
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

        return Positioned(
          left: -120,
          top: -120,
          width: 80,
          height: 80,
          child: IgnorePointer(
            child: Stack(
              children: [
                for (final renderer in renderers)
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: RTCVideoView(
                      renderer,
                      mirror: false,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
