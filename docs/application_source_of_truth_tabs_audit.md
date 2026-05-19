# Application Source Of Truth Tabs Audit

Branch: `economy-control-center-source-of-truth-v1`

This is a foundation and safe wiring pass. It does not redesign UI, and it does not change the stable live-room realtime behavior. The goal is to make the source contract explicit for every visible tab so future rewiring happens through one master read, child APIs, backend config, and Control Center modules.

## Master Rule

- Master app read: `GET /users/me/master-state`.
- Master source map: `GET /app/source-of-truth/master`.
- Owner Control Center source map: `GET /control-center/source-of-truth`.
- Child APIs own feature-specific reads/writes and must return or trigger backend canonical state.
- Backend config/catalog/rule endpoints own display and rule configuration.
- Flutter may keep local loading, formatting, and temporary UI state only. Final persisted/profile/economy/store/permission/realtime state must come from backend responses or canonical websocket snapshots.

## Tab Source Map

| Tab | Canonical master | Child APIs/config | Control Center owner | Duplicate sources to retire |
| --- | --- | --- | --- | --- |
| Home | `/users/me/master-state` | `/home-banners`, `/vibes/feed`, `/rooms/trending` | Banner Manager, source registry | Local banner/feed demo data |
| Rooms | `/users/me/master-state` + `/rooms/{room_public_id}/realtime-snapshot` | `/rooms/*`, `/presence/*`, `/ws/room-realtime` | Room settings/permissions modules | Room ranking mock fallbacks, room background fallback lists |
| Vibes | `/users/me/master-state` | `/vibes/feed`, `/vibes/saved`, `/vibes/{post_id}` | Moderation/report tools | Vibes mock/demo data |
| Inbox | `/users/me/master-state` | `/inbox/conversations`, `/inbox/lock/status`, `/inbox/backup/status`, `/ws/inbox` | Inbox lock/reset tools | Local conversation/demo notification fallback data |
| Profile/Me | `/users/me/master-state` + `/profile-display/me` | `/profile-display/users/{id}`, `/users/profile/{id}`, `/store/inventory` | Economy, store, asset, role modules | VIP/profile/frame constants after canonical payload migration |
| Wallet | `/users/me/master-state` | `/wallet/me`, `/economy/me`, `/coin-sales/*` | Economy Control Center | Wallet mock data in legacy sheets |
| VIP Center | `/users/me/master-state` | Economy rule/config endpoint | Economy Control Center | `VipProgramMockRepository` config/reward fallback after public rules endpoint |
| Store | `/users/me/master-state` | `/store/catalog`, `/store/inventory`, store purchase/equip writes | Store Catalog and Asset Control Center | Local store/gift fallback catalog after DB migration |
| Rankings | `/users/me/master-state` | `/rankings/*`, room contribution rankings | Economy Control Center | Mock ranking rows/builders |
| Family | `/users/me/master-state` | `/families/me`, `/families/*`, `/families/economy/*` | Family/economy owner tools later | Family mock data and static requirement constants |
| Love Bonds | `/users/me/master-state` | `/love-bonds/me`, `/love-bonds/inventory`, `/relationships/*` | Economy/relationship tools later | Presentation program defaults |
| Notifications | `/users/me/master-state` | `/notifications/*` | Moderation/admin tools later | `NotificationsMockData` |
| Search | `/users/me/master-state` | Social/room search APIs | Role/privacy controls | Local suggestion fallbacks |
| Games | `/users/me/master-state` | `/games/master`, `/games/*` | Game pools and game props | Game local defaults after backend parity |
| Control Center | `/users/me/master-state` | `/control-center/*`, `/super-owner/*`, `/admin/*` | Founder/Owner/SuperAdmin only | Scattered owner-only config surfaces |

## Live Room Protection

The live room remains protected. Room entry, privacy, settings, kickout, seats, gifts, chat, online count, and realtime websocket behavior must stay on their stable canonical room services:

- `backend/app/services/rooms/room_service.py`
- `backend/app/services/rooms/room_state_service.py`
- `backend/app/services/rooms/room_action_service.py`
- `backend/app/services/rooms/room_kickout_service.py`
- `backend/app/services/permissions/room_permission_service.py`
- `backend/app/api/routes/room_realtime.py`
- `backend/app/api/routes/rooms/rooms.py`

Any future display-payload rewiring inside live room must be a dedicated two-window verification pass.

## Safe Migration Order

1. Keep `/users/me/master-state` as the current-user master read for every tab.
2. Use `/app/source-of-truth/master` as the registry for tab source ownership and migration tracking.
3. Add or expose public config endpoints before removing any local Flutter fallback.
4. Move one visible screen at a time from local mock/fallback data to its canonical child API.
5. Keep UI components and layout unchanged unless a bug requires a focused fix.
6. Run backend compile, `flutter analyze`, and `git diff --check` after each wiring batch.

## Intentionally Deferred

- Removing all Flutter mock/fallback data at once is deferred because several screens still need public config endpoints and safe visual regression checks.
- Live-room canonical profile-display rewiring is deferred to preserve the verified realtime behavior.
- Store/gift asset fallback deletion is deferred until DB catalog parity is verified in Control Center.
- Control Center UI for the source registry is deferred; backend endpoints are available now without changing UI.
