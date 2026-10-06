# M4 — Localization + Growth / Deep Links

## Visual constraint

M4 does not redesign FunKey. Existing navigation, Settings language row,
Profile share icon and all product layouts remain in place.

No new Room, Vibe, Game, Event or Family share buttons are introduced in this
chunk. Their canonical link contracts are ready underneath the UI; adding new
visible entry points remains a separate product decision.

## Localization foundation

- FunKey now has application-localization infrastructure for English, Hindi and
  Telugu.
- Material, Widgets and Cupertino localization delegates are enabled.
- The existing Settings > Language control changes the real app locale and
  persists the preference without adding a new screen or control.
- The saved backend language is reconciled after authentication.
- Existing bottom-navigation labels and the core Settings language surface are
  localized first. The rest of the app can migrate string-by-string without a
  large UI rewrite.
- Languages already present in older settings but not translated in M4 safely
  fall back to English until their string catalog is added.

## Growth-link contract

Canonical destinations:

```text
funkey://room/<room-id>
funkey://vibe/<vibe-id>
funkey://profile/<public-user-id>
funkey://game/<game-id>
funkey://event/<event-id>
funkey://family/<family-id>
```

Optional query values:

- `ref=<public-user-id>` — non-authoritative referral attribution.
- `invite=<opaque-token>` — reserved family/invite token plumbing.

When `FUNKEY_SHARE_BASE_URL` is supplied at build time, the same contract can
emit and parse HTTPS links under that configured host/path. No production web
domain is invented in source control.

## Authentication / deferred routing

Incoming links are captured before or during login. They remain pending while:

- no authenticated user exists, or
- profile setup is still required.

After authentication/profile setup, the pending link is consumed exactly once
and routed through authoritative feature APIs:

- Room links load the authoritative room then use the normal join flow.
- Vibe links fetch the authoritative Vibe before opening detail.
- Profile links use the public-profile route.
- Game links verify the enabled Game Platform catalog/manifest entry.
- Event links open the existing Events UI with the requested event selected.
- Family links open the existing Family surface.

Recommendation, link metadata and referral data never become content,
permission, Economy or membership authority.

## Native handling

Android and iOS register the `funkey` custom scheme and use the existing native
shells to deliver cold/warm links to Flutter. Flutter's parallel default deep
link handler is disabled to avoid duplicate delivery.

The existing Profile share icon now opens the native platform share sheet on
Android/iOS and copies the canonical link on unsupported platforms/web.

Universal/App Links over HTTPS require the eventual production domain plus its
Digital Asset Links / Apple App Site Association files. M4 intentionally does
not invent that domain or commit fake association metadata.

## Family invite limitation

The current Family backend sends recipient-specific internal invites but does
not expose a public token-acceptance endpoint. M4 therefore carries and stores
an optional opaque invite token and opens the existing Family surface, but does
not auto-accept membership from a public link. Adding that server contract can
be done later without changing the FunKey visual UI.

## Validation

M4 is complete only after Flutter tests, analyzer, production web build and all
repository architecture/security/platform workflows are green on the
authoritative branch.
