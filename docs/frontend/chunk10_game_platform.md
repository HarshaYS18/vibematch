# Chunk 10 — Remote Game Platform v1

Chunk 10 moves gameplay delivery out of the Flutter application package and puts it behind a
versioned, integrity-checked runtime boundary. The existing room **Games** entry and sheet remain
visually unchanged; only the launch/runtime ownership changes.

## Ownership

The canonical dependency direction is:

```text
Room UI
  -> RemoteGamePlayerPage
  -> GameManifestRepository
     -> backend /games/catalog/{game_id}
     -> HTTPS game manifest
     -> SHA-256 verified single-HTML bundle
  -> GameRuntime
     -> InAppWebViewGameRuntime
     -> GameHostBridge
     -> AppNetworkClient
     -> authoritative backend game/economy APIs
```

Room membership, chat, seats, presence, gifts, room audio and Watch Party do not depend on the game
runtime. A game WebView never owns or opens the FunKey application realtime channel.

## Backend registry contract

The existing game catalog is the registry. Each enabled remotely delivered game must provide:

- `game_key`
- `config_version`
- `min_app_version`
- `cdn_base_url` (HTTPS)
- `asset_manifest_url` (HTTPS)

The backend remains authoritative for whether a game is enabled and for all economy/risk/settlement
state. Updating a game means publishing a new immutable bundle/manifest, increasing
`config_version`, and then updating the backend catalog. Clients reject a manifest whose
`game_id` or `config_version` does not match the catalog record.

## Manifest v1

Chunk 10 intentionally uses a small contract rather than loading an arbitrary web application:

```json
{
  "schema_version": 1,
  "game_id": "jungle_hunt",
  "config_version": 5,
  "bridge_version": 1,
  "bundle_format": "single_html",
  "entry_path": "index.html",
  "entry_sha256": "<64 lowercase hex characters>",
  "allowed_origins": [
    "https://games-cdn.example.com"
  ]
}
```

Rules:

1. Manifest and bundle URLs are HTTPS only.
2. `game_id` and `config_version` must match the backend catalog.
3. `bridge_version` must be supported by the app.
4. v1 accepts only `single_html`.
5. The complete HTML bundle is limited to 5 MiB and is verified with SHA-256 before execution.
6. External executable dependencies (`<script src>`, iframe/object/embed) are rejected.
7. A restrictive CSP disables direct network APIs from the game document. Visual/media assets may
   come only from manifest-declared HTTPS origins.
8. The app bearer token is never injected into JavaScript or the DOM.

## Host bridge v1

Remote game code calls only:

```js
await window.FunKeyHost.request("game.round.create")
await window.FunKeyHost.request("game.round.get", { roundId })
await window.FunKeyHost.request("game.bet.place", { roundId, targetId, amount })
await window.FunKeyHost.request("game.round.settle", { roundId })
await window.FunKeyHost.request("game.history", { limit: 30 })
await window.FunKeyHost.request("host.context")
await window.FunKeyHost.request("host.close")
```

The host validates the method and parameters, adds authentication itself, and accepts round commands
only for round IDs created inside that runtime session. The remote document receives command
results, never credentials.

The current settle command preserves the existing Jungle Hunt backend contract. It is not a
general client-authoritative settlement design; the backend remains the final authority and can
change that endpoint without widening the bridge.

## Cache and rollback

Verified bundles are cached by:

```text
game_id + config_version + entry_sha256
```

A changed version/hash produces a different cache key. Disabling a game or removing its remote
manifest configuration invalidates that game's cached entry. Because catalog version and manifest
version must agree, rollback is performed by publishing/updating an explicit catalog version rather
than silently serving different bytes under an existing version.

Chunk 10 uses an in-process verified-bundle cache. It deliberately does not persist executable HTML
across application launches; that keeps first-version rollback and cache invalidation simple and
forces integrity verification after a process restart.

## Flutter package migration

The Flutter asset manifest no longer includes `assets/games/jungle_hunt/**`. Those repository
assets may remain temporarily as migration/source material, but they are not shipped in the app
bundle and the room flow cannot import the legacy Jungle Hunt gameplay pages.

The architecture guard fails if:

- game-platform code creates a raw websocket;
- raw game WebView access escapes `game_platform/runtime/web`;
- room code imports the legacy bundled Jungle Hunt gameplay pages;
- `pubspec.yaml` begins bundling `assets/games/**` or a `games_raw/**` package again.

Legacy gameplay source can be deleted after the production CDN bundle has been published and smoke
tested. It is intentionally unreachable now so the migration does not pretend that external CDN
deployment has already happened.

## CDN deployment prerequisite

Repository code cannot provision the production CDN by itself. Before Jungle Hunt is usable through
the new runtime in a deployed environment, operations must:

1. produce a self-contained `index.html` compatible with Host Bridge v1;
2. publish it to the production HTTPS CDN;
3. calculate its SHA-256;
4. publish Manifest v1 beside it;
5. update the backend Jungle Hunt catalog with the CDN/manifest URLs and a matching
   `config_version`;
6. smoke test login, room entry, game open, round creation, betting, result, close/reopen and app
   realtime continuity.

Until those values are configured, the app fails closed with **Game unavailable** instead of
falling back to bundled gameplay.

## Acceptance

Chunk 10 is source-complete when:

- room Jungle Hunt launches `RemoteGamePlayerPage`;
- game assets are absent from Flutter's packaged asset list;
- manifest schema/version/HTTPS/SHA rules are tested;
- tampered bundles are rejected;
- the bridge does not expose credentials and rejects unknown methods/foreign round IDs;
- game runtime does not create another app websocket;
- architecture guard, Flutter tests/analyze and production web build pass.

Production CDN publication is deployment configuration, not repository evidence, and must not be
fabricated in source control.
