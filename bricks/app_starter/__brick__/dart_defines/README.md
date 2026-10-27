# dart_defines

Per-flavor build-time values, passed with `--dart-define-from-file`. Copy
`<flavor>.json.example` to `<flavor>.json` and fill it in; the real files are
git-ignored. Read them through `lib/core/config/app_secrets.dart`.

Keep **secrets here, not in `.env.*`**: the `.env` files are bundled as assets
and readable from the built app.
