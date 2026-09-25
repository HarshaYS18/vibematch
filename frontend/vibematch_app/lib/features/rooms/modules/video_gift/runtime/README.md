# Video Gift Runtime

The production live-room gift video path is
`presentation/clean_video_gift_overlay.dart`.

Chunk 34-M10 adds `GiftVideoResourceParticipant` for the widget-owned
`VideoPlayerController`. It depends only on the foundation resource lifecycle
contract.

Background lifecycle pauses playback and remembers whether it should resume.
Memory pressure and authenticated-session teardown may release the ephemeral
decoder and finish the local gift presentation.

This runtime owns no gift settlement, wallet, combo or durable room state.
