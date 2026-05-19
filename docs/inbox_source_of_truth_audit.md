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

## Duplicate sources found

No separate duplicate user/profile/badge/room models were added inside Inbox during this pass.

Existing Inbox already had feature-local `InboxConversation` and `InboxMessage` models. They remain as Inbox DTO/view models because the current frontend and backend are already wired around them. New cross-feature call/presence/notification concepts were not duplicated in Inbox; they were added to a shared source.

## Canonical source chosen

Canonical shared communication contracts:
- `frontend/vibematch_app/lib/shared/communication/vm_communication_models.dart`

This file is the shared source of truth for:
- call type/status/session references
- call participant references
- notification payload type/contracts
- quick reply payload contracts
- room presence visibility/safe display rules

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
- `frontend/vibematch_app/lib/features/inbox/presentation/widgets/swipe_reply_message.dart`
- `frontend/vibematch_app/lib/features/inbox/presentation/pages/stranger_requests_page.dart`

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

Reused existing backend only in this pass:
- `GET /inbox/conversations`
- `POST /inbox/conversations/direct`
- `PATCH /inbox/conversations/{conversation_id}/state`
- `POST /inbox/conversations/{conversation_id}/messages`
- `PATCH /inbox/conversations/{conversation_id}/messages/{message_id}`
- `DELETE /inbox/conversations/{conversation_id}/messages/{message_id}`
- `POST /inbox/conversations/{conversation_id}/reports`
- Inbox lock and backup routes already present.

No backend DB migration was added in this pass. The existing backend already contains Inbox tables/routes/services and this task focused on safe UI/source-of-truth foundation.

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

## What remains mocked/deferred

- Native closed-app incoming call overlay.
- Real call session backend/media wiring for direct calls, 1v1 video, and group calls.
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

## Verification notes

Requested verification commands:
- `flutter analyze`
- `flutter test test/widget_test.dart`
- `python -m compileall app` if backend changed
- `git diff --check`

Backend Python files were not modified in this pass, so backend compile was not required by the changed file set.

The GitHub connector used here can edit repository files but cannot run Flutter/terminal verification inside the private repository workspace. Run the above commands locally before merging or continuing backend/native notification work.
