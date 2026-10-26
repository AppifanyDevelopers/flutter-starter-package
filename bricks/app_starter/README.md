# app_starter

A Mason brick that generates a fully functional Flutter app: Login (with
Remember me), Signup, Forgot Password, a Dashboard, and a Settings screen
(Appearance/dark mode, FAQ, Contact Us, Terms & Conditions, Privacy Policy,
Notification Settings, Change Password, Edit Profile, Delete Account,
Logout, app version) -- wired with GetX, staging/production flavors, `.env`
config, an in-app update prompt, and Firebase push notifications with
tap-to-navigate (inert until a real Firebase project is added -- see
`docs/POST_GEN_MANUAL_STEPS.md`). All other data comes from an in-memory
fake backend by default, so the generated app runs immediately with no
server setup.

See the repo root [README.md](../../README.md) for the full usage guide.

## Vars

| Var | Description | Default |
|---|---|---|
| `project_name` | Dart package name, lower_snake_case | `my_starter_app` |
| `app_name` | Human-readable display name | `My Starter App` |
| `application_id` | Exact Android applicationId / iOS bundleId for production, used as typed (staging adds `.staging`; the project name is not appended) | `com.example.myapp` |
| `seed_color` | Hex brand color, drives `ColorScheme.fromSeed` | `#6750A4` |
| `description` | pubspec.yaml description | `A Flutter app generated from app_starter.` |
| `api_base_url_staging` | Staging API base URL, including the `/api` prefix | `https://staging-api.example.com/api` |
| `api_base_url_production` | Production API base URL, including the `/api` prefix | `https://api.example.com/api` |
| `ios_app_store_url` | App Store link opened by the update dialog (required var when scripting `mason make`; the placeholder id works until the app exists) | `https://apps.apple.com/app/id0000000000` |

## Generate

```bash
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

`post_gen` runs `flutter create` (native android/ios folders), `flutter_flavorizr`
(staging/production flavors), and `flutter_launcher_icons` (app icon) for you.
