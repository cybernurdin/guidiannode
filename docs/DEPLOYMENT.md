# GuardianNode Deployment

This checklist prepares the Flutter clients and Node API for a real deployment without committing secret values.

## Backend API

Required environment variables:

```env
NODE_ENV=production
PORT=3000
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
GOOGLE_MAPS_SERVER_API_KEY=your_google_server_key
JWT_SECRET=replace_with_a_long_random_secret
CORS_ORIGIN=https://your-web-app.example.com
SMS_PROVIDER=twilio
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_FROM_NUMBER=+15551234567
DEBUG_AUTH_MODE=false
AUTO_VERIFY_DEBUG_OTP=false
OTP_EXPIRES_MINUTES=10
```

Useful commands from `server/`:

```bash
npm install
npm run check:env:prod
npm run start:prod
```

Health endpoints:

```text
GET /health
GET /ready
```

Notes:

- `DEBUG_AUTH_MODE=true` is blocked in production.
- `SMS_PROVIDER=twilio` is required in production so OTP delivery works.
- `CORS_ORIGIN` accepts a comma-separated list when multiple clients need API access.
- Keep `server/.env` local. It is ignored going forward; remove it from source control before publishing this repository.

## Flutter Runtime Defines

Use explicit deployment values for every release build:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.your-domain.example \
  --dart-define=GOOGLE_MAPS_API_KEY=your_web_google_maps_key \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_publishable_or_anon_key \
  --dart-define=SHOW_DEBUG_OTP_HELPER=false
```

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.your-domain.example \
  --dart-define=GOOGLE_MAPS_API_KEY=your_android_google_maps_key \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_publishable_or_anon_key \
  --dart-define=SHOW_DEBUG_OTP_HELPER=false
```

For iOS, put the iOS Google Maps key in `ios/Flutter/Secrets.xcconfig` or provide it through CI/Xcode build settings:

```xcconfig
GOOGLE_MAPS_API_KEY=your_ios_google_maps_api_key
```

## Android Release Signing

Create `android/key.properties` using `android/key.properties.example` as the shape. The file is ignored so passwords and keystores stay local.

```properties
storeFile=../upload-keystore.jks
storePassword=replace_with_store_password
keyAlias=upload
keyPassword=replace_with_key_password
```

The Android application id is `com.guardiannode.app`. Release builds no longer use the debug signing config.

## Supabase Schema

Apply the SQL files in `server/sql/` before first deployment, especially:

```text
create_otp_sessions.sql
create_live_locations.sql
add_enum_value.sql
reload_schema_cache.sql
```

Then verify `/ready` and run through registration, OTP, SOS creation, live location, nearby alerts, responder follow, and SOS resolution.
