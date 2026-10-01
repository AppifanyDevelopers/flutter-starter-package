# Login run 2 (blind), spec v2

Spec v2: email lowercased, no device fields, `errorText` allowed on the shared
`AppTextFormField`. Score 18/18, first try. Imports use package `verify_app`.

Guesses: 422 without an email/password entry falls back to a snackbar
(same as run 1); lowercasing happens in the repository, not the controller;
field errors clear at the start of `login()`; a 200 with no token/user returns
a generic InternalAppError; the push prompt handoff is left out as the spec
says. Not covered: the push dialog (register_device_token), which has no run yet.
