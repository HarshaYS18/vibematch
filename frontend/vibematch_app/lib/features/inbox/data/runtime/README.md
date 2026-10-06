# Inbox Call Media Runtime

Chunk 34-M12 adds the feature-owned camera lifecycle adapter used by
`InboxCallMediaBridge`.

The bridge remains the owner of local call streams and mediasoup producers.
`CameraInputResourceParticipant` only coordinates the local video-input track
with app/session lifecycle.

Backgrounding pauses an enabled camera without ending call audio. Foreground
resumes only a lifecycle-paused camera. Memory pressure does not destroy an
active call. Session teardown releases the camera producer/track.

Inbox/backend remains durable call-session authority.


## M14 call microphone

`CallAudioInputResourceParticipant` registers the audio-input portion of an
Inbox call. Active call audio is preserved across background and ordinary memory
pressure; authenticated-session teardown releases the local audio producer and
track.
