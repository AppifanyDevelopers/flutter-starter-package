# Login run 1 (blind)

First blind implementation of `specs/login.json` (template `auth`): a
`DioAuthRepository` (login real, everything else delegates to the fake),
`LoginController` field errors from `ApiErrorResponse.firstError`, and an
`errorText` on `AppTextFormField`. Imports use package `verify_app`.
Score: 16/16 (`dart scripts/eval_api.dart --spec login --app <dir>`).
The checks were written from the spec BEFORE this run and failed 6/16 on the
untouched generated app, so they measure the new work, not existing behaviour.

Checks proven able to fail by mutation: endpoint magic string, `message ==`,
`expires_in`, `retryAfterSeconds`/`Timer`, and `debugPrint` of a password.

Spec gaps the agent guessed (open, need an owner decision):
1. Added `errorText` to the shared `AppTextFormField` (outside the feature
   folder; CONVENTIONS said feature + endpoints only). Now allowed in spec.
2. 422 without an email/password entry falls back to a snackbar.
3. Email is NOT lowercased although the backend rule says "email, lowercase".
4. Optional device fields (`device_id`, `device_token`, `platform`) not sent.
5. Errors clear at the start of `login()`, before client-side validation.
