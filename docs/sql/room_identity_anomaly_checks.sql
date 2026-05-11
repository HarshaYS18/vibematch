-- Vibe Match room identity / presence / ownership anomaly checks
-- Run inside psql connected to vibematch_db.

-- 1) Room owners that do not exist as users.
SELECT r.id AS room_db_id, r.room_public_id, r.owner_user_id, r.name
FROM rooms r
LEFT JOIN users u ON u.id = r.owner_user_id
WHERE r.owner_user_id IS NOT NULL AND u.id IS NULL;

-- 2) Rooms with NULL owner_user_id. These cannot have a lifetime channel host.
SELECT id AS room_db_id, room_public_id, owner_user_id, name, created_at
FROM rooms
WHERE owner_user_id IS NULL;

-- 3) Duplicate lifetime rooms for normal/non-owner users.
SELECT r.owner_user_id, u.public_user_id, u.username, u.display_name, COUNT(*) AS room_count,
       STRING_AGG(r.room_public_id, ', ' ORDER BY r.created_at) AS rooms
FROM rooms r
JOIN users u ON u.id = r.owner_user_id
LEFT JOIN user_roles ur ON ur.user_id = u.id
GROUP BY r.owner_user_id, u.public_user_id, u.username, u.display_name
HAVING COUNT(*) > 1
   AND BOOL_OR(ur.role_name IN ('founder_owner', 'owner')) IS NOT TRUE;

-- 4) Participants pointing to missing rooms/users.
SELECT rp.id AS participant_id, rp.room_id, rp.user_id
FROM room_participants rp
LEFT JOIN rooms r ON r.id = rp.room_id
LEFT JOIN users u ON u.id = rp.user_id
WHERE r.id IS NULL OR u.id IS NULL;

-- 5) Active room_participants that belong to inactive/deleted rooms.
SELECT rp.id AS participant_id, r.room_public_id, rp.user_id, rp.is_active
FROM room_participants rp
JOIN rooms r ON r.id = rp.room_id
WHERE rp.is_active IS TRUE AND r.is_active IS NOT TRUE;

-- 6) Room owner rows that are not marked member/admin in room_participants.
SELECT r.room_public_id, r.owner_user_id, u.public_user_id, rp.is_member, rp.is_room_admin
FROM rooms r
JOIN users u ON u.id = r.owner_user_id
LEFT JOIN room_participants rp ON rp.room_id = r.id AND rp.user_id = r.owner_user_id
WHERE r.owner_user_id IS NOT NULL
  AND (rp.id IS NULL OR rp.is_member IS NOT TRUE OR rp.is_room_admin IS NOT TRUE);

-- 7) Stored online_count mismatches active participants.
SELECT r.room_public_id, r.online_count AS stored_online_count, COUNT(rp.id) AS active_participant_count
FROM rooms r
LEFT JOIN room_participants rp ON rp.room_id = r.id AND rp.is_active IS TRUE
GROUP BY r.id, r.room_public_id, r.online_count
HAVING r.online_count <> COUNT(rp.id);

-- 8) Repair owner participant flags.
INSERT INTO room_participants (room_id, user_id, is_active, is_member, is_room_admin, joined_at, last_seen_at, member_added_at, admin_added_at)
SELECT r.id, r.owner_user_id, FALSE, TRUE, TRUE, NOW(), NOW(), NOW(), NOW()
FROM rooms r
WHERE r.owner_user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM room_participants rp WHERE rp.room_id = r.id AND rp.user_id = r.owner_user_id
  );

UPDATE room_participants rp
SET is_member = TRUE,
    is_room_admin = TRUE,
    member_added_at = COALESCE(member_added_at, NOW()),
    admin_added_at = COALESCE(admin_added_at, NOW())
FROM rooms r
WHERE rp.room_id = r.id
  AND rp.user_id = r.owner_user_id;

-- 9) Repair online_count from active participants.
UPDATE rooms r
SET online_count = counts.active_count
FROM (
  SELECT room_id, COUNT(*)::int AS active_count
  FROM room_participants
  WHERE is_active IS TRUE
  GROUP BY room_id
) counts
WHERE r.id = counts.room_id;

UPDATE rooms r
SET online_count = 0
WHERE NOT EXISTS (
  SELECT 1 FROM room_participants rp WHERE rp.room_id = r.id AND rp.is_active IS TRUE
);
