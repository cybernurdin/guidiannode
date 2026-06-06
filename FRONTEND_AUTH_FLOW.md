# Frontend Authentication Flow

1. The user submits the existing registration or login form.
2. Flutter calls the matching WhatsApp `start-verification` endpoint.
3. The app displays the token, expiry notice, and **Verify via WhatsApp** button. No six-digit OTP input is shown.
4. The button opens the backend-provided `wa.me` URL in WhatsApp.
5. Flutter polls `GET /api/verification/status/:verificationId` every three seconds.
6. Polling stops on `verified` or `expired`.
7. A verified response is stored through the existing `SessionService`, then the user moves into the existing dashboard flow.

The release API URL is supplied at compile time with `--dart-define=API_BASE_URL=https://guidiannode-production.up.railway.app`.
