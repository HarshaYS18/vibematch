# VibeMatch Flutter Dev Backend URLs

The app defaults to the local backend for Flutter Web / Edge testing:

```text
http://127.0.0.1:8000
```

Start backend:

```powershell
cd "D:\Vibe Match\vibematch\backend"
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Run Flutter Web / Edge:

```powershell
cd "D:\Vibe Match\vibematch\frontend\vibematch_app"
flutter run -d edge
```

Run Android emulator:

```powershell
flutter run -d android --dart-define=VM_API_BASE_URL=http://10.0.2.2:8000
```

Run physical Android phone on same Wi-Fi:

```powershell
flutter run -d android --dart-define=VM_API_BASE_URL=http://YOUR_LAN_IP:8000
```

Example:

```powershell
flutter run -d android --dart-define=VM_API_BASE_URL=http://192.168.29.240:8000
```

Quick backend checks:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
Invoke-RestMethod http://127.0.0.1:8000/rooms/trending
```

Important:

- Do not hardcode temporary LAN IPs in feature services.
- Use `AppConstants.apiBaseUrl`, `AppConstants.webApiBaseUrl`, `VmApiConfig.baseUrl`, or `VmApiConfig.endpoint(...)`.
- For future network code, prefer the existing `ApiClient` or `VmApiConfig.endpoint(...)` instead of building raw URLs inside feature widgets.
