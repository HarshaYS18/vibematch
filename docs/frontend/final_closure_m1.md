# Final Closure M1 — Baseline Verification and UI State/Motion Audit

## Purpose

M1 closes the first production-closure gate after the application-wide motion, loading, retry, and failure-presentation work.

It does **not** redesign FunKey, change durable authorities, or introduce new infrastructure. It verifies the existing branch, repairs regressions, and enforces the canonical presentation contracts already introduced.

## Authoritative branch

`chatgpt/funkey-frontend-architecture-v1`

The branch must preserve all legitimate work newer than:

`6733b2ea831d8a8f56cd3453272369d1f5d684b2`

No reset to the historical checkpoint is allowed.

## Baseline findings

The audit found that the branch had advanced substantially beyond the historical transition/state commit, so the newer branch state was treated as authoritative.

The current closure wave exposed three CI failures:

- Flutter tests failed because presentation helper widgets had been accidentally removed while their callers remained.
- A room contribution rankings file imported `vm_failure.dart` from the wrong relative path.
- Gitleaks reported an exact historical false-positive in `SECURITY.md` security-policy prose.

The UX/state audit also found one remaining feature-owned `PageRouteBuilder` in the Inbox Story Viewer.

## Repairs

The following repairs were applied without changing product layout or durable application behavior:

- restored Account Settings presentation helper widgets while retaining canonical loading/failure states;
- restored Vibes report-review helper widgets while retaining canonical failure presentation and sheet motion;
- corrected the Room Contribution Rankings `VmFailurePresentation` import path;
- added an exact fingerprint ignore for the historical `SECURITY.md` Gitleaks false-positive;
- migrated Inbox Story Viewer navigation to `VmMotion.pageRoute` with a zero slide offset, removing the feature-owned `PageRouteBuilder`.

## Canonical UI contracts verified

The M1 audit checks the recent closure surface against these rules:

1. Modal bottom sheets use `VmMotion.sheetAnimationStyle`.
2. Feature code does not own arbitrary `PageRouteBuilder` implementations.
3. User-facing backend/network failures pass through `VmFailurePresentation`.
4. Initial loading, inline failure, full failure and retry states reuse the common presentation layer where applicable.
5. Background-refresh failures should preserve previously usable content rather than destructively replacing it.
6. Reduced-motion behavior remains centralized in the shared motion layer.
7. No Hago-style product polish is allowed to bypass FunKey's design system or create a parallel navigation/state architecture.

The permanent regression guard is:

`frontend/vibematch_app/test/ui_motion_surface_guard_test.dart`

## Validation gate

M1 is complete only when the final branch HEAD passes all relevant PR workflows, including:

- Frontend architecture guard
- Backend Media Architecture
- Service Contracts
- Production Platform
- Security Supply Chain
- Docs and Architecture Conformance
- Final Architecture Audit

The Flutter workflow must reach tests, analyzer, and production web build successfully; a compile failure before analyzer/build is not acceptable evidence.

## Residual work after M1

M1 deliberately does not perform product expansion. Once this gate is green, the next closure phase should focus on dead-code/assets cleanup and remaining production-polish issues, while preserving the existing architecture and UI contracts.

External release qualifications that require real deployment/device evidence remain separate from repository closure, including real-device profile-mode performance measurements and production CDN/runtime configuration where applicable.
