# GuardianNode — Vercel Flutter Web Setup

These files make Vercel deploy the Flutter web client as static files while the
Node.js API remains on Railway.

## Copy into the repository

Copy these files to the same paths in the GuardianNode repository:

- `vercel.json`
- `.vercelignore`
- `scripts/vercel_build.sh`
- `lib/core/config/app_config.dart`

Commit and push them.

## Vercel project settings

Open **Vercel → GuardianNode project → Settings → Build and Deployment**.

Set:

- **Framework Preset:** Other
- **Root Directory:** `.` (repository root)
- **Build Command:** leave controlled by `vercel.json`
- **Output Directory:** leave controlled by `vercel.json`
- **Install Command:** leave controlled by `vercel.json`
- **Node.js Version:** 20.x or newer

Do not set the root directory to `server`. The backend is already hosted on Railway.

## Vercel environment variables

Add these under **Settings → Environment Variables** for Production and Preview:

- `API_BASE_URL=https://guidiannode-api-production.up.railway.app`
- `FLUTTER_VERSION=3.41.4`
- `GOOGLE_MAPS_API_KEY=<browser-restricted Google Maps key>`
- `SUPABASE_URL=<your Supabase project URL>`
- `SUPABASE_ANON_KEY=<your public anon/publishable key>`
- `WHATSAPP_TARGET_NUMBER=<country-code number without +>`
- `SHOW_DEBUG_OTP_HELPER=false`

Never put a Supabase service-role key, Railway secret, private signing key, or
server-only credential in Vercel's Flutter build variables because Flutter web
values are embedded in the browser bundle.

## Railway CORS

The Railway backend must allow the Vercel origins, for example:

- the final production `https://<project>.vercel.app` domain
- your custom domain, if used
- Vercel preview domains during testing, or a carefully controlled preview rule

The exact variable name depends on the backend implementation. Inspect its CORS
configuration before adding a value such as `ALLOWED_ORIGINS` or `CORS_ORIGIN`.

## Redeploy

After pushing:

1. Open Vercel → Deployments.
2. Select the latest deployment.
3. Choose **Redeploy** with build cache cleared if the old Node deployment is cached.
4. The deployment output should show static assets, not a root Express function.
5. Test `/`, authentication, the map, API calls, and a browser refresh on a deep route.

## Quick verification

Backend:

```bash
curl -i https://guidiannode-api-production.up.railway.app/health
```

Local web release:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://guidiannode-api-production.up.railway.app \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY \
  --dart-define=SUPABASE_URL=YOUR_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```
