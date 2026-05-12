import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/live_room_audio_service.dart';

class LiveRoomRemoteAudioRenderers extends StatelessWidget {
  const LiveRoomRemoteAudioRenderers({super.key});

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
