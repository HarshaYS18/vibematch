# Room Audio Input Runtime

Chunk 34-M11 registers the real local microphone stream with the foundation
resource runtime.

The participant is created only after `getUserMedia(audio)` succeeds and is
removed when the stream stops. It does not decide mute, seat or publishing
authorization.

Active room voice is preserved across background and ordinary memory pressure.
Authenticated-session teardown releases the local microphone device.
