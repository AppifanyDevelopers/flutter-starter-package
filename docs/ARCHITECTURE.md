# Architecture

`bricks/app_starter/__brick__` is the single source of truth -- there is no
separate "reference app" kept in sync by hand. Running `mason make
app_starter` locally with default values *is* how you see/demo the base app,
and CI does exactly that on every PR.

## Feature structure

Feature-first, GetX:

```
lib/features/<feature>/
├── data/
│   ├── model/        # plain Dart classes, no codegen
│   └── repository/   # <Feature>Repository (interface) + Fake<Feature>Repository
└── presentation/
    ├── bindings/
    ├── controllers/
    └── screens/
```

Each repository interface has exactly one `Fake*` implementation wired in
its feature's `Bindings` via `Get.lazyPut<XRepository>(() => FakeXRepository())`
with a `// TODO(swap-backend)` marker next to it. Swapping to a real backend
is: write `DioXRepository implements XRepository`, change that one line.
Controllers and screens never change.

## Loading/error/success pattern

`lib/core/enums/the_states.dart` defines `enum TheStates {initial, success,
error, loading}` with a `.showWidget(loading:, success:, error:, orElse:)`
extension. Controllers expose `Rx<TheStates>` fields; screens wrap content in
`Obx(() => controller.state.value.showWidget(...))`. This is the only
loading-state mechanism in the app -- no global loading overlay package.

## Auth guard

`GetMiddleware.redirect()` is synchronous; secure-storage reads are not. So
`SessionService` hydrates an in-memory `isLoggedInSync` flag once at boot
(`SplashController`) and updates it on login/logout. `AuthGuard`/`GuestGuard`
read that cached flag -- never storage directly.

## Theming

`lib/core/theme/app_colors.dart` holds one line: the seed color. `AppTheme`
builds a `ColorScheme.fromSeed` from it. Rebranding = changing that one
value (or regenerating with a different `seed_color`).

Light/dark/system is a separate, user-facing choice: `ThemeController`
(`lib/core/theme/theme_controller.dart`) holds an `Rx<ThemeMode>` persisted
in `GetStorage`, read by `MyApp` (wrapped in `Obx`) and set from the
"Appearance" item on the Settings screen. The seed color drives *what* the
palette looks like; `ThemeController` drives *which* brightness is shown.

## Remember me

"Remember me" on the login screen only remembers the *email* for next time
(`SessionService.rememberedEmail`, in `GetStorage`) and pre-fills it on the
next visit to the login screen. It does not affect session persistence --
the access token already survives app restarts via secure storage
regardless of this checkbox; logging out always clears both.

## Push notifications

`lib/core/notifications/push_notification_service.dart` wraps Firebase
Messaging + `flutter_local_notifications`. It's deliberately inert without a
real Firebase project: `PushNotificationService.init()` (called from
`SplashController`) checks `FirebaseBootstrap.isAvailable` and returns early
if Firebase never initialized, so the rest of the app works with zero
Firebase setup -- see `docs/POST_GEN_MANUAL_STEPS.md` for what activates it,
and the "Firebase bootstrap" section below for why it doesn't call
`Firebase.initializeApp()` itself.

**Payload contract:** a push that should navigate somewhere on tap must
include a `route` key in its `data` payload matching a name in `AppRoutes`
(e.g. `{"route": "/settings/notifications"}`). Three separate entry points
funnel into the same route check:
- `FirebaseMessaging.onMessage` (app in foreground) -- shown via a local
  notification, whose tap handler carries the route forward as its payload.
- `FirebaseMessaging.onMessageOpenedApp` (app resumed from background by a
  tap) -- navigates immediately via `Get.toNamed`.
- `FirebaseMessaging.instance.getInitialMessage()` (app cold-started by a
  tap) -- can't navigate immediately since GetX isn't booted yet; instead
  `PushNotificationService.consumeInitialRoute()` is awaited once by
  `SplashController` and folded into its single `Get.offAllNamed` call, so
  there's never a double-navigation.

The background message handler (`_firebaseMessagingBackgroundHandler`) is a
top-level function annotated `@pragma('vm:entry-point')`, per Firebase's
requirement -- it runs on a separate isolate with no access to this app's
state, so it only re-initializes Firebase and nothing else.

**Native config is patched, not hand-maintained:** `android/` and `ios/`
aren't part of `__brick__` (see below) -- `post_gen.dart` patches the
`flutter create`-generated Gradle files with anchored regexes for: the
Google Services plugin (applied *conditionally*, only if
`google-services.json` exists -- see `POST_GEN_MANUAL_STEPS.md`), core
library desugaring (`flutter_local_notifications` requires it
unconditionally), and iOS's minimum deployment target (bumped from
`flutter create`'s default 13.0 to 15.0, which Firebase's iOS SDK requires).

## Signup wizard + OTP

Signup is a shared `SignupController` driving three screens (a `StepIndicator`
shows "Step N of 3"), the same "one controller across several screens" shape
as `ForgotPasswordController`:
1. `SignupScreen` (basic details: name, email, phone, date of birth, optional
   photo) -- `submitDetails()` validates, then calls
   `AuthRepository.sendVerificationOtp` and moves on. No account exists yet.
2. `SignupOtpScreen` -- `verifyOtp()` calls `AuthRepository.verifySignupOtp`,
   which returns a single-use *verification token* (stashed in the
   controller). Resend is available.
3. `SignupPasswordScreen` -- `createAccount()` validates the password
   (8+ chars, a capital, a number, a special character, no spaces; a live
   `PasswordRulesChecklist` shows progress) and only then calls
   `AuthRepository.signup(..., verificationToken:)`, saves the session and
   routes to the dashboard.

The account is deliberately created last, and only for an email whose code was
verified -- an unverified signup can't reach authenticated routes, and nobody
can register an email they don't own. This needs a backend that issues the
verification token at step 2 and requires it at registration (the reference
backend's `register` currently takes the password directly; see
`docs/ai/api-workflow/BACKEND_CONTRACT.md`).
`FakeAuthRepository.signup` accepts phone/DOB/photo (like a real endpoint
would) but doesn't persist them into `FakeProfileRepository`'s separate
in-memory profile; keeping the two fakes in sync would add real complexity
for a cosmetic benefit in a template.

## Social sign-in

Google and Apple are handled entirely differently from the email flow
above: `SocialAuthService` (`lib/core/auth/social_auth_service.dart`) is a
single shared implementation used identically by both `LoginController` and
`SignupController`, rather than duplicated per screen -- a "continue with
Google/Apple" tap creates-or-logs-in immediately, with no OTP or phone/DOB/
photo step, since the provider already verified the user's email. That
information can still be added later via Edit Profile.

**No `firebase_auth` dependency.** A common reference pattern (and the one
this template's design was checked against) bridges Google/Apple credentials
through `FirebaseAuth.instance.signInWithCredential(...)` purely to get a
verified UID/email, then discards Firebase's own session and sends only the
provider UID to a custom backend. Since that token is thrown away either
way, this template skips the bridge: `GoogleSignInAuthentication.idToken`
and `AuthorizationCredentialAppleID.identityToken` go straight to
`AuthRepository.loginWithGoogle`/`loginWithApple` -- the same shape as
`login(email, password)`. A real backend verifies the token server-side
(a standard, documented flow for both providers) and returns a session.

**Apple's first-authorization-only quirk**: Apple only returns the user's
real name/email on their *first* ever authorization for this app -- later
sign-ins return only a stable identifier. `loginWithApple`'s `email`/
`fullName` params are nullable for exactly this reason; a real backend must
persist them on that first call, since Apple won't send them again.

**Apple Sign-In is iOS-only** (`SocialSignInButtons` checks `Platform.isIOS`)
-- confirmed directly against `sign_in_with_apple`'s own source that
Android/Web require `WebAuthenticationOptions` pointing at a hosted redirect
URI, which needs a real backend this template doesn't have. Cancellation
(tapping outside the sheet, dismissing the system UI) is treated as "nothing
happened," not an error -- see `core/utils/social_auth_cancellation.dart`.

**Native config is patched, not hand-maintained** (same reasoning as
everywhere else `android/`/`ios/` aren't part of `__brick__`): Google
Sign-In needs a URL scheme + `GIDClientID` in `Info.plist`, inserted as
clearly-marked placeholders since the real values only exist once a
developer has their actual `GoogleService-Info.plist`. Apple Sign-In needs
the `com.apple.developer.applesignin` entitlement; since `flutter create`
doesn't generate a `Runner.entitlements` file or wire `CODE_SIGN_ENTITLEMENTS`
into any build configuration by default (confirmed empirically), `post_gen.dart`
creates one and points every flavor's Debug/Release/Profile xcconfig at it --
simpler and more resilient than inserting `CODE_SIGN_ENTITLEMENTS` into each
of `project.pbxproj`'s many `XCBuildConfiguration` blocks directly.

## Pagination

Demonstrated on FAQ, the one list-shaped feature -- there's no generic
`Paginated<T>` type, since inventing one for a single call site would be a
premature abstraction. `SettingsContentRepository.getFaqs({page, pageSize,
query})` returns one page; a page shorter than `pageSize` means there's no
next page (no separate total-count field, the same convention many real
paginated APIs use). `FaqController` tracks `page`/`hasMore`/`isLoadingMore`
and a `ScrollController` that calls `loadMore()` near the bottom of the
list. Copy this shape for any other list that needs paging later.

## Semantic colors

`AppColors.success`/`warning`/`info` are fixed values, not derived from
`seed` -- like Material's own error color, a status color needs to stay
recognizable regardless of a client's brand color. `AppSnackbar.success(...)`
is a thin wrapper so success feedback looks consistent everywhere instead of
each call site restyling `Get.snackbar` itself.

## Flavors and the environment banner

Three flavors: `production`, `staging` and `di` (flavorizr ids `<id>`,
`<id>.staging`, `<id>.di`). `di` reads `.env.di`, which starts out pointing at
the staging API -- change `API_BASE_URL` in it when `di` gets its own backend.

`MyApp` wraps routed content in `EnvironmentBanner`: a red "STAGING" or blue
"DI" corner ribbon at the top left, none on production. The same ribbon is
drawn onto each flavor's launcher icon by `post_gen.dart` (via the `image`
package; production keeps the plain icon), and `flutter_launcher_icons`
writes a separate icon set per flavor from the generated
`flutter_launcher_icons-<flavor>.yaml` files. All of this is separate from
(and simpler than) flutter_flavorizr's own ribbon-banner feature, which is
deliberately excluded from the generator (see below) since it needs a network
download during generation.

## Fastlane

`android/fastlane/` and `ios/fastlane/` are scaffolded fresh by
`post_gen.dart`'s `_scaffoldFastlane` (not part of `__brick__`, for the same
reason `android/`/`ios/` themselves aren't -- they only exist once `flutter
create` has run). Each platform gets `build_staging`/`build_production`
lanes that shell out to `flutter build` rather than invoking Gradle/Xcode
directly, since that's what correctly bundles Flutter's assets. Deploy lanes
(TestFlight/Play upload) aren't included -- see `POST_GEN_MANUAL_STEPS.md`
for the credentials that upgrade path needs.

Every lane that already builds in release mode (iOS's `build_staging` and
`build_production`, Android's `build_production`) also passes `--obfuscate
--split-debug-info=build/debug-info/<platform>-<flavor>`. Android's
`build_staging` stays a plain unobfuscated `--debug` build -- `--obfuscate`
requires a release/profile build, and turning staging into a release build
is a bigger behavior change than "harden the lanes" calls for.

## Image cropping

`lib/core/utils/pick_and_crop_image.dart` is one function,
`pickAndCropProfilePhoto()`, used identically by the signup wizard's photo
step and Edit Profile's avatar picker: ask for a source (camera, gallery or files), then crop with
`image_cropper` (original/square aspect presets -- no forced circle-crop UI,
since the result is displayed inside a circular `AvatarPicker` regardless).
Bounded to 800x800 at 70% JPEG quality via `cropImage`'s own
`maxWidth`/`maxHeight`/`compressQuality` params, rather than a separate
resize/compress pass with the `image` package -- same practical outcome
without a second image-processing dependency. `image_cropper`'s Android side
(uCrop) needs an activity declared in `AndroidManifest.xml`; since
`android/` isn't part of `__brick__`, `post_gen.dart`'s
`_wireAndroidImageCropper` patches it in, the same anchored-text-patch
approach as every other native fix here. iOS needs no configuration for
this package.

## Firebase bootstrap

Push notifications, Crashlytics, and Analytics all need
`Firebase.initializeApp()` to have run -- but calling it more than once
throws a duplicate-app error, and Crashlytics specifically needs to run
*first*, before anything else, so `FlutterError.onError` is wired as early
as possible. `lib/core/firebase/firebase_bootstrap.dart` centralizes this:
`main.dart` calls `FirebaseBootstrap.init()` once, right after
`GetStorage.init()` and before `runApp`; `PushNotificationService`,
`CrashlyticsService`, and `AnalyticsService` all read
`FirebaseBootstrap.isAvailable` instead of calling `Firebase.initializeApp()`
themselves. The one exception is the push notification background message
handler, which keeps its own `Firebase.initializeApp()` call -- it runs on a
separate isolate that doesn't share this state.

`CrashlyticsService.init()` wires `FlutterError.onError` and
`PlatformDispatcher.instance.onError` to Crashlytics and disables collection
in debug builds. `AnalyticsService` is a fixed catalogue (`logSignUp`,
`logLogin`, `logLogout`) rather than a generic `log(String name)`
passthrough, so event names can't drift between call sites -- it uses the
SDK's own `logSignUp`/`logLogin` methods (GA4's recommended events) where
available. Both are inert (no-ops) until Firebase is configured, same as
push notifications.

## Connectivity

`lib/core/connectivity/connectivity_service.dart` wraps `connectivity_plus`
in a `GetxService` exposing `RxBool isOnline`. Registered in
`AppInitializer` like the other root services, but its own `init()` is
fire-and-forget (not awaited) so app boot isn't blocked on a connectivity
check -- `isOnline` starts `true` and corrects itself within a moment if
that's wrong. `OfflineBanner` (a slim red bar, `SizedBox.shrink()` when
online) is wired into `MyApp`'s `builder:` alongside the staging ribbon
banner, so it shows above every screen without touching individual screens.

## Why `change_app_package_name` isn't in the generator pipeline

`flutter create --org` (step 1 of `post_gen.dart`) sets a base id derived from
`<org>.<project_name>`, which `post_gen` then rewrites to the exact
`application_id` (Android namespace and `MainActivity` package, iOS base
bundle ids); flavorizr sets the per-flavor ids. Running
`change_app_package_name` afterwards would do a blind global find/replace of
the bundle id across every Xcode build configuration -- but by then
`flutter_flavorizr` (step 3) has already created distinct per-flavor
bundle ids (staging vs. production). A global rewrite would collapse them
back to one, silently destroying the flavor split. It's kept as a documented
manual fallback only, for renaming an already-generated project later.

## Colours: `AppPalette`

`core/theme/app_palette.dart` holds the neutral, grey and warning ramps. The
theme builds its `ColorScheme` from the brand seed, then overrides
`onSurface`, `onSurfaceVariant`, `outline` and `outlineVariant` (and input
hints/labels) from the neutral ramp, so text and borders look the same across
brand colours. The shipped defaults come from rentsy's design system. Passing a
`color.xml` to `scripts/create_app.dart` regenerates the file: only
`warning<N>`, `neutral<N>` and `grey<N>` are read, missing names keep their
default, the first value wins for repeated names.

## Monorepo layout

`scripts/create_app.dart` can generate the app as one app of a Melos
workspace (the rentsy layout):

```
<folder>/
  melos.yaml, pubspec.yaml
  apps/<project>/
  packages/<base>_design_system/   AppColors, AppPalette, AppTheme
  packages/<base>_common/          shared widgets, validators, keyboard helpers
```

It sets `APP_STARTER_MONOREPO_BASE` for the brick's `post_gen` hook (a plain
`mason make` leaves it unset and gets a standalone app). The hook rewrites every
import of the moved files in `lib/` and `test/` to the two packages' barrel
files, moves the files, scaffolds the packages and adds path dependencies to the
app. Both moved sets import only Flutter and `shimmer`, which is what keeps this
safe; if you add a dependency from those files back into the app, move that file
too or leave the file out of `_commonFiles` in `post_gen.dart`. Running the
script again with an existing monorepo folder adds another app and reuses the
packages without touching them (including their palette).

## Permissions

`core/permissions/permissions.dart`: `Permissions.ensure(AppPermission.camera)`
is the one way to ask. Already allowed returns true silently; undecided shows
the system prompt; denied for good (the OS will not prompt again) shows a
dialog explaining why with an "Open Settings" button. The platform sits behind
`PermissionGateway`, so tests fake it. `post_gen` enables only the iOS
`PERMISSION_CAMERA/PHOTOS/NOTIFICATIONS` Podfile flags (permission_handler
compiles a permission in only when its flag is set) and declares CAMERA,
POST_NOTIFICATIONS and INTERNET in the Android manifest (INTERNET is otherwise
only in the debug/profile manifests). Only the camera source of the photo
picker needs it; gallery and files are system pickers.

## Secrets

`.env.*` files are bundled as assets, so anything in them can be read out of
the built app. They hold only `API_BASE_URL` (a test enforces the allow-list).
Anything else goes through `--dart-define-from-file=dart_defines/<flavor>.json`
and is read in `core/config/app_secrets.dart`. The real JSON files are
git-ignored; `<flavor>.json.example` files are committed, and the Fastlane lanes
pass the file when it exists.

## Which flavor is this build?

`core/build_variants/flavor_resolver.dart`: `--dart-define=FLAVOR=<name>` wins,
otherwise Flutter's own `--flavor <name>` (`appFlavor`), otherwise `staging`.
Before this, a CLI `flutter build apk --flavor production` without the define
silently ran the staging entry point.

## Crash and analytics identity

`core/telemetry/telemetry.dart` is a swappable `TelemetrySink`. The flavor is
set at boot; `SessionService.saveSession(token, userId:)` identifies the user
(and stores the id so a restarted app identifies again), `clear()` un-identifies,
and `DioApiClient` reports 5xx responses with the request that failed (4xx are
expected outcomes and are not reported). Only the backend's user id is sent,
never an email or name.

## Scaffolding a feature

`dart run tool/new_feature.dart order_history --item Order` creates the model,
repository interface, a fake repository, controller (loading / error / empty /
pull-to-refresh that never shows the shimmer), screen, bindings, an
AuthGuard-protected route and tests. In a monorepo app it imports the shared
widgets from `<base>_common`. Generated imports use `show` because dartz also
exports an `Order`.

## Releasing the brick

Bump `version:` in `bricks/app_starter/brick.yaml` and merge. After the verify
job passes on `main`, the `tag` job runs `scripts/tag_brick.dart --push`, which
creates `app_starter-v<version>` once. It never moves a tag; `--strict` exits 2
if the brick changed under an already-tagged version. `/tag-brick` still tags by
hand.
