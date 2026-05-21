# Economy Control Center Source Of Truth Audit

Branch: `inbox-v3-local-update` tracking `origin/inbox-v3-clean-ui-rebuild`

This audit started as the `economy-control-center-source-of-truth-v1` foundation pass. The continuation pass was applied on the Inbox changes branch after Inbox was completed, preserving stable live-room entry, privacy, settings, seats, gifts, chat, and profile navigation.

## Current Backend Sources

- Wallet and balances: `backend/app/models/economy.py`, `backend/app/services/economy_service.py`, `backend/app/api/routes/economy.py`, `backend/app/api/routes/wallet/__init__.py`.
- VIP/SVIP status: `backend/app/models/vip_status.py`, `backend/app/services/economy_level_service.py`, `backend/app/services/vip_status_service.py`.
- Sent/received/room EXP: `backend/app/models/experience.py`, `backend/app/services/experience_service.py`, `backend/app/services/level_progression_service.py`.
- Rankings: `backend/app/api/routes/rankings.py`, `backend/app/models/economy_stats.py`, `backend/app/services/rooms/room_contribution_service.py`.
- Store and equipped assets: `backend/app/models/store.py`, `backend/app/services/store_service.py`, `backend/app/api/routes/store.py`.
- Gift catalog: `backend/app/models/gift_catalog.py`, `backend/app/services/gift_catalog_service.py`, `backend/app/api/routes/gift_catalog.py`.
- Roles and permissions: `backend/app/models/role.py`, `backend/app/models/special_permission.py`, `backend/app/services/role_service.py`, `backend/app/services/special_permission_service.py`, `backend/app/services/permissions/room_permission_service.py`, `backend/app/api/routes/admin.py`.
- Public profile payload: `backend/app/services/profile_service.py`, `backend/app/api/routes/users.py`.
- Room participant/profile snapshot: `backend/app/services/rooms/room_service.py`, `backend/app/services/rooms/room_state_service.py`.

## Current Flutter Sources

- Store catalog UI and repository: `frontend/vibematch_app/lib/features/store/...`.
- Live-room seats/chat/mini profile: `frontend/vibematch_app/lib/features/rooms/presentation/...`, `frontend/vibematch_app/lib/features/rooms/data/live_room_presence_repository.dart`, `frontend/vibematch_app/lib/features/rooms/data/live_room_media_signaling_service.dart`.
- VIP/SVIP badges/assets: `frontend/vibematch_app/lib/features/rooms/presentation/widgets/vip_badge.dart`, `frontend/vibematch_app/lib/core/assets/vip_svip_tag_assets.dart`.
- Economy master client: `frontend/vibematch_app/lib/features/economy/data/economy_master_api_service.dart`.
- Control Center: `frontend/vibematch_app/lib/features/control_center/...` and `frontend/vibematch_app/lib/features/profile/presentation/control_center/...`.

## Duplicate Or Legacy Sources Found

- Level thresholds were hardcoded in `level_progression_service.py`. This pass adds DB-backed `economy_rule_sets` and `economy_rule_levels`, seeds them from the existing stable table, and routes live economy calculations through the DB rule service with the old code as fallback.
- Store categories were hardcoded in `store_service.CATEGORY_ORDER` and local Flutter category labels. This pass adds DB-backed `store_categories` and Control Center CRUD while keeping labels as UI fallback.
- Store defaults still seed from `DEFAULT_STORE_ITEMS` for closed-beta continuity. They are now folded into DB catalog state and can be replaced category/item-by-item.
- Profile display data was spread across profile, economy, room snapshot, and store inventory payloads. This pass adds `/profile-display/*` and `CanonicalUserDisplayModel` as the shared payload.
- Stealth state used room participant flags and an older marker in `User.interests`. This pass adds `user_stealth_states`; room visibility flags remain the runtime source for each active room session.
- Several mock/demo Flutter sources remain outside the safest live-room path, including VIP program mock repository, event/social/demo data, and some gift fallback data.
- Me page hero display still read VIP/SVIP/name/avatar/cover/role fields from profile and wallet payloads before the continuation pass.
- Public Profile header, mini-profile seat target, and follower/following entry payloads still mixed public profile, economy public card, and widget seed values before the continuation pass.
- Live-room mini profile economy lookup used economy summary endpoints before canonical profile display.
- Room contribution ranking rows parsed legacy economy/ranking user fields only, so canonical profile-display decorations could be dropped even when the backend supplied them.
- Control Center economy/store write routes had service-level audit behavior but did not all repeat the same explicit owner access check used by read routes.

## Canonical Sources After This Pass

- App/tab source registry: `GET /app/source-of-truth/master` and owner-only `GET /control-center/source-of-truth`. The full per-tab audit lives in `docs/application_source_of_truth_tabs_audit.md`.
- Economy balances: `user_wallets` and `wallet_ledger`.
- VIP/SVIP visible status: `user_vip_statuses`, derived from wallet ledger using active `economy_rule_sets`.
- Sent/received/room levels: `user_experience_statuses`, `room_experience_statuses`, and active `economy_rule_sets`.
- Ranking source: gift/ledger/stat tables and existing ranking endpoints; materialized `ranking_snapshots` remains available for later scheduled snapshots.
- Store catalog: `store_categories`, `store_items`, and `store_asset_manifests`.
- Inventory/equipment: `user_store_inventory`.
- Shared display payload: `/profile-display/me` and `/profile-display/users/{public_user_id}`. Me, Public Profile, mini profile economy lookup, and backend ranking-row parsing now prefer this payload where it is safely available. Embedding this payload into room realtime snapshots is still deferred because the stable live-room sync path must remain untouched until a dedicated verification pass.
- Roles/permissions: `user_roles`, `special_permissions`, and centralized role/room permission services.
- Stealth eligibility/state: `special_permissions.USE_STEALTH` and `user_stealth_states`; per-room public visibility still comes from room participant visibility flags.

## Inbox Branch Continuation Migration

- Me page: `MePageContent` now loads `ProfileDisplayRepository.getMe()` and uses canonical display name, public/display ID, role label, VIP/SVIP levels, avatar URL, and cover photo URL before legacy profile/wallet fallbacks.
- Public Profile page: `PublicProfileViewPage` now loads `ProfileDisplayRepository.getPublicUser(public_user_id)` and uses canonical display name, username, public/display ID, verified flag, role label, VIP/SVIP, sent/received levels, monthly sent/received coins, avatar, cover photo, equipped avatar frame/chat bubble, and name gradient before legacy profile/economy/widget fallbacks.
- Live-room mini profile: `MiniProfileEconomyService` now tries `/profile-display/users/{public_user_id}` before economy summary endpoints, keeping the old economy and seat-user fallbacks inside the service layer.
- Ranking rows: `RoomContributionRankingsApiService` now accepts canonical `sent_level`, `received_level`, `monthly_sent_coins`, `monthly_received_coins`, `name_gradient`, and `equipped_items` fields when backend ranking payloads include them.
- Control Center: owner-only access is now explicitly checked for economy rule writes, store category writes, store item writes, and store manifest imports, matching the existing owner-only read/preview route behavior.

## Files Changed In Continuation Pass

- `backend/app/api/routes/control_center.py`
- `frontend/vibematch_app/lib/features/profile/presentation/widgets/me_page_content.dart`
- `frontend/vibematch_app/lib/features/profile/presentation/public_profile_view_page.dart`
- `frontend/vibematch_app/lib/features/profile/presentation/public_profile_view_controller.dart`
- `frontend/vibematch_app/lib/features/profile_display/models/canonical_user_display_model.dart`
- `frontend/vibematch_app/lib/features/rooms/data/mini_profile_economy_service.dart`
- `frontend/vibematch_app/lib/features/rooms/data/room_contribution_rankings_api_service.dart`
- `docs/economy_control_center_source_of_truth_audit.md`

## Safe Migration Order

1. Apply DB migration `20260518_0100_economy_control_foundation.py`.
2. Let `/control-center/economy/rules` seed rule sets from the previous hardcoded thresholds.
3. Verify `/economy/me`, `/economy/users/{id}/public-card`, and gift sends still return the same levels.
4. Add/edit store categories/items through Control Center and confirm `/store/catalog` reflects DB category order.
5. Verify `/profile-display/users/{public_user_id}` matches existing backend profile/economy values without wiring it into live-room realtime yet.
6. Migrate remaining store/gift assets from local fallback lists to DB catalog entries in small batches.
7. Replace remaining mock-only screens after each screen has a canonical endpoint and analyze passes.

## Deferred Work

- Full migration of gift panel fallback items is deferred because gift sending is stable and has a separate catalog editor.
- VIP program reward/config defaults remain in `VipProgramMockRepository` until a public economy rules/config endpoint is exposed for that screen.
- Local room ranking preview builders remain as offline/error fallbacks. Backend ranking endpoints and canonical ranking payload parsing are preferred when available.
- Public profile cover placeholder and empty public Vibes list remain display-only fallbacks for missing backend media/feed data.
- Live-room seats, chat sender snapshots, and realtime peer snapshots are intentionally left on the stable pre-foundation data path. Canonical display wiring there needs a dedicated two-window realtime verification pass before it is introduced.
- Scheduled ranking materialization for hourly/daily/weekly/monthly periods is deferred; current ranking endpoints calculate from ledger/gift tables.
- Asset manifest rollback UI is deferred. The backend stores manifest imports and validation results, but rollback needs a product decision around version pinning.
- Fine-grained permission-grant UI for every new special permission is deferred; backend enum/service support is in place and existing Control Center role/permission tools remain active.

## Verification Results

- Passed on the Inbox changes branch: `cd frontend/vibematch_app && flutter analyze` (`No issues found!`).
- Passed on the Inbox changes branch: `cd frontend/vibematch_app && flutter test test/widget_test.dart`.
- Passed because backend route code changed: `cd backend && python -m compileall app`.
- Passed: `git diff --check` exited successfully. Git printed existing CRLF normalization warnings for tracked files.
