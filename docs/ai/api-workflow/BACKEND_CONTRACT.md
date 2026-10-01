# Backend contract (unoStarterKit reference API)

Distilled from the "API Response Reference" (2026-09-30). This is the one
place the generator learns the wire format; per-endpoint samples live in
`specs/`. Base path is `/api`; send `Accept: application/json`, and
`Authorization: Bearer <access_token>` on protected endpoints.

## Rules

- **Success vs failure is decided by the HTTP status.** The body's `status`
  repeats it.
- **Branch on `code`, never on `message`.** Messages may be reworded but are
  always safe to show the user.
- Success: `{status, message|null, data, meta?}`. `data` is an object, an
  array, `[]` or `null`, depending on the endpoint. Parse with `ApiEnvelope`
  (`core/network/api_envelope.dart`).
- Paginated success adds `meta {current_page,last_page,per_page,total,from,to}`.
  No more pages when `current_page == last_page`. Empty: `data: []`,
  `total: 0`, `from/to: null`, `last_page: 1`.
- Error: `{status, code, message, errors}`. `errors` is `null` except on
  validation and OTP errors, where it maps field -> list of messages; show the
  first under the field. Parsed into `ApiErrorResponse`
  (`core/errors/app_error.dart`).

## Codes and handling

| HTTP | code | Handling |
|---|---|---|
| 401 | `invalid_credentials` | message on the login form |
| 401 | `unauthenticated` | session ended: clear session, show login (done globally in `DioApiClient`) |
| 403 | `account_blocked`, `account_pending_approval`, `forbidden` | show message |
| 404 | `not_found` | message or empty state |
| 422 | `validation_failed` | `errors[field][0]` under each field |
| 422 | `reset_token_invalid` | message; restart reset flow |
| 422 | `otp_invalid`, `otp_expired`, `otp_attempt_limit` | `errors.otp[0]`; offer Resend on expired/limit |
| 422 | `otp_already_verified`, `otp_not_found` | continue / restart flow |
| 422 | `otp_resend_cooldown`, `otp_resend_limit` | wait `Retry-After` / restart |
| 422 | `otp_delivery_failed`, `otp_error` | message; let the user retry |
| 429 | `too_many_requests` | wait `Retry-After` seconds |
| 405 | `method_not_allowed` | developer error |
| 500 | `server_error` | generic error; message is safe |
| 503 | `service_unavailable` | maintenance screen, retry later |

## Tokens and limits

- Login, register and refresh return `data.access_token`, `token_type`,
  `expires_in` (3600) and `user`. Refresh must happen before expiry.
- Login, register and the four password-reset endpoints: 3 requests per 60
  minutes per IP (`X-RateLimit-*`, `Retry-After` on 429).
- A password reset invalidates every earlier token (`401 unauthenticated`).

## Known quirks worth remembering

- `password/forgot` and `password/resend` return the same 200 for unknown
  emails: the app must always continue to the code screen.
- `password/verify` returns `reset_token`, which is a token but **not** a
  login. The router only treats `token`/`access_token` as auth.
- The notifications list has no `per_page` param; the server fixes it at 20.
- The reference has no signup OTP, delete-account or notification-preference
  endpoints; those `AppEndpoints` entries are marked as not provided.
