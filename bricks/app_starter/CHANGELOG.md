# Changelog

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
