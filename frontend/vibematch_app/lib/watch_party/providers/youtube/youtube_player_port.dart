import 'package:youtube_player_iframe/youtube_player_iframe.dart';

abstract interface class YoutubePlayerPort {
  Future<void> cueVideo({
    required String videoId,
    required double startSeconds,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seekToMs(int positionMs);
  Future<int> currentPositionMs();
  Future<List<double>> availablePlaybackRates();
  Future<void> setPlaybackRate(double playbackRate);
  Future<void> close();
}

class YoutubeIFramePlayerPort implements YoutubePlayerPort {
  YoutubeIFramePlayerPort(this.controller);

  final YoutubePlayerController controller;

  @override
  Future<void> cueVideo({
    required String videoId,
    required double startSeconds,
  }) {
    return controller.cueVideoById(
      videoId: videoId,
      startSeconds: startSeconds,
    );
  }

  @override
  Future<void> play() => controller.playVideo();

  @override
  Future<void> pause() => controller.pauseVideo();

  @override
  Future<void> seekToMs(int positionMs) {
    return controller.seekTo(
      seconds: positionMs.clamp(0, 1 << 62).toDouble() / 1000,
      allowSeekAhead: true,
    );
  }

  @override
  Future<int> currentPositionMs() async {
    final seconds = await controller.currentTime;
    return (seconds * 1000).round();
  }

  @override
  Future<List<double>> availablePlaybackRates() {
    return controller.availablePlaybackRates;
  }

  @override
  Future<void> setPlaybackRate(double playbackRate) {
    return controller.setPlaybackRate(playbackRate);
  }

  @override
  Future<void> close() => controller.close();
}
