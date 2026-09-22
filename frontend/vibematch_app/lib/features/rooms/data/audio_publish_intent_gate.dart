class AudioPublishIntentGate {
  int _generation = 0;

  int capture() => _generation;

  void invalidate() {
    _generation += 1;
  }

  bool isCurrent(
    int generation, {
    required bool seated,
    required bool muted,
  }) {
    return generation == _generation && seated && !muted;
  }
}
