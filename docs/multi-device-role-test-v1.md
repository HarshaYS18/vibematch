# Multi Device Role Test v1

Branch: `multi-device-role-test-v1`

Use this branch when you want to test VibeMatch on three devices/accounts:

- Device 1: Founder Owner
- Device 2: normal user A
- Device 3: normal user B

Then Founder can promote User A or User B to an official/testing role and revoke that role again.

## New internal APIs

```txt
GET  /internal-test/multi-device/accounts
GET  /internal-test/multi-device/login/{label}
POST /internal-test/multi-device/promote
POST /internal-test/multi-device/revoke-role
POST /internal-test/multi-device/reset-user-roles/{public_user_id}
```

Labels:

```txt
founder
user_a
user_b
```

Promotable roles:

```txt
owner
superadmin
admin
monitor
cs
agency_owner
bd
coin_seller
merchant
reseller
```

The API blocks assigning or revoking `founder_owner`.

## Easy test flow

### 1. Start backend

```powershell
cd "D:\Vibe Match\vibematch"
git fetch
git checkout multi-device-role-test-v1
docker compose up -d
cd backend
.\.venv\Scripts\activate
uvicorn app.main:app --reload
```

Open:

```txt
http://127.0.0.1:8000/docs
```

### 2. Get all three test accounts

In Swagger, run:

```txt
GET /internal-test/multi-device/accounts
```

It returns login tokens for:

- founder
- user_a
- user_b

Each response includes:

```txt
access_token
public_user_id
roles
primary_role
```

### 3. Use devices

Device 1 should use founder account.

Device 2 should use user_a.

Device 3 should use user_b.

For now, if the Flutter app UI does not yet have account switcher buttons, use the normal dev-login body manually:

Founder:

```json
{
  "email": "founder@vibematch.com",
  "username": "founder",
  "display_name": "Founder Owner",
  "device_id": "internal-founder-device"
}
```

User A:

```json
{
  "email": "internal.user.a@vibematch.test",
  "username": "internal_user_a",
  "display_name": "Internal User A",
  "device_id": "internal-user-a-device"
}
```

User B:

```json
{
  "email": "internal.user.b@vibematch.test",
  "username": "internal_user_b",
  "display_name": "Internal User B",
  "device_id": "internal-user-b-device"
}
```

### 4. Promote a user from Founder

First authorize Swagger with Founder token:

```txt
Bearer FOUNDER_ACCESS_TOKEN
```

Then run:

```txt
POST /internal-test/multi-device/promote
```

Example body:

```json
{
  "public_user_id": 6418000001,
  "role": "admin",
  "reason": "Testing admin role on second device"
}
```

Use the real `public_user_id` returned for User A or User B.

### 5. Check role changed

On User A device, call:

```txt
GET /users/me
```

The response should include the promoted role after logging in again or refreshing token/session.

### 6. Revoke role from Founder

Authorize Swagger with Founder token and run:

```txt
POST /internal-test/multi-device/revoke-role
```

Example body:

```json
{
  "public_user_id": 6418000001,
  "role": "admin",
  "reason": "Finished admin role test"
}
```

### 7. Reset a test user back to normal user

```txt
POST /internal-test/multi-device/reset-user-roles/{public_user_id}
```

This removes all roles from that user and adds normal `user` role again.

## Notes

- Founder Owner cannot be modified.
- Founder Owner role cannot be assigned through this internal API.
- These endpoints are for local/internal testing only.
- Keep them out of production builds later or protect them behind environment flags.
