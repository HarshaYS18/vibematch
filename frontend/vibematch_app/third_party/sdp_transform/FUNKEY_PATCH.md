# FunKey patch notes

This directory vendors upstream `sdp_transform 0.3.2` under its MIT license.

Local change:
- `lib/src/parser.dart`: remove the unconditional
  `print("trying to add null key")` emitted for the grammar's intentional
  unnamed fallback entry.

Parsing behavior is unchanged. Unknown SDP attributes are still preserved by
the existing `invalid` fallback collection.

Reason: `flutter_webrtc` exercises this parser during normal WebRTC
negotiation, so the upstream debug print polluted otherwise healthy FunKey
room-audio logs.
