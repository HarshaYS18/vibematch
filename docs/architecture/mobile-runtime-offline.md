# Mobile runtime / offline / battery architecture

Chunk 46 adds a bounded cross-platform offline read projection using the already
shipped SharedPreferences layer. It may cache small Home, public-profile,
room-preview, Vibe-feed and recent-search payloads. Media and large content stay
in normal HTTP/CDN caches.

Wallet, gift, purchase/payment, room membership/seat, moderation, auth and game
settlement commands are forbidden from offline queuing.

A first-party `funkey/power_state` MethodChannel reads Android battery/power-save
state and iOS battery/Low Power Mode without adding a plugin. Unsupported
platforms fall back safely. Background, low-battery and low-power modes disable
speculative prefetch while essential authenticated/realtime behavior keeps its
own lifecycle authority.

The existing session-scoped heavyweight resource coordinator remains the single
owner of decoders/WebViews/WebRTC/image/game-cache lifecycle.
