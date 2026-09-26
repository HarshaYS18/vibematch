# FunKey frontend architecture baseline

This document is the source of truth for Chunk 0 of the frontend architecture migration.

## Non-negotiable UI contract

Architecture work must not redesign the existing FunKey UI. Existing layout, colors, typography,
spacing, icons, animations and interaction affordances stay visually equivalent unless a separate
visual-defect change explicitly says otherwise.

The visual reference set is:

- Login
- Onboarding
- Home
- Room
- Room sheets
- Profile / Me
- Vibes
- Inbox
- Wallet
- Store
- Games
- Control Center

The machine-readable contract lives at
`frontend/vibematch_app/tool/frontend_baseline_manifest.json`.

## Baseline reference status

The migration reached the end of Chunk 5 before pixel goldens or device-profile
measurements were captured. That historical evidence cannot be reconstructed honestly.
The audited Chunk 5 head `b8189636eacda323cabcf2b07a2bedf94853737d` is therefore frozen in the manifest as the
**post-Chunk-5 / pre-Chunk-6 reference commit**.

This does not claim that Chunks 0-5 had zero pixel drift; it establishes a trustworthy
reference point for all work from Chunk 6 onward. Before any visual migration is approved,
run the strict baseline readiness check and capture the required goldens/profile metrics.

## Baseline capture protocol

Golden images are generated from the current UI implementation, never hand-authored. Run the
golden capture on the same Flutter version, device pixel ratio, viewport and font configuration
recorded by the manifest. Store approved captures under
`frontend/vibematch_app/test/goldens/baseline/`.

Runtime measurements must be taken in Flutter profile mode on the baseline Android device. Record:

- cold start to first useful frame
- authenticated shell ready time
- Home -> Vibes -> Inbox -> Me tab switch latency
- Home scroll frame timing
- room entry to authoritative snapshot rendered
- room reconnect to converged state
- process RSS after a five-minute room session
- major request count during one shell restore
- websocket connection count per authenticated session

Do not invent a number when a device run has not happened. The manifest stores `null` for an
uncaptured measurement and source review treats that as runtime verification still required.

## Current source-level debt snapshot

The pre-migration shell directly owns navigation, user refresh, presence heartbeat, inbox realtime,
wallet realtime, notification-banner state and app lifecycle behavior. Feature code also contains
multiple direct HTTP/WebSocket clients and process-global mutable state. Those are migration inputs,
not patterns to copy.

Dependency direction for migrated code is fixed as:

```text
UI
 -> Provider / ViewModel
 -> Repository
 -> Service / transport abstraction
 -> HTTP / realtime / media / persistence
```

Backend events return through the inverse path and produce immutable domain state. A feature UI may
select only the state it renders; it must not own transport lifecycles.

## Ownership rules

- Session owns authentication/session validity, device session and sign-out.
- Identity owns canonical display identity and profile completion.
- App shell owns tab selection/navigation only.
- Realtime owns application event delivery, sequence tracking and resync requests.
- Room session owns room presence, membership, admins, seats and room snapshot convergence.
- Media owns mediasoup/WebRTC transport and microphone/audio lifecycle.
- Watch Party owns synchronized playback state.
- Game platform owns remote-game hosting/bridge/session state.

Presence, durable room membership and microphone seat occupancy are separate concepts.

## Chunk 0 acceptance

Source-level baseline artifacts are complete when:

1. the UI contract/required screens are versioned;
2. the architecture ownership/dependency rules are versioned;
3. the runtime measurement schema and budgets are versioned;
4. tests can detect removal/corruption of the baseline manifest.

Golden pixels and profile-mode numbers are runtime evidence. They can only be marked captured after
an actual supported device/browser run; repository code must never fabricate them.


## Readiness checks

Structural baseline integrity runs in normal CI:

```bash
python scripts/check_frontend_baseline.py
```

Before approving any UI-affecting migration, the strict evidence gate must pass:

```bash
python scripts/check_frontend_baseline.py --require-runtime-evidence
```

Strict mode requires every declared golden file to exist with `captured: true` and every
runtime metric to contain a real measured value. It intentionally fails until supported
device/browser capture has actually been performed.
