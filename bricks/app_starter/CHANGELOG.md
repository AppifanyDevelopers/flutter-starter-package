# Changelog

## 0.7.0

- **Permissions helper** (`Permissions.ensure`): one behaviour everywhere, with
  an "Open Settings" fallback when the OS will not prompt again. The platform
  config (iOS Podfile flags, Android manifest) is wired by `post_gen`.
- **Secrets:** `.env.*` are limited to non-secret config (enforced by a test);
  secrets use `dart_defines/<flavor>.json` and `AppSecrets`, passed by Fastlane
  when present.
- **Crash/analytics identity:** flavor tag, user id on login/signup/social and
  after restart, cleared on logout, 5xx responses reported.
- **Flavor selection fix:** `flutter build --flavor production` without
  `--dart-define=FLAVOR` used to run the staging entry point; `--flavor` now
  decides unless the define says otherwise.
- **`tool/new_feature.dart`** scaffolds a feature in the app's conventions.
- Releases: a `tag` job creates `app_starter-v<version>` after the brick
  verifies on `main` (`scripts/tag_brick.dart`).

- **Colours:** new `AppPalette` (neutral, grey and warning ramps, defaults from
  rentsy) drives text, hint and border colours. `scripts/create_app.dart` asks
  for an optional `color.xml` and reads only `warning*`, `neutral*` and `grey*`.
- **Monorepo option:** `scripts/create_app.dart` asks polyrepo (default) or
  monorepo (folder name, base package name) and generates a Melos workspace with
  `apps/<project>`, `<base>_design_system` and `<base>_common`, reusing existing
  packages when adding another app.

- **New `di` flavor** next to `staging` and `production`: id `<application_id>.di`,
  `.env.di` (starts on the staging API URL), app name "<App> DI", Fastlane
  `build_di` lanes. The guided script now requires all three Android packages in
  `google-services.json`.
- **Flavor ribbon on the launcher icon and in-app:** red STAGING and blue DI at
  the top left (production none), drawn by `post_gen` and written as per-flavor
  icon sets. Fixes a latent iOS bug where production pointed at a missing
  `AppIcon-production` asset set.
- **Signup is a 3-step stepper:** basic details -> confirm email code -> password
  (account created last, with a verification token). Needs a backend change, see
  `docs/ai/api-workflow/BACKEND_CONTRACT.md`. `AuthRepository.signup` gains a
  required `verificationToken`, plus new `verifySignupOtp`.
- **Forms:** validation only on submit, whitespace-only input is rejected
  everywhere, name/email/phone keyboard types (email blocks spaces, phone blocks
  letters), keyboard hides on every button press and on tapping blank space,
  cursor/selection use the primary colour, and password creation shows a live
  rule checklist (8+ chars, capital, number, special, no spaces; enforced).
  `form_validator` is replaced by in-house validators.
- **Notifications:** Android status-bar icon, and a post-login "Turn on / Later"
  dialog that asks the OS for permission only after "Turn on" (it used to ask at
  app start). iOS shows the app icon, as the system requires.
- **Photos:** the picker offers camera, gallery or files, then crops.

- `scripts/create_app.dart` asks for a parent folder and creates
  `<parent>/<project_name>/` itself (it used to write the project's files
  straight into whatever folder you typed, e.g. the Desktop). It refuses a
  target folder that already exists and is not empty.
- **Breaking:** the `org` brick var is replaced by `application_id`, used
  exactly as typed for the Android `applicationId` and iOS bundle id
  (staging adds `.staging`). The project name is no longer appended, so
  `com.acme.rentals` is `com.acme.rentals`, not
  `com.acme.rentals.rentals_app`. Underscores and hyphens are rejected.
  `post_gen` also rewrites the Android `namespace`/`MainActivity` package and
  the leftover iOS base bundle ids that `flutter create` derives from the
  project name.

- **Breaking for scripted generation:** new brick var `ios_app_store_url`
  (used by the update dialog instead of a hardcoded `id0000000000`). Scripts
  that call `mason make -c vars.json` must now include it.
- API base URL prompts and defaults now say "include the `/api` prefix" and
  default to `.../api` (was `.../api/v1`); `AppEndpoints` are relative to it.
- `scripts/create_app.dart`: the two Firebase files are now required and
  validated (package names for both flavors, Google sign-in enabled,
  `CLIENT_ID`/`REVERSED_CLIENT_ID`/`BUNDLE_ID` present). The Google Sign-In
  keys in `Info.plist` are filled from the plist, so the Google button works
  without hand-editing. The `Info.plist` placeholder for the reversed client
  id is now the whole value (it used to double the `com.googleusercontent`
  prefix if replaced as documented).

- `DioApiClient` now speaks the reference backend envelope: sends
  `Authorization: Bearer` from `SessionService.readToken`, parses error bodies
  into `ApiErrorResponse` (`code`, `fieldErrors`, `retryAfterSeconds`), and on
  `401 unauthenticated` clears the session and returns to login.
- Add `ApiEnvelope` / `PaginationMeta` (`core/network/api_envelope.dart`) for
  success bodies, plus tests for error and envelope parsing.
- `AppEndpoints` aligned with the reference backend's paths (adds refresh,
  logout, notifications, content and device-token endpoints).

## 0.6.0

- Add Google and Apple Sign-In ("Continue with...") on Login and Signup,
  as a one-shot action that creates-or-logs-in immediately -- no forced
  phone/DOB/photo/OTP step, since the provider already verified the email.
  Apple is iOS-only (Android/Web need a hosted redirect this template
  doesn't have).
- No `firebase_auth` dependency: Google's `idToken`/Apple's `identityToken`
  go straight to `AuthRepository.loginWithGoogle`/`loginWithApple`, the
  same shape as email `login`/`signup` -- a real backend verifies them
  server-side. `SocialAuthService` is shared by both `LoginController` and
  `SignupController` rather than duplicated per screen.
- `post_gen` adds placeholder Google Sign-In keys to iOS `Info.plist`
  (needs real values from your `GoogleService-Info.plist` -- see
  `POST_GEN_MANUAL_STEPS.md`) and creates `Runner.entitlements` with the
  Apple Sign-In entitlement, wired into every flavor's xcconfig.

## 0.5.0

- The signup/Edit Profile photo picker now crops the picked image
  (`image_cropper`, original/square aspect presets, bounded to 800px at
  70% JPEG quality) instead of using it as-is. Requires a new Android
  manifest activity, added by `post_gen`.
- Add Crashlytics + Analytics, inert until Firebase is configured (same
  tier as push notifications) -- wired into concrete call sites (login,
  signup, logout), not just declared. Required extracting a single
  `FirebaseBootstrap.init()` so Push/Crashlytics/Analytics don't each call
  `Firebase.initializeApp()` independently (which throws on the second call).
- Add `ConnectivityService` + an offline banner shown globally when the
  device has no network.
- Add `UrlLauncherUtils`, centralizing `url_launcher` calls (`AppUpdateService`
  now uses it instead of its own inline `launchUrl`).
- Fastlane's production lanes (and iOS's staging lane, already a release
  build) now build with `--obfuscate --split-debug-info`; `POST_GEN_MANUAL_STEPS.md`
  notes the resulting symbols must be uploaded to Crashlytics once it's
  configured, or crashes from these builds can't be de-obfuscated.

## 0.4.0

- Signup is now a 2-step wizard (account, then phone/date of birth/photo)
  followed by an email OTP verification screen, mirroring forgot-password's
  OTP flow. `AuthRepository` gains `sendVerificationOtp`.
- Add DOB and a photo picker (`image_picker`, gallery only) to Edit Profile
  too; `post_gen` now adds the iOS `NSPhotoLibraryUsageDescription` string
  this requires.
- Add search and infinite-scroll pagination to FAQ; `SettingsContentRepository.getFaqs`
  gains `page`/`pageSize`/`query` params.
- Add pull-to-refresh (and a shimmer loading skeleton) to Terms & Conditions
  and Privacy Policy; shimmer skeletons also added to FAQ and Edit Profile
  (the `AppShimmer` widget existed since 0.1.0 but was never actually used
  anywhere until now).
- Add a "STAGING" ribbon banner shown only on staging builds.
- Add semantic `success`/`warning`/`info` colors to `AppColors`, applied to
  the existing success snackbars via a new `AppSnackbar.success` helper.
- Add `AppEndpoints`, a reference class of documented (currently unused)
  endpoint paths for whoever does the real `TODO(swap-backend)` work.
- Add build-only Fastlane lanes (`build_staging`/`build_production`) for
  both platforms, scaffolded fresh by `post_gen` since `android/`/`ios/`
  aren't part of `__brick__`.
- Add `.claude/commands/tag-brick.md` to this repo (not shipped to
  generated projects) for tagging brick releases.

## 0.3.0

- Add Firebase Cloud Messaging + `flutter_local_notifications`, inert until
  a real Firebase project is configured (`PushNotificationService`).
- Add tap-to-navigate for notifications via a `data: {"route": "..."}`
  payload contract, covering foreground, background-resumed, and
  cold-started-by-tap cases.
- `post_gen` now also patches the generated Android Gradle files
  (conditional Google Services plugin, core library desugaring) and bumps
  the iOS minimum deployment target to 15.0, all required for the above.
- Fixed the documented `mason make ... -c '{...}'` usage across all docs/CI
  to use a JSON file path -- inline JSON isn't supported by this Mason CLI
  version and fails with `PathNotFoundException`.

## 0.2.0

- Add "Remember me" on login (remembers email only; session persistence is
  unaffected either way).
- Add an app version/build number footer on the Settings screen
  (`package_info_plus`).
- Add a light/dark/system "Appearance" toggle on the Settings screen,
  persisted via a new `ThemeController`.

## 0.1.0

- Initial release: login, signup, forgot password, dashboard, settings
  (FAQ, contact us, terms & conditions, privacy policy, notification
  settings, change password, edit profile, delete account, logout), fake
  swappable repositories, GetX auth guard, staging/production flavors,
  `.env` config, seed-color theming, in-app update prompt.
