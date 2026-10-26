# flutter_starter_pack

A Mason brick (`bricks/app_starter`) that generates a fully functional
Flutter app -- Login (with Remember me), a 2-step Signup wizard (account,
then phone/DOB/photo) with email OTP verification, Forgot Password (also
OTP-based), a Dashboard, and a Settings screen (Appearance/dark mode, FAQ
with search, Contact Us, Terms & Conditions, Privacy Policy, Notification
Settings, Change Password, Edit Profile, Delete Account, Logout, app
version) -- wired with GetX, staging/production flavors, `.env` config, an
in-app update prompt, Firebase push notifications with tap-to-navigate
(inert until a real Firebase project is added), and build-only Fastlane
lanes. Everything else runs against an in-memory fake backend by default,
so a freshly generated app runs immediately with no server setup.

Spin up a new client app in minutes: give it a name, an application id, and a brand
color, and get a working app with auth + settings + dashboard already done.

## Generate a new project

1. **Prerequisites**: Flutter SDK, Dart (bundled with Flutter), and Mason
   CLI (`dart pub global activate mason_cli`; make sure
   `$HOME/.pub-cache/bin` is on your `PATH`).
2. **One-time setup**, from this repo's root:
   ```bash
   mason get
   ```
3. **Run the guided generator**:
   ```bash
   dart scripts/create_app.dart
   ```
   It prompts for the project name, app name, application id, brand
   color, description, and API URLs -- and, since these are real per-client
   files rather than text Mason can template, optionally a real **app
   icon** (PNG) and the two **Firebase config files**
   (`google-services.json`, `GoogleService-Info.plist`). Anything left
   blank is skipped and can be added later; see
   [scripts/README.md](scripts/README.md) for exactly what each prompt
   does.
4. **Run the generated app**:
   ```bash
   cd <parent folder>/<project name>
   flutter run --flavor staging -t lib/main.dart --dart-define=FLAVOR=staging
   ```
   Demo login: `demo@example.com` / `password123`. Any OTP screen (signup or
   forgot password) accepts `1234` against the fake backend.
5. **Work through the manual-steps checklist**:
   [docs/POST_GEN_MANUAL_STEPS.md](docs/POST_GEN_MANUAL_STEPS.md) -- real
   backend integration, the actual Firebase project, iOS code signing,
   store listings, Fastlane deploy lanes, and a few other things a name and
   a brand color can't automate.

Run the script again anytime to generate another project -- it's stateless
and only touches the output directory you give it, never this repo.

### Advanced: scripted / CI generation

For automation (batch-generating several apps, CI, etc.) skip the prompts
and drive Mason directly with a vars file:

```bash
mason add -g app_starter --path bricks/app_starter   # install once, from anywhere

mkdir ~/clients/acme_rentals && cd ~/clients/acme_rentals
cat > vars.json <<'EOF'
{
  "project_name": "acme_rentals",
  "app_name": "Acme Rentals",
  "application_id": "com.acme.rentals",
  "seed_color": "#1E88E5",
  "api_base_url_staging": "https://staging-api.acme.com/api",
  "api_base_url_production": "https://api.acme.com/api",
  "ios_app_store_url": "https://apps.apple.com/app/id1234567890",
  "description": "Acme Rentals customer app"
}
EOF
mason make app_starter -o . -c vars.json
```

This path doesn't apply a real app icon or Firebase config for you -- see
`scripts/create_app.dart` for how to do that (copy the icon to
`assets/logo/icon.png` and rerun `dart run flutter_launcher_icons`; copy
`google-services.json` to `android/app/`; add `GoogleService-Info.plist` to
`ios/Runner/` via Xcode).

Note: `-c` takes a path to a JSON file, not inline JSON -- `mason make ... -c '{...}'` fails with a `PathNotFoundException` on this Mason CLI version.

`post_gen` automatically runs `flutter create` (native android/ios
folders), scaffolds Fastlane, wires Firebase's native config, runs
`flutter_flavorizr` (staging/production flavors), and
`flutter_launcher_icons` (app icon) for you.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the feature structure,
the fake/real repository swap pattern, the auth guard, theming, pagination,
and the signup/OTP flow.

## Verify a change to the brick

```bash
mason make app_starter -o /tmp/verify-app -c vars.json --on-conflict overwrite
cd /tmp/verify-app
flutter analyze
flutter test
flutter build apk --debug --flavor staging
flutter build apk --debug --flavor production
flutter build ios --no-codesign --debug --flavor staging
flutter build ios --no-codesign --debug --flavor production

# Optional, if the fastlane gem is installed -- proves the lanes actually run:
(cd android && fastlane build_staging)
(cd ios && fastlane build_staging)
```
