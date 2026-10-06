# M3 — Discovery + Game Hub (UI-stable)

## Product constraint

M3 improves discovery behavior without changing FunKey's visual UI. Existing
Home header, banners, Trending/Following filters, room cards, Quick Match and
Games list remain the visible surfaces.

No Hago layout, tabs or visual components are copied into FunKey.

## Discovery behavior

- the existing Trending room list consumes the optional Recommendation
  projection and promotes recommended room IDs without changing room cards;
- recommendation failure is fail-open and never hides authoritative Home data;
- the existing Following filter remains the friends-active discovery surface;
- event discovery continues through the existing backend-owned Home banners;
- Quick Match cycles through currently available recommended public rooms first
  and falls back to the existing backend Quick Match endpoint;
- refresh errors keep the last usable Home room list visible.

## Game Hub behavior

The existing Games page keeps its current visual structure while becoming a
real discovery surface:

- only enabled games with verified remote manifests are eligible;
- per-user recently played games rank first;
- Recommendation-projection game candidates rank next;
- remaining catalog games use stable display-name ordering;
- opening a game records local per-user recent history;
- recent-history storage is convenience state only and is never gameplay or
  Economy authority;
- Recommendation remains disposable personalization and cannot authorize game
  access or change server-authoritative outcomes.

## Authority rules

PostgreSQL/Game Platform remain durable game/economy authority. Home/Room APIs
remain room/content authority. Recommendation output is only a reconstructable
ranking hint, exactly as defined by the existing Recommendation architecture.

## Visual non-goals

M3 intentionally does not add:

- new Home tabs or sections;
- Hago-styled cards;
- a different navigation shell;
- new colors, typography or layout language;
- Karaoke, PK, live video or 3D spaces.

If those later features cannot fit FunKey's current UI cleanly, they require a
separate product decision before implementation.

## Validation

M3 is complete only after Flutter tests, analyzer, production web build and the
full repository workflows are green on the authoritative branch.
