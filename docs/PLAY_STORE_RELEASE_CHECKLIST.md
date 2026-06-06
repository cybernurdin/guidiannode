# GuardianNode Play Store Release Checklist

## Backend

- Deploy the Node API to a public HTTPS host.
- Set `NODE_ENV=production`.
- Set `DEBUG_AUTH_MODE=false`.
- Configure the production Meta webhook at `https://guidiannode-production.up.railway.app/webhook`.
- Set the WhatsApp Cloud API IDs, verify token, target number, and Meta app secret.
- Confirm signed Meta webhook POST requests are accepted and invalid signatures return HTTP 401.
- Use a strong production `JWT_SECRET`.
- Set HTTPS `CORS_ORIGIN` or `CLIENT_ORIGIN`.
- Verify `/health` and `/ready` return successful JSON from the production API.

## Flutter Android Build

- Create an Android upload keystore and `android/key.properties`.
- Build the Play bundle with a production HTTPS API URL:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://guidiannode-production.up.railway.app
```

- Confirm the generated file exists at:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Google Play Console

- Create the app record with package name `com.guardiannode.app`.
- Enroll in Play App Signing.
- Upload the release `.aab`.
- Complete App Content sections:
  - Privacy policy URL
  - Data safety
  - App access
  - Content rating
  - Target audience
  - Ads declaration
  - Permissions declarations for location, if requested by Play Console
- Add store listing text, screenshots, app icon, feature graphic, and contact email.

## Data Safety Notes

GuardianNode currently processes:

- Phone number for WhatsApp verification and account identity
- Full name and neighborhood
- Emergency contact name, relationship, and phone number
- Approximate/precise location for SOS, nearby alerts, maps, and responder routing
- Emergency alert details and status

Use these facts when completing the Google Play Data safety form and privacy policy.
