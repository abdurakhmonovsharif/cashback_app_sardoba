# Sardoba Restaurant App UI Kit

Sardoba is a Flutter UI starter for restaurant brands who want to launch a
branch-based mobile experience fast. The kit ships with branch catalogs, menu
exploration per location, dynamic promotions, and a cashback rewards flow that
keeps diners engaged without having to build the core UX from scratch.

## Highlights
- Branch directory with location details powered by Yandex MapKit
- Menu layouts scoped per branch, including rich imagery and pricing states
- Cashback wallet module for earning, tracking, and redeeming rewards
- Campaign banners and promo callouts that surface timely offers
- Skeleton loading states, light/dark theming, and localization scaffolding
- Fully responsive Flutter UI components for Android and iOS

## Tech Stack
- Flutter 3.5+ and Dart 3
- `flutter_svg` for vector assets and iconography
- `shared_preferences` for local caching and session state
- `yandex_mapkit` for map views and branch positioning
- `form_field_validator`, `crypto`, `url_launcher`, and `.env` driven configs

## Project Structure
- `lib/screens` – page layouts such as branch lists, menus, auth, and loyalty
- `lib/components` – reusable widgets (cards, headers, progress indicators)
- `lib/models` – data models for branches, menu items, and loyalty balances
- `lib/services` – integrations and helpers (API, storage, localization)
- `assets/` – illustrations, icons, and branding resources bundled in the app

## Getting Started
1. Install Flutter 3.5 or newer and the associated platform toolchains.
2. Clone the repository and fetch packages:
   ```bash
   flutter pub get
   ```
3. Copy `.env.example` to `.env` and set your own values for the API endpoint
   and Yandex MapKit key. These values are now consumed by both Flutter and the
   native Android/iOS launchers.
4. Launch the app:
   ```bash
   flutter run
   ```

### Environment reference

| Key | Description |
| --- | --- |
| `API_BASE_URL` | Base URL for all REST services (Auth, Catalog, Cashback, etc). |
| `YANDEX_MAPKIT_API_KEY` | Native Yandex MapKit SDK key used by both Android and iOS bootstrap code. |

Run `flutter test` to execute widget or unit tests located in the `test/`
directory.

## WebSocket-driven notifications

The app now relies on a WebSocket+local-notification stack (see
`lib/services/notification_socket_service.dart`). The flow works as follows:

1. **Register the device** – After OTP verification, the client calls
   `POST /api/v1/notifications/register-token` with `deviceType` (`android` or
   `ios`), `deviceToken: null`, the current language (`AppLanguage`), and
   `usesWebSocket: true` so the backend remembers that this device expects real-
   time pushes instead of FCM.
2. **Open the WebSocket** – The same moment the device registers, the manager
   connects to `wss://<your-api>/api/v1/notifications/ws` (constructed from
   `API_BASE_URL`) and sends the `Authorization: Bearer <access_token>` header.
   Successful connections trigger the server to replay any missed notifications.
3. **Show real-time alerts** – Incoming JSON blobs must include
   `notification_id`, `title`, and `description` (optional `created_at`). They
   are turned into `AppNotification` instances, streamed for UI listeners, and
   displayed as banners via `PushNotificationManager.instance.showNotification`.
4. **Reconnect automatically** – If the socket drops, the manager retries with
   exponential backoff (2s, 4s, 8s, …) capped at 60s. Each successful
   reconnection asks the server to resend unsent events.
5. **Logout cleanup** – When the user logs out (`AppNavigator.forceLogout` or
   manual session reset), the socket closes and reconnect attempts stop until the
   next login.
6. **Fetch historic notifications** – The existing
   `NotificationService.fetchNotifications()` (`GET /api/v1/notifications/me`)
   still provides the history that powers the “Bell” screen (`lib/screens/notifications/notifications_screen.dart`).

## Cashback & loyalty data

The app now relies on the refreshed `/api/v1/cashback/user/{user_id}` payload
that includes both `loyalty` summary information and the `transactions`
history needed to render the cashback cards, balances, and level progress
indicators. The response looks like this:

```json
{
  "loyalty": {
    "level": "Gold",
    "cashback_balance": 2700,
    "points_total": 4200,
    "current_level_points": 1300,
    "current_level_min_points": 1000,
    "current_level_max_points": 2000,
    "next_level": "Platinum",
    "next_level_required_points": 2000,
    "points_to_next_level": 700,
    "is_max_level": false,
    "cashback_percent": 5,
    "next_level_cashback_percent": 7
  },
  "transactions": [
    {
      "id": 1,
      "user_id": 123,
      "amount": 12000,
      "balance_after": 1200,
      "created_at": "2024-09-12T12:34:56Z",
      "branch_id": 139235,
      "source": "ORDER",
      "staff_id": null
    }
  ]
}
```

`CashbackService.fetchUserCashback` now returns that structure
(see `lib/models/cashback_history.dart`), so the UI cards stay in sync with the
backend-provided `cashback_balance`, `current_level_points`, `points_to_next`,
and other level-related stats. If the backend needs to redeem points, call
`POST /api/v1/cashback/use` with `user_id`/`amount`. These endpoints and the
schema are captured in the latest `openapi.json`.

## Customization Tips
- Update the color system and typography in `lib/theme.dart` to match branding.
- Seed demo content and loyalty scenarios via `lib/demo_data.dart`.
- Extend localization strings in `lib/app_localizations.dart` and regenerate
  translations as needed.

## Screenshots
Add your own mockups or device captures to the `assets/branding/` directory and
reference them here once available.

## License
Provide license details or usage terms here if you are distributing the kit
beyond internal teams.
# sardoba_cashback
