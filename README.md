# Sardoba

Sardoba is a Flutter mobile app for restaurant customers. It lets customers browse the restaurant catalog, find locations, track loyalty points and transaction history, and use QR-based loyalty features.

[![App Store](https://img.shields.io/badge/App%20Store-iOS-111111?logo=apple)](https://apps.apple.com/uz/app/sardoba/id6757268380)
[![Google Play](https://img.shields.io/badge/Google%20Play-Android-414141?logo=googleplay)](https://play.google.com/store/apps/details?id=com.sardobabukhara.app&hl=en)

## Features

- Browse, search, and filter the restaurant and product catalog.
- Find restaurant locations and view them on a map.
- Sign in with a phone number and SMS verification code.
- Use QR-based loyalty features.
- View points balance, loyalty level, and transaction history.
- Receive news and notifications.
- Manage profile details, PIN, saved locations, and notification preferences.
- Use the app in Uzbek or Russian.

## Tech stack

- Flutter and Dart 3 (the `pubspec.yaml` SDK constraint is `>=3.5.0 <4.0.0`).
- Dio for REST API requests and WebSocket for real-time notifications.
- Yandex MapKit for restaurant locations.
- `shared_preferences` for local preferences and session data.
- Flutter Local Notifications, `image_picker`, `url_launcher`, and `cached_network_image`.

## Getting started

### Requirements

- Flutter SDK (which includes the Dart SDK).
- Android Studio and Android SDK for Android builds.
- macOS and Xcode for iOS builds.
- Access to an API server. A platform-specific Yandex MapKit API key is also needed to display maps on Android and iOS.

### Install packages

From the repository root, run:

```bash
flutter pub get
```

### Run the app

If `API_BASE_URL` is not set, the app uses `https://api.sardobacashback.uz`. To use another server, such as a local or staging environment, pass its URL with `--dart-define`:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com
```

Replace `https://api.example.com` with a reachable API URL. On an emulator, `localhost` refers to the emulator itself; use an address that can reach the server running on your computer.

### Configure Yandex MapKit

Set a Yandex MapKit API key for each native platform:

- Android: the `yandex_mapkit_api_key` value in `android/app/src/main/res/values/strings.xml`.
- iOS: the `configureYandexMapKit()` configuration in `ios/Runner/AppDelegate.swift`.

Obtain platform-appropriate keys from your Yandex Developer account. Review your project and Yandex account restrictions before committing keys to a public repository. `YANDEX_MAPKIT_API_KEY` changes the Dart `AppConfig` value; it does not replace the native Android or iOS SDK keys.

## Build

### Android APK

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com
```

### Android App Bundle

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.com
```

For Google Play releases, configure Android release signing with `android/key.properties` and a release keystore. Do not commit signing files or credentials to Git.

### iOS

```bash
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.example.com
```

For an App Store build, configure the signing team and provisioning settings in Xcode.

## Checks

```bash
flutter analyze
flutter test
```

Widget and unit tests are located in the `test/` directory.

## Project structure

```text
lib/
├── components/    # Reusable UI components
├── config/        # API and app configuration
├── models/        # API and screen data models
├── navigation/    # Navigation and the main screen container
├── screens/       # App screens
├── services/      # API, session, catalog, points, and notification services
├── app_language.dart
├── app_localizations.dart
└── main.dart

assets/            # Images, icons, fonts, and branding
android/           # Android native configuration
ios/               # iOS native configuration
test/              # Flutter tests
```

## API integration

Authentication, catalog, locations, points, and news are handled by services in `lib/services/`. Notifications use a WebSocket for signed-in users, and notification history is also available in the app. The API base URL is read from `lib/config/app_config.dart`.

API endpoints and payloads evolve alongside the backend. Refer to the backend project's OpenAPI documentation for the current API contract.

## App version

- The app version is managed by the `version` field in `pubspec.yaml`. The current value is `2.0.0+3`.
- Use `--build-name` and `--build-number` to override the version and build number at build time.

## License

This repository does not include a license file. Contact the project owner to confirm the terms for using or distributing the code.
