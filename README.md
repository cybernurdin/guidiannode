# GuardianNode

GuardianNode is a Flutter and Node.js emergency alert app for Bamenda, with OTP authentication, realtime location sharing, nearby SOS alerts, responder route guidance, and Supabase-backed live updates.

## Local auth backend

The Node backend lives in `server/` and serves auth endpoints at `http://localhost:3000/api/auth`.

Start it with:

```bash
cd server
npm start
```

Health check:

```bash
http://127.0.0.1:3000/health
```

Readiness check:

```bash
cd server
npm run check:env
```

## Running the Flutter app against local auth

Android emulator can use the built-in default:

```bash
flutter run
```

That default is `http://10.0.2.2:3000/api/auth`, which only works inside the Android emulator.

For a physical Android phone, use one of these:

```bash
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_AUTH_BASE_URL=http://127.0.0.1:3000/api/auth
```

```bash
flutter run --dart-define=API_AUTH_BASE_URL=http://<your-computer-ip>:3000/api/auth
```

## Deployment

Deployment steps, environment variables, signing notes, and production build commands are in [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).
