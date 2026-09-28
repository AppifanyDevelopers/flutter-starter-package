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
| `org` | Reverse-DNS org id (Android applicationId / iOS bundleId) | `com.example` |
| `seed_color` | Hex brand color, drives `ColorScheme.fromSeed` | `#6750A4` |
| `description` | pubspec.yaml description | `A Flutter app generated from app_starter.` |
| `api_base_url_staging` | Staging API base URL (used once a real backend exists) | `https://staging-api.example.com/api/v1` |
| `api_base_url_production` | Production API base URL (used once a real backend exists) | `https://api.example.com/api/v1` |

## Generate

```bash
cat > vars.json <<'EOF'
{
  "project_name": "acme_rentals",
  "app_name": "Acme Rentals",
  "org": "com.acme",
  "seed_color": "#1E88E5",
  "api_base_url_staging": "https://staging-api.acme.com/api/v1",
  "api_base_url_production": "https://api.acme.com/api/v1",
  "description": "Acme Rentals customer app"
}
EOF
mason make app_starter -o . -c vars.json
```

`post_gen` runs `flutter create` (native android/ios folders), `flutter_flavorizr`
(staging/production flavors), and `flutter_launcher_icons` (app icon) for you.
