#!/usr/bin/env bash
set -Eeuo pipefail

# GuardianNode Flutter Web build for Vercel.
# The project was created with Flutter 3.41.4, so keep this pinned unless
# the repository is deliberately upgraded and tested with another version.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.4}"
FLUTTER_HOME="${HOME}/flutter-${FLUTTER_VERSION}"

echo "==> Building GuardianNode with Flutter ${FLUTTER_VERSION}"

if [ ! -x "${FLUTTER_HOME}/bin/flutter" ]; then
  echo "==> Installing Flutter ${FLUTTER_VERSION}"
  rm -rf "${FLUTTER_HOME}"
  git clone \
    --depth 1 \
    --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter precache --web
flutter pub get

API_BASE_URL="${API_BASE_URL:-https://guidiannode-api-production.up.railway.app}"
WHATSAPP_TARGET_NUMBER="${WHATSAPP_TARGET_NUMBER:-237657262038}"
GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY:-}"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if [ -z "${GOOGLE_MAPS_API_KEY}" ]; then
  echo "WARNING: GOOGLE_MAPS_API_KEY is empty. The web map may not work."
fi

if [ -z "${SUPABASE_URL}" ] || [ -z "${SUPABASE_ANON_KEY}" ]; then
  echo "WARNING: Supabase web configuration is incomplete. Realtime/auth features may not work."
fi

flutter build web \
  --release \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define="VITE_API_BASE_URL=${API_BASE_URL}" \
  --dart-define="WHATSAPP_TARGET_NUMBER=${WHATSAPP_TARGET_NUMBER}" \
  --dart-define="VITE_WHATSAPP_TARGET_NUMBER=${WHATSAPP_TARGET_NUMBER}" \
  --dart-define="GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY}" \
  --dart-define="VITE_GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" \
  --dart-define="VITE_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" \
  --dart-define="SHOW_DEBUG_OTP_HELPER=false"

test -f build/web/index.html
echo "==> Flutter web build completed successfully."
