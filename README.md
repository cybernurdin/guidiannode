# GuardianNode

GuardianNode is a Flutter and Node.js emergency-response app for Cameroon. It provides inbound WhatsApp authentication, SOS alerts, realtime location sharing, nearby incidents, responder guidance, and Supabase-backed updates.

## Local Development

Start the backend:

```powershell
Set-Location server
npm ci
npm start
```

Run Flutter against it:

```powershell
flutter pub get
flutter run
```

Android emulators use `http://10.0.2.2:3000` by default. For a physical Android device:

```powershell
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000
```

Core endpoints:

```text
POST /api/auth/register/start-verification
POST /api/auth/login/start-verification
GET  /api/verification/status/:verificationId
GET  /webhook
POST /webhook
GET  /health
GET  /privacy-policy
GET  /data-deletion
```

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) and [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) before releasing.
