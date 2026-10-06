# M2 — Product Surface Integrity & Accessibility

## Purpose

M2 is the pre-product-expansion closure gate after M1. It fixes places where
FunKey's production architecture was stronger than its user-facing integration.
It does not add a new backend authority or redesign the application.

## Repairs in this chunk

- system text scaling is no longer globally forced below the user's platform
  preference;
- global Material tap targets return to accessible padded behavior and primary
  button/icon targets use a 44 logical-pixel minimum;
- Home, Vibes, Notifications and the Games entry preserve last-known-good
  content when a refresh fails instead of destructively blanking usable state;
- tapping a Vibe author opens the real public profile;
- Vibe Search results now fetch the canonical backend Vibe and open the real
  detail surface;
- raw invite exceptions are normalized through `VmFailurePresentation`;
- the owner profile no longer exposes the engineering-only
  `GameTestPage`;
- the canonical `/games` named route now opens a consumer-facing, backend
  catalog-driven remote-games surface;
- `AppRouteFactory` no longer maps named routes to `VmSkeletonPage`.
  Historical room-scoped/deprecated links fall through to the honest
  unsupported-link guard rather than pretending a feature page exists;
- static regression guards now enforce route-surface integrity,
  accessibility bootstrap rules, production GameTest isolation and raw error
  presentation policy.

## Non-goals

M2 is not the full Game Hub/discovery redesign. It deliberately does not add
Karaoke, room-vs-room PK, live video, 3D spaces, new microservices or a second
state architecture. Those are product-expansion decisions after closure.

## Validation gate

M2 is complete only when the authoritative branch passes:

1. Flutter tests;
2. Flutter analyzer;
3. production web build;
4. Frontend architecture guard;
5. Backend Media Architecture;
6. Service Contracts;
7. Production Platform;
8. Security Supply Chain;
9. Docs and Architecture Conformance;
10. Final Architecture Audit.

Real-device accessibility/performance and soak evidence remains a release
certification requirement rather than something CI can fabricate.
