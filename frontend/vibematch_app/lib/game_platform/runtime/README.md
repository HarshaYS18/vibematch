# Game Platform Runtime

This directory owns Flutter-side execution boundaries for verified remote game
content. It is not durable game authority.

## Core runtime

`GameRuntime` is the provider-independent execution interface.
`web/in_app_webview_game_runtime.dart` is the concrete sandboxed WebView
implementation. Remote HTML communicates with FunKey only through the allowlisted
Host Bridge and never receives the app bearer token.

## Resource lifecycle

Chunk 34-M7 adds `GameWebViewResourceParticipant`. The participant depends on
the foundation `MediaResourceRegistry` contract, not on AppShell runtime
implementation.

Foreground/background and memory-pressure notifications are forwarded as
non-authoritative host events. Normal feature disposal still belongs to
`RemoteGamePlayerPage`; authenticated-session teardown can additionally
release the runtime through the registry. Durable game sessions, rounds, bets
and settlement remain backend authorities.
