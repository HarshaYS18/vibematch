import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/app/runtime/vibes_media_resource_participant.dart';
import 'package:vibematch_app/features/vibes/presentation/widgets/vibe_media_playback_gate.dart';

/// Chunk 34-M3 behavioral coverage for Vibes resource lifecycle migration.
void main() {
  test('background pause lock composes with existing tab pause state', () async {
    final gate = VibeMediaPlaybackGate(initiallyPaused: false);
    addTearDown(gate.dispose);
    final participant = VibesMediaResourceParticipant(playbackGate: gate);

    expect(gate.feedPlaybackPaused.value, isFalse);

    await participant.onForegroundChanged(false);
    expect(gate.feedPlaybackPaused.value, isTrue);

    // Tab becomes inactive while app is backgrounded.
    gate.setTabPaused(true);
    await participant.onForegroundChanged(true);

    // Foreground removes only the lifecycle lock; tab ownership still pauses.
    expect(gate.feedPlaybackPaused.value, isTrue);

    gate.setTabPaused(false);
    expect(gate.feedPlaybackPaused.value, isFalse);
  });

  test('memory pressure clears active decoder ownership and advances trim tick', () async {
    final gate = VibeMediaPlaybackGate(initiallyPaused: false);
    addTearDown(gate.dispose);
    final participant = VibesMediaResourceParticipant(playbackGate: gate);

    gate.claimActiveFeedVideo('vibe-1');
    final beforeTick = gate.feedScrollTick.value;
    expect(gate.activeFeedVideoKey.value, 'vibe-1');

    await participant.onMemoryPressure();

    expect(gate.activeFeedVideoKey.value, isNull);
    expect(gate.feedScrollTick.value, beforeTick + 1);
  });

  test('session release pauses Vibes and requests a final trim', () async {
    final gate = VibeMediaPlaybackGate(initiallyPaused: false);
    addTearDown(gate.dispose);
    final participant = VibesMediaResourceParticipant(playbackGate: gate);

    gate.claimActiveFeedVideo('vibe-2');
    final beforeTick = gate.feedScrollTick.value;

    await participant.release();

    expect(gate.feedPlaybackPaused.value, isTrue);
    expect(gate.activeFeedVideoKey.value, isNull);
    expect(gate.feedScrollTick.value, beforeTick + 1);
  });
}
