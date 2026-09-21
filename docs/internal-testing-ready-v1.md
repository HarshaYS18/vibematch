# Internal Testing Ready v1

Branch: `internal-testing-ready-v1`

This branch is for beginner-friendly internal testing. It is not for public release.

## What changed

Added internal seed/reset APIs:

```txt
GET    /internal-test/status
POST   /internal-test/seed
DELETE /internal-test/reset-my-samples
```

These routes create sample backend records for the major pages/modules so testers can see real database-backed records without manually creating every item.

## Beginner test checklist

### 1. Checkout branch

```powershell
cd "D:\Vibe Match\vibematch"
git fetch
git checkout internal-testing-ready-v1
```

### 2. Start database

```powershell
docker compose up -d
```

### 3. Start backend

```powershell
cd backend
.\.venv\Scripts\activate
uvicorn app.main:app --reload
```

If `.venv` does not exist yet:

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open:

```txt
http://127.0.0.1:8000/docs
```

### 4. Login

In Swagger docs, open:

```txt
POST /auth/dev-login
```

Use:

```json
{
  "email": "founder@vibematch.com",
  "username": "founder",
  "display_name": "Founder Owner",
  "device_id": "internal-test-device"
}
```

Copy the `access_token`.

Click the Swagger `Authorize` button and paste:

```txt
Bearer YOUR_ACCESS_TOKEN
```

### 5. Check internal test status

Run in Swagger:

```txt
GET /internal-test/status
```

Expected:

```json
{
  "ok": true,
  "mode": "internal_testing"
}
```

### 6. Seed sample data

Run in Swagger:

```txt
POST /internal-test/seed
```

Expected:

```json
{
  "ok": true,
  "created_count": 17
}
```

### 7. Check sample records

Run these in Swagger:

```txt
GET /mvp/vibes
GET /mvp/wallet
GET /mvp/gifts
GET /mvp/store
GET /mvp/vip
GET /mvp/family
GET /mvp/events
GET /mvp/assets
GET /mvp/reports
```

You should see seeded records.

### 8. Start Flutter app

Open a new PowerShell window:

```powershell
cd "D:\Vibe Match\vibematch\frontend\vibematch_app"
flutter pub get
flutter run -d chrome
```

Use Chrome first. Android emulator can be tested after Chrome works.

### 9. Media and deployment

This historical checklist is superseded by [PRODUCTION_RUNBOOK.md](../PRODUCTION_RUNBOOK.md). Use backend_media and authenticated API discovery for room and call media.

## Internal testing pass criteria

This branch is internally testable when:

- `/health` works
- `/auth/dev-login` works
- `/users/me` works
- `/internal-test/status` works
- `/internal-test/seed` creates records
- `/mvp/features` returns feature list
- `/mvp/vibes`, `/mvp/wallet`, `/mvp/gifts`, `/mvp/family` return records
- Flutter opens in Chrome
- WebRTC standalone test page can join a local room

## Known limitation

Many Flutter pages still need direct API wiring. This branch provides backend readiness and sample data, but frontend screens may still show local mock data until each page is wired to these endpoints.
