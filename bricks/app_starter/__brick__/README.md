# {{{app_name}}}

Generated from the `app_starter` Mason brick. Fully functional out of the
box against an in-memory fake backend -- no server required.

## Run

```bash
flutter pub get
flutter run --flavor staging -t lib/main.dart --dart-define=FLAVOR=staging
```

Demo login: `demo@example.com` / `password123`.

## Swap in a real backend

Every feature's data access goes through a repository interface with a
`Fake*` implementation wired in its `Bindings` class, e.g.:

```dart
// lib/features/auth/presentation/bindings/auth_bindings.dart
Get.lazyPut<AuthRepository>(() => FakeAuthRepository()); // TODO(swap-backend)
```

Find every place to change with:

```bash
grep -rn "TODO(swap-backend)" lib/
```

Write a `Dio*Repository implements *Repository` for the feature and swap
that one line -- no controller or screen changes required.

## What's not set up yet

See `docs/POST_GEN_MANUAL_STEPS.md` in the `flutter_starter_pack` template
repo: real backend integration, Firebase, real app icon artwork, iOS code
signing, store listings, and real `.env` API URLs.
