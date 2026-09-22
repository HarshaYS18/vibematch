from app.schemas.app_source_registry import (
    AppSourceRegistryResponse,
    SourceEndpoint,
    TabSourceRegistryItem,
)


MASTER_STATE = "/users/me/master-state"


def _endpoint(path: str, purpose: str, *, owner: str = "backend", realtime_safe: bool = True) -> SourceEndpoint:
    return SourceEndpoint(path=path, purpose=purpose, owner=owner, realtime_safe=realtime_safe)


def get_app_source_registry() -> AppSourceRegistryResponse:
    return AppSourceRegistryResponse(
        version=4,
        master_api=_endpoint(
            MASTER_STATE,
            "Authenticated user/profile/economy summary used as the app-level master read.",
        ),
        rules={
            "master_read": "Screens read broad identity/profile/economy state from the master API first.",
            "child_reads": "Feature tabs use child APIs only for feature-specific lists, pagination, or detail payloads.",
            "child_writes": "Mutations go through feature child APIs and must return or trigger canonical backend state.",
            "configs": "Display/config data comes from backend config/catalog/rule endpoints before any local fallback.",
            "control_center": "Owner/SuperAdmin Control Center APIs manage rules, catalog, roles, permissions, and stealth.",
            "live_room": "RoomSessionRepository owns canonical room lifecycle/state; /ws/room-realtime delivers authoritative snapshots and commands while media transport remains separate.",
        },
        tabs=[
            TabSourceRegistryItem(
                tab_key="home",
                label="Home",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/home-banners", "Home event/policy banner data."),
                    _endpoint("/vibes/feed", "Home feed content when shown on the home tab."),
                    _endpoint("/rooms/trending", "Room discovery summaries."),
                    _endpoint("/rooms/quick-match", "Backend-selected public room for one-tap matchmaking."),
                ],
                config_sources=[_endpoint("/control-center/source-of-truth", "Owner-visible source registry.")],
                control_center_modules=["Banner Manager", "Source Of Truth Registry"],
                duplicate_sources_to_retire=["local banner/feed demo data"],
                migration_status="active_backend_sources",
            ),
            TabSourceRegistryItem(
                tab_key="rooms",
                label="Rooms",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/rooms/trending", "Room discovery list."),
                    _endpoint("/rooms/my-created-room", "Current user's owned room card."),
                    _endpoint("/rooms/{room_public_id}/realtime/snapshot", "Canonical live-room read snapshot."),
                ],
                child_writes=[
                    _endpoint("/rooms/{room_public_id}/realtime/join", "Canonical room entry and privacy gate returning a full room snapshot."),
                    _endpoint("/rooms/{room_public_id}/realtime/heartbeat", "Presence heartbeat returning an explicitly marked partial room snapshot."),
                    _endpoint("/rooms/{room_public_id}/realtime/leave", "Canonical room exit returning final room state."),
                    _endpoint("/rooms/{room_public_id}/realtime/seat/take", "Canonical seat take/request mutation."),
                    _endpoint("/rooms/{room_public_id}/realtime/seat/leave", "Canonical seat leave mutation."),
                    _endpoint("/rooms/{room_public_id}/realtime/mic", "Canonical microphone state mutation."),
                    _endpoint("/rooms/{room_public_id}/realtime/watch-party/command", "Canonical Watch Party LOAD/PLAY/PAUSE/SEEK/CHANGE_CONTENT/SYNC/END/TRANSFER_CONTROL mutation returning authoritative room state."),
                    _endpoint("/rooms/{room_public_id}/realtime/activity/command", "Canonical karaoke, party and social-game room activity mutation and invite flow."),
                    _endpoint("/rooms/{room_public_id}/settings", "Room settings mutation while settings UI migrates onto RoomSessionRepository."),
                ],
                realtime_channels=["/ws/room-realtime"],
                protected_flows=["room entry", "privacy", "kickout", "seats", "gifts", "chat", "online count", "watch party", "room activities"],
                duplicate_sources_to_retire=[
                    "LiveRoomPresenceRepository lifecycle reads/writes after legacy UI adapters are retired",
                    "LiveRoomMembershipService process-global cache after all room consumers read RoomSessionRepository",
                    "LiveRoomMediaSignalingService roomSnapshot as domain state after media-only migration",
                    "room ranking mock fallback",
                    "local room background fallback after DB catalog migration",
                ],
                migration_status="canonical_room_session_active",
            ),
            TabSourceRegistryItem(
                tab_key="vibes",
                label="Vibes",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/vibes/feed", "Vibe feed."),
                    _endpoint("/vibes/saved", "Saved vibe feed."),
                    _endpoint("/vibes/{post_id}", "Single vibe detail."),
                ],
                child_writes=[
                    _endpoint("/vibes", "Create vibe post."),
                    _endpoint("/vibes/{post_id}/comments", "Comment mutations."),
                    _endpoint("/vibes/{post_id}/report", "Report mutations."),
                ],
                duplicate_sources_to_retire=["vibes mock/demo data"],
                migration_status="active_backend_sources",
            ),
            TabSourceRegistryItem(
                tab_key="inbox",
                label="Inbox",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/inbox/conversations", "Conversation list."),
                    _endpoint("/inbox/lock/status", "Inbox lock state."),
                    _endpoint("/inbox/backup/status", "Backup provider state."),
                ],
                child_writes=[
                    _endpoint("/inbox/messages", "Message send/update flows."),
                    _endpoint("/inbox/backup/*", "Backup actions."),
                ],
                realtime_channels=["/ws/inbox"],
                duplicate_sources_to_retire=["local conversation/demo notification fallbacks"],
                migration_status="active_backend_sources",
            ),
            TabSourceRegistryItem(
                tab_key="profile",
                label="Profile",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/profile-display/me", "Canonical current profile display payload."),
                    _endpoint("/profile-display/users/{public_user_id}", "Canonical public display payload."),
                    _endpoint("/users/{public_user_id}", "Public profile compatibility detail."),
                    _endpoint("/users/me/profile-visitors", "Profile visitor list."),
                ],
                child_writes=[
                    _endpoint("/users/me/profile", "Profile edits."),
                    _endpoint("/store/equip", "Equipped profile asset change."),
                ],
                config_sources=[
                    _endpoint("/store/catalog", "Profile asset catalog."),
                    _endpoint("/economy/rules", "Level and VIP rule source where exposed."),
                ],
                control_center_modules=["Economy Control Center", "Store Catalog Control Center", "Asset Control Center"],
                duplicate_sources_to_retire=["Me/Profile constants for VIP/SVIP/frames once all callers use canonical payload"],
                migration_status="foundation_canonical_payload_available",
            ),
            TabSourceRegistryItem(
                tab_key="wallet",
                label="Wallet",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/wallet/me", "Wallet balance and ledger summary."),
                    _endpoint("/economy/me", "Economy profile summary."),
                    _endpoint("/coin-sales/*", "Coin seller flows."),
                ],
                child_writes=[
                    _endpoint("/coin-sales/orders", "Coin purchase/sale order mutations."),
                    _endpoint("/super-owner/coins/*", "Owner coin supply mutations.", realtime_safe=False),
                ],
                control_center_modules=["Economy Control Center"],
                duplicate_sources_to_retire=["wallet mock data in legacy sheets"],
                migration_status="active_backend_sources",
            ),
            TabSourceRegistryItem(
                tab_key="vip_center",
                label="VIP Center",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/users/me/master-state", "Canonical VIP/SVIP current level."),
                    _endpoint("/control-center/economy/rules", "Owner-managed VIP/SVIP rule sets."),
                ],
                config_sources=[_endpoint("/control-center/economy/rules", "VIP/SVIP thresholds and labels.")],
                control_center_modules=["Economy Control Center"],
                duplicate_sources_to_retire=["VipProgramMockRepository reward/config defaults after public rules endpoint is added"],
                migration_status="current_level_canonical_config_foundation",
            ),
            TabSourceRegistryItem(
                tab_key="store",
                label="Store",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/store/catalog", "DB-backed store categories/items."),
                    _endpoint("/store/inventory", "User inventory/equipment."),
                ],
                child_writes=[
                    _endpoint("/store/purchase", "Purchase item."),
                    _endpoint("/store/equip", "Equip item."),
                ],
                config_sources=[_endpoint("/store/catalog", "Store category/item config and CDN assets.")],
                control_center_modules=["Store Catalog Control Center", "Asset Control Center"],
                duplicate_sources_to_retire=["local store/gift asset fallback lists after DB migration"],
                migration_status="foundation_db_catalog",
            ),
            TabSourceRegistryItem(
                tab_key="rankings",
                label="Rankings",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/rankings/*", "Global and period ranking data."),
                    _endpoint("/rooms/{room_public_id}/contribution-rankings", "Room contribution rankings."),
                ],
                config_sources=[_endpoint("/control-center/economy/rules", "Ranking level/rule display metadata.")],
                duplicate_sources_to_retire=["ranking mock-entry fallback builders"],
                migration_status="active_backend_sources_with_mock_fallbacks",
            ),
            TabSourceRegistryItem(
                tab_key="family",
                label="Family",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/families/me", "Current family state."),
                    _endpoint("/families/*", "Family detail/list flows."),
                    _endpoint("/families/economy/*", "Family economy and contribution flows."),
                ],
                child_writes=[_endpoint("/families/*", "Family create/update/join/admin actions.")],
                config_sources=[_endpoint("/control-center/economy/rules", "Family eligibility levels once public config is exposed.")],
                duplicate_sources_to_retire=["family mock data", "static family VIP requirement constants"],
                migration_status="active_backend_sources_with_local_config_fallbacks",
            ),
            TabSourceRegistryItem(
                tab_key="love_bonds",
                label="Love Bonds",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/love-bonds/me", "Current love bond state."),
                    _endpoint("/love-bonds/inventory", "Love bond inventory."),
                    _endpoint("/relationships/*", "Relationship EXP and summary flows."),
                ],
                child_writes=[_endpoint("/love-bonds/*", "Bond create/update actions.")],
                duplicate_sources_to_retire=["presentation-level program defaults once backend config endpoint exists"],
                migration_status="active_backend_sources",
            ),
            TabSourceRegistryItem(
                tab_key="notifications",
                label="Notifications",
                master_read=MASTER_STATE,
                child_reads=[_endpoint("/notifications", "Notification list and unread count.")],
                child_writes=[_endpoint("/notifications/*", "Mark read/delete actions.")],
                duplicate_sources_to_retire=["NotificationsMockData"],
                migration_status="active_backend_sources_with_mock_fallbacks",
            ),
            TabSourceRegistryItem(
                tab_key="search",
                label="Search",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/social/search", "User/social search."),
                    _endpoint("/rooms/search", "Room search where available."),
                ],
                duplicate_sources_to_retire=["local search suggestion fallbacks"],
                migration_status="active_backend_sources",
            ),
            TabSourceRegistryItem(
                tab_key="games",
                label="Games",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/games/master", "Game definitions and master config."),
                    _endpoint("/games/*", "Game play/detail/history flows."),
                ],
                child_writes=[_endpoint("/games/*", "Game play mutations.")],
                config_sources=[
                    _endpoint("/control-center/game-pools", "Game pool config."),
                    _endpoint("/control-center/game-props", "Game prop config."),
                ],
                control_center_modules=["Game Pool Management", "Game Props"],
                duplicate_sources_to_retire=["game local defaults after backend config parity"],
                migration_status="active_backend_sources",
            ),
            TabSourceRegistryItem(
                tab_key="control_center",
                label="Control Center",
                master_read=MASTER_STATE,
                child_reads=[
                    _endpoint("/control-center/source-of-truth", "Owner-visible source registry."),
                    _endpoint("/control-center/economy/rules", "Economy rules."),
                    _endpoint("/control-center/store/categories", "Store category management."),
                    _endpoint("/control-center/store/items", "Store item management."),
                    _endpoint("/super-owner/special-permissions/options", "Permission options."),
                ],
                child_writes=[
                    _endpoint("/control-center/economy/rules/{track_key}", "Update economy rules."),
                    _endpoint("/control-center/store/categories", "Upsert store category."),
                    _endpoint("/control-center/store/items", "Upsert store item."),
                    _endpoint("/control-center/stealth/*", "Stealth grant/toggle management."),
                ],
                control_center_modules=[
                    "Economy Control Center",
                    "Store Catalog Control Center",
                    "Asset Control Center",
                    "Role & Permission Control Center",
                    "Stealth Control Center",
                    "Source Of Truth Registry",
                ],
                migration_status="foundation_control_center_active",
            ),
        ],
        deferred_work=[
            "Replace remaining mock/fallback sources tab-by-tab only after each canonical child API is verified.",
            "Expose public economy rule/config reads for non-owner VIP/level screens before removing local display config.",
            "Retire live-room legacy UI caches/controllers only after each consumer has migrated to RoomSessionRepository; keep media signaling transport separate from room domain state.",
            "Add Control Center UI for viewing the source registry after product approves the placement.",
        ],
    )
