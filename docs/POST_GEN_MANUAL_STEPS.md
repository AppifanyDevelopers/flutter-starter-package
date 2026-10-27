# What's NOT automated

`mason make app_starter` produces a runnable app, but these steps are
intentionally manual -- a name and a brand color can't automate them:

1. **Real backend integration.** Every feature's data access goes through a
   repository interface with a `Fake*` implementation. Find every place to
   change with `grep -rn "TODO(swap-backend)" lib/`, write a
   `Dio*Repository implements *Repository`, and swap that one binding line.
2. **Firebase (push notifications, Crashlytics, Analytics).** All three are
   already coded and wired via a shared `FirebaseBootstrap` and inert until
   configured -- `Firebase.initializeApp()` fails silently and all three
   become no-ops until you:
   - Create a Firebase project and Android/iOS apps in it matching this
     project's applicationId/bundleId per flavor (`{{application_id}}`,
     `{{application_id}}.staging` and `{{application_id}}.di`).
   - Download `google-services.json` into `android/app/` (the Google
     Services Gradle plugin only activates once this file exists).
   - Download `GoogleService-Info.plist`, add it to `ios/Runner/` **via
     Xcode** (drag into the Runner target so it's bundled as a resource --
     copying the file alone isn't enough).
   - As soon as those two files exist, Crashlytics and Analytics are live
     with no separate switch -- there's nothing further to turn on for
     them specifically.
   - For push notifications specifically, also: in Xcode, enable the
     **Push Notifications** capability and **Background Modes > Remote
     notifications** on the Runner target, and upload an APNs Auth Key to
     the Firebase project (Project Settings > Cloud Messaging). None of
     this is scriptable -- it requires an Apple Developer Program
     membership and is standard for any Flutter+FCM project, template or
     not.
   - Send pushes with a `data: {"route": "/settings/notifications"}`
     payload (matching a name in `AppRoutes`) to make tapping one navigate
     somewhere; omit it for a plain notification.
3. **Google and Apple Sign-In.** The code (`SocialAuthService`, the
   `SocialSignInButtons` on Login/Signup, placeholder `Info.plist` keys, the
   Apple Sign-In entitlement) is already in place but will actively error
   when tapped -- unlike the rest of this list, there's no way to fake a
   believable response, since control passes to the native provider SDK
   immediately. Before it can work:
   - **Google**: when generated with `scripts/create_app.dart`, the iOS
     `GIDClientID` and URL scheme in `ios/Runner/Info.plist` are filled in
     from your `GoogleService-Info.plist` automatically. Only if you
     generated with `mason make` directly, replace
     `REPLACE_WITH_CLIENT_ID` with its `CLIENT_ID` and
     `REPLACE_WITH_REVERSED_CLIENT_ID` with its full `REVERSED_CLIENT_ID`
     (it already starts with `com.googleusercontent.apps.`). For Android,
     register your debug and release keystores' SHA-1/SHA-256 fingerprints in
     the Firebase console -- a per-developer-machine credential that can't be
     generated.
   - **Apple**: enable the "Sign In with Apple" capability for this app's
     App ID in the Apple Developer Portal (requires a paid Developer
     Program membership) -- the `Runner.entitlements` file and Xcode-side
     wiring are already there, but the capability must still be turned on
     for your Team ID/App ID before it'll actually authorize.
   - **Branding**: the Google button uses a generic icon, not Google's
     trademarked "G" logo -- swap in an official branded asset
     ([Google's guidelines](https://developers.google.com/identity/branding-guidelines))
     before shipping, same tier as the placeholder app icon.
   - Apple Sign-In is intentionally iOS-only in this template -- see
     ARCHITECTURE.md for why extending it to Android needs a real backend.
4. **Real app icon / branding artwork.** The brick ships a generic
   flat-color placeholder (`assets/logo/icon.png`) so `flutter_launcher_icons`
   has something to process. Swap in the client's real logo and re-run
   `dart run flutter_launcher_icons`.
   - Note: the iOS `NSPhotoLibraryUsageDescription` string `image_picker`
     needs (for the signup/Edit Profile avatar picker) is already added to
     `Info.plist` for you -- nothing to do here for that.
5. **iOS code signing.** Team ID, provisioning profiles, and automatic
   signing per flavor scheme must be set in Xcode (or Fastlane match)
   before device builds/TestFlight archives work. Simulator and Android
   builds are unaffected.
6. **App Store Connect / Play Console** app records, bundle id
   registration, and listing metadata.
7. **Real API base URLs.** `.env.staging`/`.env.di`/`.env.production` are filled
   from the vars supplied at generation time -- update them once a real
   backend exists.
8. **Real store URLs for the update prompt.** `AppUpdateService` is called
   from `SplashController` with placeholder store URLs; the check silently
   no-ops until a real app is published.
9. **Signing credentials / keystores** (`key.properties`, `.jks`) must be
   generated and stored per-client outside git.
10. **Renaming an already-generated project later.** Use the
    `change_app_package_name` package manually for this one case -- it's
    deliberately not part of the automated `post_gen` pipeline (see
    ARCHITECTURE.md for why).
11. **Fastlane deploy lanes, and uploading debug symbols.** `android/fastlane/`
    and `ios/fastlane/` ship with `build_staging`/`build_production` lanes
    (run via `fastlane build_staging` from inside `android/` or `ios/`) that
    only build -- prerequisite: `gem install fastlane` or a `Gemfile` +
    `bundle install`. The release-mode lanes (iOS's `build_staging` and
    `build_production`, Android's `build_production`) pass `--obfuscate
    --split-debug-info=build/debug-info/<platform>-<flavor>`; once
    Crashlytics is configured (item 2 above), upload that folder
    (`firebase crashlytics:symbols:upload --app=<app-id> build/debug-info/<platform>-<flavor>`)
    after every release build, or crashes from these builds can't be
    de-obfuscated back into readable stack traces. Uploading to
    TestFlight/Play internal testing needs more:
    - **Android**: a Play Console service account JSON, referenced from
      `android/fastlane/Appfile` (`json_key_file(...)`), then a
      `lane :beta do upload_to_play_store(...) end` using `supply`.
    - **iOS**: an App Store Connect API key (or Apple ID + app-specific
      password), an `apple_id`/`team_id` in `ios/fastlane/Appfile`, real
      code signing (item 5 above) since `build_staging`/`build_production`
      currently pass `--no-codesign`, and a `lane :beta do upload_to_testflight(...)
      end` using `pilot`.
    Neither is scaffolded by default -- both need credentials that can't be
    generated, the same reasoning as the rest of this list.
12. **CI/CD** for whatever pipeline the team adopts to build/ship the
    generated app (the Fastlane lanes above are a natural fit to call from
    one, but aren't a CI pipeline by themselves).
