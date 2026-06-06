# Backend Authentication Flow

1. Registration or login posts a normalized phone number to its `start-verification` endpoint.
2. The backend creates a pending `otp_sessions` record with a hashed `CM-XXXXX` token and a ten-minute expiry.
3. The response contains `verificationId`, `token`, `expiresAt`, and a `wa.me` URL for `237657262038`.
4. Meta sends the user's incoming WhatsApp message to `POST /webhook`.
5. The webhook validates `X-Hub-Signature-256`, extracts the sender and token, then returns HTTP 200 before background processing.
6. A matching, pending, non-expired session is atomically changed to `verified`; sender details and `verified_at` are stored.
7. `GET /api/verification/status/:verificationId` finalizes the existing registration or login path, marks the existing user phone as verified, and returns the normal JWT app session.

The old OTP columns and service remain for schema compatibility, but active registration and login routes use inbound WhatsApp verification. Twilio is not part of the active authentication path.
