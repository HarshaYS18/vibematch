# Chunks 11-12: Product migration onto canonical domains

Chunks 11-12 do not create a new application state layer. Hago-style social behavior is mapped onto domains already established in Chunks 0-10.

- Quick matchmaking -> Home/room discovery -> `GET /rooms/quick-match`.
- Room activities / party modes -> Room Session -> canonical `activity` in the room snapshot.
- Karaoke -> room activity kind `karaoke`.
- Social games -> room activity kind `social_game` plus the Chunk-10 remote game platform.
- Game/activity invites -> target-scoped room realtime activity invite on the existing room realtime channel.
- Post-game loops -> `post_game` payload on room activity state.
- Missions/social rewards -> Experience + existing wallet ledger; daily idempotent `SOCIAL_MISSION_REWARD` credits.
- Events -> Experience/community events consumed by the existing Events screen.
- Families/community -> existing Family domain plus existing Inbox storage for family chat.
- Leaderboards -> existing Rankings and Family Rankings remain authoritative.
- Room discovery -> trending/following plus quick match.

Room activity START is owner/admin controlled. UPDATE/END requires the controller or room admin. Controller departure transfers deterministically to another active participant or ends the activity.

No feature-specific process-global manager is introduced. Room activities flow through RoomSessionRepository. Social rewards flow through Experience/Economy. Family chat reuses Inbox. Remote social games remain behind GameRuntime.
