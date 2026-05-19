# Inbox Source of Truth Audit

Branch: `economy-control-center-source-of-truth-v1`
Base commit requested: `6d3d6907 Wire family and love bond store sources`

## Current inbox files found

Frontend entry point:
- `frontend/vibematch_app/lib/features/inbox/presentation/inbox_page.dart`
  - Public export wrapper for the modular Inbox page.
- `frontend/vibematch_app/lib/features/inbox/presentation/inbox_page_modular.dart`
  - Main Inbox screen/controller integration.
- `frontend/vibematch_app/lib/features/inbox/presentation/pages/inbox_chat_page.dart`
  - Direct chat UI, input bar, attachments, reactions, local call foundation placeholder.
- `frontend/vibematch_app/lib/features/inbox/presentation/pages/inbox_calling_page.dart`
  - Reusable call foundation UI for incoming overlay, active call, and call summary screens.
- `frontend/vibematch_app/lib/features/inbox/presentation/widgets/inbox_conversation_card.dart`
  - Conversation row/card UI.
- `frontend/vibematch_app/lib/features/inbox/models/inbox_models.dart`
  - Existing Inbox conversation/message/report/lock/backup models.
- `frontend/vibematch_app/lib/features/inbox/controllers/inbox_controller.dart`
  - Existing Inbox state, backend loading, local optimistic message state, lock/block/mute/pin/report actions.
- `frontend/vibematch_app/lib/features/inbox/data/inbox_api_service.dart`
  - Existing Inbox REST API adapter.

Backend files found/reused:
- `backend/app/models/inbox.py`
  - Existing DB tables for conversations, participants, messages, reports, lock settings, lock OTP.
- `backend/app/schemas/inbox.py`
  - Existing DTOs for Inbox APIs.
- `backend/app/services/inbox_service.py`
  - Existing Inbox business logic and payload mapping.
- `backend/app/api/routes/inbox.py`
  - Existing thin routes for lock, conversations, messages, state, reports, room invites.
- `backend/app/websocket/inbox_ws.py`
  - Existing Inbox realtime manager.
- `backend/app/api/routes/media_realtime_auth.py`
  - FastAPI media realtime verification endpoint for mediasoup/signaling servers.
- `backend/app/schemas/media_realtime_auth.py`
  - DTOs for media realtime verification.
- `backend/app/services/media_realtime_auth_service.py`
  - Business logic for JWT-backed media realtime access checks.

## Duplicate sources found

No separate duplicate user/profile/badge/room models were added inside Inbox during this pass.

Existing Inbox already had feature-local `InboxConversation` and `InboxMessage` models. They remain as Inbox DTO/view models because the current frontend and backend are already wired around them. New cross-feature call/presence/notification concepts were not duplicated in Inbox; they were added to shared sources.

No actual mediasoup Node/signaling server implementation was found in this repository branch, so produce/consume/createTransport handlers were not patched directly here. Instead, a backend source-of-truth verification endpoint and Flutter client wrapper were added for the external mediasoup signaling service to use before any media action.

## Canonical source chosen

Canonical shared communication contracts:
- `frontend/vibematch_app/lib/shared/communication/vm_communication_models.dart`
- `frontend/vibematch_app/lib/shared/communication/vm_notification_payload_factory.dart`
- `frontend/vibematch_app/lib/shared/communication/vm_media_realtime_auth_service.dart`

These files are the shared source of truth for:
- call type/status/session references
- call participant references
- notification payload type/contracts
- quick reply payload contracts
- room presence visibility/safe display rules
- safe notification/quick-reply payload construction for message, room invite, team/system, stranger request, and call events
- Flutter-side media realtime verification client for joining/progressing mediasoup actions

Canonical media realtime auth source:
- `backend/app/api/routes/media_realtime_auth.py`
- `backend/app/schemas/media_realtime_auth.py`
- `backend/app/services/media_realtime_auth_service.py`

This source is for mediasoup/signaling JWT verification before actions like:
- `join_room`
- `create_transport`
- `connect_transport`
- `produce_audio`
- `consume_audio`
- `pause_producer`
- `resume_producer`
- `close_producer`
- `join_seat`
- `leave_seat`
- `leave_room`

Existing shared visual source reused:
- `frontend/vibematch_app/lib/shared/gradient_names/gradient_name_text.dart`
- `frontend/vibematch_app/lib/shared/gradient_names/gradient_name_style.dart`

Existing backend source reused:
- `backend/app/models/inbox.py`
- `backend/app/services/inbox_service.py`
- `backend/app/api/routes/inbox.py`

## Flutter models/widgets added or reused

Added:
- `frontend/vibematch_app/lib/shared/communication/vm_communication_models.dart`
- `frontend/vibematch_app/lib/shared/communication/vm_notification_payload_factory.dart`
- `frontend/vibematch_app/lib/shared/communication/vm_media_realtime_auth_service.dart`
- `frontend/vibematch_app/lib/features/inbox/presentation/widgets/swipe_reply_message.dart`
- `frontend/vibematch_app/lib/features/inbox/presentation/pages/stranger_requests_page.dart`
- `frontend/vibematch_app/lib/features/inbox/presentation/pages/inbox_calling_page.dart`

Updated:
- `frontend/vibematch_app/lib/features/inbox/models/inbox_models.dart`
  - Added shared `VmRoomPresenceSnapshot` composition.
  - Added grouped stranger hub metadata fields.
  - Added future-ready group/story/call conversation/message enum values.
- `frontend/vibematch_app/lib/features/inbox/presentation/inbox_page_modular.dart`
  - Rebuilt UI into premium Instagram/WhatsApp-style Inbox shell.
  - Added dark gradient hero, quick metrics, mini story rail, compact filter chips, grouped stranger hub behavior, and premium card list.
- `frontend/vibematch_app/lib/features/inbox/presentation/widgets/inbox_conversation_card.dart`
  - Redesigned rows into compact premium rounded cards with gradient avatar rings, badge/status pills, locked preview handling, unread badges, and safe presence text.
- `frontend/vibematch_app/lib/features/inbox/presentation/pages/inbox_chat_page.dart`
  - Rebuilt chat UI with premium dark header, gradient sent bubbles, glass/white received bubbles, shared moving swipe-reply wrapper, reply preview, reactions/action sheet, room invite cards, relationship request cards, system cards, and call foundation placeholder.

Reused:
- Existing `InboxController` for backend load/state/messaging/report/lock actions.
- Existing `InboxApiService` for live backend data.
- Existing `LockedChatsPage`, `InboxSettingsPage`, `InboxSearchPage`, `CsReportTasksPage`, and lock/report sheets.
- Existing app route `VmRoutes.liveRoom` for room invite join cards.

## Backend routes/tables added or reused

Reused existing backend:
- `GET /inbox/conversations`
- `POST /inbox/conversations/direct`
- `PATCH /inbox/conversations/{conversation_id}/state`
- `POST /inbox/conversations/{conversation_id}/messages`
- `PATCH /inbox/conversations/{conversation_id}/messages/{message_id}`
- `DELETE /inbox/conversations/{conversation_id}/messages/{message_id}`
- `POST /inbox/conversations/{conversation_id}/reports`
- Inbox lock and backup routes already present.

Added backend foundation:
- `POST /media-realtime/verify`

`POST /media-realtime/verify` uses normal Bearer JWT auth through `get_current_user`, returns backend-trusted user identity/roles, checks active user, banned user, active device ban, required room id for room actions, room existence, and room active status. The external mediasoup signaling service must ignore any client-sent user id, role, or permission claims.

No backend DB migration was added in this pass.

## What is fully wired now

- Main Inbox page opens through the existing exported `InboxPage` entry point.
- Existing backend conversations still load through `InboxController` and `InboxApiService`.
- Normal chats, room invite conversations, official team conversation, and stranger conversations still come from backend.
- Stranger messages are visually grouped under one `Stranger Messages` hub in the redesigned Inbox shell.
- Opening the stranger hub opens `StrangerRequestsPage` with individual stranger request conversations.
- Per-chat lock/block/mute/pin/report actions still map to existing controller/backend methods.
- Locked individual chats hide preview text in the conversation card.
- Chat screen sends text through existing controller/API logic.
- Attachments remain mapped to existing local mock/file-picker behavior.
- Room invite cards still navigate to the live room route using existing route args.
- Swipe-to-reply now physically moves the message body during drag and snaps back after release.
- Reply preview activates after swipe threshold or action sheet reply.
- Call buttons show safe call foundation placeholder UI rather than claiming native call support.
- Reusable call UI screens exist for incoming overlay, active calling, and call summary.
- Shared notification payload factory exists for message, room invite, system/team, stranger request, call, and quick-reply payload contracts.
- FastAPI now exposes a JWT-protected media realtime verification endpoint for external mediasoup/signaling integration.
- Flutter has a shared media realtime verification client that can be used by future live-room/call signaling code before mediasoup actions.

## What remains mocked/deferred

- Native closed-app incoming call overlay.
- Real call session backend/media wiring for direct calls, 1v1 video, and group calls.
- Actual Node/mediasoup signaling server handler patching; no mediasoup server source was found in this branch.
- Push notifications and quick reply action execution.
- Full message notification contracts on backend.
- Cloud chat wallpapers and custom wallpaper picker.
- Backend-enforced stranger request accept/reject workflow beyond existing conversation state/report/block behavior.
- Backend safe presence flags for Secret Vibe/stealth presence need a canonical backend payload when room presence source is finalized.
- Full group chat backend and group topic tabs.
- Story privacy backend and story reply feeds.
- Message recall API; current delete action remains existing delete-for-user/server delete behavior.

## Manual test checklist

1. Launch app and log in.
2. Open Inbox from app shell.
3. Confirm premium gradient Inbox hero appears.
4. Confirm mini story rail renders without overflow.
5. Confirm filter chips scroll horizontally and select correctly.
6. Confirm normal friend chats appear as cards.
7. Confirm official Team conversation appears as official card.
8. Confirm room invite conversations show invite pill/card behavior.
9. Confirm stranger conversations do not mix as individual rows in All; they appear under `Stranger Messages` hub.
10. Tap `Stranger Messages`; confirm grouped requests page opens.
11. Long press normal chat; confirm Lock/Unlock, Block/Unblock, Mute/Unmute, Pin/Unpin, Report options appear.
12. Lock one chat; confirm preview changes to locked text and opening requires lock if lock is enabled.
13. Open a normal chat.
14. Send a text message.
15. Long press a message; test reply, reaction, star, forward, delete.
16. Swipe a message horizontally; confirm the actual bubble/body moves with the finger and snaps back.
17. Swipe beyond threshold; confirm reply preview appears.
18. Tap room invite card; confirm live room route opens.
19. Tap voice/video call icons; confirm placeholder call foundation sheet opens.
20. Confirm no Secret Vibe room name is displayed unless backend provides it as safe public room presence.
21. Open/import `InboxIncomingCallOverlay`, `InboxCallingPage`, and `InboxCallSummaryPage` in a temporary test harness before wiring real call routes.
22. Verify `POST /media-realtime/verify` with a valid Bearer token and room id.
23. Verify `POST /media-realtime/verify` rejects missing/invalid/expired Bearer token through existing `get_current_user` auth.
24. Verify unsupported `requested_action` returns `allowed=false`.
25. Verify banned device id returns `allowed=false`.
26. Verify room-required actions without `room_public_id` return `allowed=false`.

## Verification notes

Requested verification commands:
- `flutter analyze`
- `flutter test test/widget_test.dart`
- `python -m compileall app` because backend files changed in the media realtime auth chunk
- `git diff --check`

The GitHub connector used here can edit repository files but cannot run Flutter/terminal verification inside the private repository workspace. Run the above commands locally before merging or continuing backend/native notification work.
