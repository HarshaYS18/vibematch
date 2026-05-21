# API tokens and production secrets checklist

Use this before uploading FunKey / VibeMatch to a VPS.

## Golden rule

Do not commit real secrets to GitHub.

Real values belong only in:

- `backend/.env` on the server
- server secret manager
- Docker secrets
- private CI/CD variables
- `backend/secrets/` on the server for service account JSON files

The repository may contain examples with `CHANGE_ME_...` placeholders only.

## Required before production

### 1. JWT secret

Required.

Environment variables:

```env
JWT_SECRET_KEY=<64+ random characters>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
ENABLE_DEV_LOGIN=false
```

Generate a strong secret:

```bash
python - <<'PY'
import secrets
print(secrets.token_urlsafe(64))
PY
```

Never use the default `change-this-secret-key-in-production` value.

### 2. PostgreSQL

Required.

```env
database_url=postgresql://vibematch_user:<strong-password>@127.0.0.1:5432/vibematch
```

Use a dedicated DB user. Do not use `postgres:postgres` in production.

### 3. Redis

Required for realtime/cache flows.

```env
redis_url=redis://:<strong-redis-password>@127.0.0.1:6379/0
```

Keep Redis private to localhost/VPC. Do not expose Redis publicly.

### 4. Google login

Required if Google sign-in is enabled.

```env
GOOGLE_AUTH_CLIENT_IDS=<android-client-id>,<web-client-id>,<ios-client-id>
```

Add every valid OAuth client ID. Production should not accept an empty audience list.

### 5. Firebase Cloud Messaging

Required for push notifications, incoming call notifications, message notifications and call overlays.

```env
FCM_PROJECT_ID=funkey-69
FIREBASE_SERVICE_ACCOUNT_PATH=/opt/funkey/backend/secrets/firebase-service-account.json
```

Server setup:

1. Download Firebase service account JSON from Firebase/Google Cloud.
2. Upload it manually to the server.
3. Put it under a protected path such as `/opt/funkey/backend/secrets/firebase-service-account.json`.
4. Ensure it is readable only by the backend process user.
5. Never commit it.

Frontend Firebase config such as `firebase_options.dart` is client configuration, not a backend secret. Restrict the Firebase API key in Google Cloud using Android package name and SHA-1/SHA-256.

### 6. Oracle Object Storage / CDN media

Required for production profile pictures, cover photos, chat media, vibes media and CDN-style assets.

```env
MEDIA_STORAGE_DRIVER=s3
MEDIA_CDN_BASE_URL=https://cdn.yourdomain.com/media
MEDIA_S3_BUCKET=<bucket-name>
MEDIA_S3_REGION=<region>
MEDIA_S3_ENDPOINT_URL=https://<namespace>.compat.objectstorage.<region>.oraclecloud.com
MEDIA_S3_ACCESS_KEY_ID=<oracle-customer-secret-key-id>
MEDIA_S3_SECRET_ACCESS_KEY=<oracle-customer-secret>
MEDIA_S3_PUBLIC_READ=true
```

If `MEDIA_STORAGE_DRIVER=local`, uploads are local VPS files only. That is okay for dev, not for production.

### 7. Gift CDN

Required when dynamic gift assets are hosted remotely.

```env
GIFT_CDN_BASE_URL=https://cdn.yourdomain.com/gifts
```

Leave empty only for closed beta if the app uses bundled fallback assets.

### 8. Google Drive backup

Required only if Inbox Google Drive backup/restore is enabled.

```env
GOOGLE_DRIVE_CLIENT_ID=<client-id>
GOOGLE_DRIVE_CLIENT_SECRET=<client-secret>
GOOGLE_DRIVE_REDIRECT_URI=https://api.yourdomain.com/inbox/backup/google/callback
GOOGLE_DRIVE_SCOPES=https://www.googleapis.com/auth/drive.file
INBOX_BACKUP_ENCRYPTION_KEY=<32-byte-or-longer-random-secret>
```

Do not use localhost redirect URI in production.

Generate encryption key:

```bash
python - <<'PY'
import secrets
print(secrets.token_urlsafe(48))
PY
```

### 9. OpenAI moderation

Required only if OpenAI image/text moderation is enabled.

```env
OPENAI_API_KEY=<openai-key>
```

or:

```env
FUNKEY_OPENAI_API_KEY=<openai-key>
```

If moderation is enabled but no key exists, moderation will fail or fallback depending on configured rules.

## Files that must stay private

These are ignored by `.gitignore`; do not force-add them:

- `.env`
- `.env.*`
- `backend/secrets/`
- `*.pem`
- `*.key`
- `*.p12`
- `*.jks`
- `*.keystore`
- `google-services.json`
- `GoogleService-Info.plist`
- Firebase service account JSON files

## Before deploy command checklist

1. Copy `backend/.env.example` to `backend/.env` on the server.
2. Replace every `CHANGE_ME_...` value.
3. Set `ENABLE_DEV_LOGIN=false`.
4. Confirm `MEDIA_STORAGE_DRIVER=s3` if production CDN uploads are required.
5. Upload Firebase service-account JSON outside Git.
6. Run backend with the server `.env`.
7. Test:
   - Google login
   - push notification
   - avatar upload
   - cover upload
   - inbox message notification
   - incoming call notification
   - lucky gift send
   - gift CDN asset load

## Quick sanity check

Run on the server before starting backend:

```bash
grep -n "CHANGE_ME\|localhost\|127.0.0.1:8000\|change-this" backend/.env
```

Only database/Redis localhost is acceptable if they run on the same server. No placeholder secrets should remain.
