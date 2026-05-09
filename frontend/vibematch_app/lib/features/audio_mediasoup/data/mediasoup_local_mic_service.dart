import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediasoupLocalMicService {
  MediaStream? _localStream;

  MediaStream? get localStream => _localStream;
  bool get hasMicStream => _localStream != null;

  Future<MediaStream> startMic() async {
    final existing = _localStream;
    if (existing != null) return existing;

    final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': <String, dynamic>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    _localStream = stream;
    return stream;
  }

  void setMuted(bool muted) {
    final tracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      track.enabled = !muted;
    }
  }

  Future<void> stopMic() async {
    final stream = _localStream;
    _localStream = null;

    if (stream == null) return;

    for (final track in stream.getTracks()) {
      await track.stop();
    }

    await stream.dispose();
  }

  Future<void> dispose() async {
    await stopMic();
  }
}
