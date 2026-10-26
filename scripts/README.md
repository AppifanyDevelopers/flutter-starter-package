# scripts/create_app.dart

An interactive wrapper around `mason make app_starter` for spinning up a new
client project. Run it from anywhere inside a checkout of this repo:

```bash
dart scripts/create_app.dart
```

No `pub get` needed -- it only uses `dart:io`/`dart:convert`, and locates
this repo's `bricks/app_starter` relative to its own file location, so it
works regardless of your current working directory.

## What it asks for

| Prompt | Maps to | Required? |
|---|---|---|
| Parent folder | Where to create the project. A `<project_name>` folder is created inside it, so files are never spread into the folder you pick; the script refuses if that folder already exists and is not empty | Yes |
| Package/project name | `project_name` brick var | Yes |
| App display name | `app_name` brick var | Yes |
| Application ID (exactly the Android applicationId / iOS bundle id; letters and digits only) | `application_id` brick var | Yes |
| Brand color | `seed_color` brick var | No (default `#6750A4`) |
| Description | `description` brick var | No |
| Staging/production API URLs (include the `/api` prefix; trailing `/` is stripped) | `api_base_url_staging`/`_production` | No |
| iOS App Store URL | `ios_app_store_url` | No (placeholder allowed) |
| App icon (PNG) | Copied to `assets/logo/icon.png`, then `flutter_launcher_icons` is rerun | No |
| `google-services.json` | Copied to `android/app/`. Validated: must list both `<application_id>` and `<application_id>.staging`, and have Google sign-in enabled | **Yes** |
| `GoogleService-Info.plist` | Copied to `ios/Runner/`. Validated: must contain `CLIENT_ID`, `REVERSED_CLIENT_ID` and a `BUNDLE_ID` matching this project. The Google Sign-In keys in `Info.plist` are filled from it | **Yes** |

The two Firebase files are required: push, Crashlytics, Analytics and Google
Sign-In are always part of the app, so the script keeps asking until the files
are valid. Everything else marked "No" can be skipped with Enter. Driving
`mason make` directly (CI, batch generation) skips this script and therefore
the Firebase files; it still needs every brick var, including
`ios_app_store_url`. See [docs/POST_GEN_MANUAL_STEPS.md](../docs/POST_GEN_MANUAL_STEPS.md).

## Why a script, not more Mason vars

Mason vars are text substituted into template files. An app icon and
Firebase config files are real binary/per-client files a team downloads
from Xcode/the Play Console/Firebase console -- there's nothing to
template, they just need to be copied into the right place after
generation. This script does that copying so you don't have to remember
the exact paths (`assets/logo/icon.png`, `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`) every time.

## What it does NOT do for you

- **Add `GoogleService-Info.plist` to the Xcode project.** Copying the file
  into `ios/Runner/` is not enough -- Xcode only bundles resources it knows
  about. Open `ios/Runner.xcworkspace` and drag the file into the Runner
  target (one-time, per project). `google-services.json` doesn't have this
  problem -- the Gradle plugin picks it up from disk automatically.
- **Validate the icon looks good at every size**, just that it's a `.png`.
  Re-run `dart run flutter_launcher_icons` yourself after swapping it again.
- **Validate `GoogleService-Info.plist`'s contents** (only `google-services.json`
  is checked, since it's parseable JSON) -- a mismatched Firebase iOS app
  will surface as a runtime error, not a build-time one.
- Anything else already listed in [docs/POST_GEN_MANUAL_STEPS.md](../docs/POST_GEN_MANUAL_STEPS.md)
  (real backend, iOS signing, store listings, etc.) -- those aren't
  file-copying problems and can't be scripted the same way.

## Generating many projects

Run the script again for each client -- it's stateless and doesn't touch
this repo. For fully unattended/batch generation (no prompts), use
`mason make app_starter -c vars.json` directly instead (see the root
README's "Advanced: scripted / CI generation" section) and handle the
icon/Firebase file copying yourself, following the same three destinations
listed above.
