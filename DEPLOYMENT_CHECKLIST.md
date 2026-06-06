# GuardianNode Deployment Checklist

## Security Gate

- [ ] Rotate the Supabase service-role key, Meta access token, Meta app secret, JWT/session secret, and any ngrok credential that was previously committed or shared.
- [ ] Store replacement secrets only in the deployment platform's secret manager.
- [ ] Confirm `.env`, `server/.env`, `key.properties`, keystores, and `node_modules` are not tracked.
- [ ] Remove historical secrets from Git history before making the repository public.

## Backend Environment

- [ ] Copy variable names from `server/.env.production.example`; do not upload that file with real values.
- [ ] Set `NODE_ENV=production`, `DEBUG_AUTH_MODE=false`, and a strong `JWT_SECRET` or `SESSION_SECRET`.
- [ ] Set Supabase, Google Maps server, Meta, WhatsApp, `APP_BASE_URL`, and strict `CORS_ORIGIN` values.
- [ ] Set `WEBHOOK_URL=https://guidiannode-production.up.railway.app/webhook`.
- [ ] Run `npm ci --omit=dev`, `npm run build`, and `npm run check:env:prod`.
- [ ] Confirm `/health` and `/ready` over HTTPS.

## Frontend Environment

- [ ] Create ignored `config/flutter.production.json` from the example.
- [ ] Set `API_BASE_URL=https://guidiannode-production.up.railway.app`.
- [ ] Set `WHATSAPP_TARGET_NUMBER=237657262038`.
- [ ] Set only public client keys; never place service-role or Meta secrets in Flutter defines.
- [ ] Run `flutter analyze`, `flutter test`, and the intended release build.

## Database

- [ ] Back up the production database.
- [ ] Apply `create_otp_sessions.sql` for a new environment.
- [ ] Apply `add_enum_value.sql`, `add_whatsapp_verification_columns.sql`, and `add_whatsapp_verification_index.sql`.
- [ ] Run `reload_schema_cache.sql`.
- [ ] Confirm `otp_sessions` has `pending_user_id`, status/expiry fields, `verified_at`, and `whatsapp_sender_phone`.
- [ ] Confirm `users.phone_verified` and `users.phone_verified_at` exist.

## Meta Webhook

- [ ] Use callback URL `https://guidiannode-production.up.railway.app/webhook`.
- [ ] Enter the exact private `WHATSAPP_VERIFY_TOKEN`.
- [ ] Subscribe the WhatsApp account to `messages`.
- [ ] Confirm GET verification returns the challenge.
- [ ] Confirm valid signed POST events return HTTP 200 and invalid signatures return HTTP 401.

## Manual Tests

Local GET challenge:

```bash
curl "http://localhost:3000/webhook?hub.mode=subscribe&hub.verify_token=guardian_node_whatsapp_verify_2026&hub.challenge=TEST_CHALLENGE"
```

Expected: `TEST_CHALLENGE`

Production GET challenge:

```bash
curl "https://guidiannode-production.up.railway.app/webhook?hub.mode=subscribe&hub.verify_token=PRODUCTION_VERIFY_TOKEN&hub.challenge=TEST_CHALLENGE"
```

Expected: `TEST_CHALLENGE`

- [ ] Enter a phone number during registration.
- [ ] Confirm the backend returns a `CM-XXXXX` token and `wa.me/237657262038` URL.
- [ ] Tap **Verify via WhatsApp** and send the prepared token from the submitted phone number.
- [ ] Confirm Meta reaches `POST /webhook`.
- [ ] Confirm the session changes from `pending` to `verified`.
- [ ] Confirm Flutter detects verification within the three-second polling interval and opens the existing authenticated flow.
- [ ] Confirm a wrong sender, reused token, expired token, malformed event, and invalid signature do not activate an account.

## Play Release

- [ ] Generate and securely back up the Android upload keystore.
- [ ] Create ignored `android/key.properties`.
- [ ] Build and smoke-test `app-release.aab`.
- [ ] Complete Play App Signing, privacy policy, Data safety, app access, content rating, target audience, and location permission declarations.

## Rollback

- [ ] Keep the previous backend image/release available.
- [ ] Do not drop old OTP columns during rollback.
- [ ] Repoint Meta only after the replacement `/webhook` passes challenge and signed-event tests.
- [ ] If verification fails, restore the previous backend release and webhook URL, then inspect masked server logs and pending sessions.
- [ ] Revoke any credential suspected of exposure before retrying deployment.
