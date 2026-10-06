# FunKey UI motion and asynchronous-state standard

This document defines the production UI behavior for page navigation, backend
loading, retry, empty states, and user-facing failure messages.

The goal is the fast, continuous feel expected from modern social/chat-room
applications without copying another product's visual design. The same rules
apply across Home, Rooms, Vibes, Inbox, Profile, Search, Store, Wallet, VIP,
Events, Family, Notifications and operator/control-center surfaces.

## 1. Route motion is global

All ordinary Material routes inherit `FunKeyPageTransitionsBuilder` from the
application theme. Named routes continue to go through `VmMotion.pageRoute`.
The live-room route keeps its dedicated entry geometry but shares the same
motion curves and standard transition primitive.

Production timings are intentionally short:

- normal page enter: 260 ms
- normal page exit: 220 ms
- main-tab transition: 210 ms
- modal sheet target: 220 ms enter / 180 ms reverse
- action feedback: 150 ms

Page motion combines a very small horizontal translation, low-amplitude scale,
and opacity ramp. The page being covered receives a tiny parallax/scale response
so navigation feels spatial without appearing theatrical.

Large zooms, long spring animations and full-screen crossfades are not allowed
for ordinary navigation because they increase perceived latency and decoder/
raster work.

## 2. Accessibility / reduced motion

Every canonical route transition checks `MediaQuery.disableAnimations`.
Reduced-motion users receive a minimal fade rather than translation and scale.
`VmFadeSlide` also becomes an immediate presentation when motion is disabled.

Feature code must not bypass this behavior with bespoke long animations unless
the animation is essential to understanding state.

## 3. Loading states

Use `VmLoadingState` for a blocking first load where there is no usable
authoritative or cached state yet.

Use a lightweight inline/linear loading indicator when:

- existing authoritative content remains usable;
- an individual action is in progress;
- pagination is appending content;
- a silent background refresh is running.

Do not blank a populated screen just because a refresh is in flight.

## 4. Failure and retry states

`VmFailurePresentation` is the only user-facing translation layer for generic
transport/backend failures. It classifies common conditions into:

- offline;
- timeout;
- unauthenticated/session expired;
- forbidden;
- not found;
- rate limited;
- server unavailable;
- cancelled;
- unknown/domain validation.

Use `VmFailureState` when the initial screen cannot be rendered because the
required backend state is unavailable.

Use `VmInlineFailure` when stale/previously loaded content can safely remain on
screen. This keeps the social experience usable during a transient network
failure while still exposing a clear Retry action.

A Retry control is shown only for failures that are locally retryable. Session
expiry and access-denied states must not create an infinite retry loop.

## 5. User-facing error wording

Transport implementation details must never be shown to normal users. Avoid
messages containing raw Dio error kinds, SocketException text, HTTP stack
details, internal hostnames, upstream service names, tracebacks or generic
`Exception:` prefixes.

Examples of canonical copy:

- offline: "You appear to be offline. Check your connection and try again."
- timeout: "This is taking longer than expected. Check your connection and try again."
- service failure: "FunKey is having trouble loading <content> right now. Please try again."
- expired session: "Your session has expired. Sign in again to continue."

Safe domain-validation messages returned by the backend may remain visible when
they are actionable, for example an already-used username.

## 6. Empty is not error

An authoritative successful response containing no data must render a real empty
state, not an error and not an endless spinner. Use `VmEmptyState` or the
feature's intentional empty-state design.

Examples:

- no rooms for the current language/filter;
- no notifications;
- no Vibes in a feed;
- no blocked users;
- empty transaction or ranking history.

## 7. State hierarchy

For an initial backend-backed screen, evaluate state in this order:

1. usable existing data, when safe;
2. blocking first-load state if no data exists;
3. blocking failure state if first load failed;
4. true empty state after a successful response;
5. normal content.

During refresh, preserve content and present any transient failure inline.

## 8. Navigation ownership

Do not introduce feature-specific route-animation implementations for ordinary
screens. Use the global Material transition or `VmMotion.pageRoute`.

Specialized routes such as Live Room may alter geometry to communicate where the
surface came from, but must still honor:

- the shared curves;
- short duration budgets;
- reduced-motion settings;
- symmetric and predictable reverse transitions.

## 9. Verification

Permanent tests cover:

- failure classification and safe user-facing copy;
- route-duration budgets;
- installation of the global Material transition builder;
- continued use of `VmMotion.pageRoute` by named routes;
- live-room integration with canonical route motion;
- presence of the canonical loading/failure/empty primitives.

CI remains the closure gate. A UI-state change is not complete if Flutter tests,
Flutter analyze or the production web build fail.
