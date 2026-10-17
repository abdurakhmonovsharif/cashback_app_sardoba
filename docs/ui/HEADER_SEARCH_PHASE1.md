# Header + Search — Phase 1

**Status: FIXED**  
**Date:** 2026-10-15 (Asia/Tashkent)  
**Scope:** Home Header + Search only. No Banner, Bonus, Products, Categories, Bottom Navigation, API, or business-logic changes.

## Findings

- The requested default typography was already present in `lib/screens/home/home_screen.dart`: branch label **12 / w400 / nominal line height 15** (`:331-342`); branch name **17 / w600 / nominal line height 22** (`:360-374`); Search hint **15 / w400** (`:522-531`). Flutter `TextStyle.height` uses a multiplier, so the source expresses these line heights as `15 / 12` and `22 / 17`.
- Search was already the existing tap-to-open launcher, with a 50dp minimum height, 20dp icon, 16dp side insets, 8dp icon gap, 12dp radius, white fill and app border (`:498-535`). It remains non-editable. Actual query entry remains on `SearchScreen`; the launcher hint stays one line and ellipsizes. The current source has **no search box shadow**.
- The branch label and title were both forced to one line at all text sizes (`:331-336`, `:360-374`). That prevented natural Header growth with larger system text. This was the confirmed defect.
- Font family is inherited as **SF Pro Text** (`lib/main.dart:83-86`). Header and Search do not override `TextScaler`; no width- or pixel-ratio-based font scaling or ScreenUtil use was found in this scope. `ResponsiveViewport` constrains content width and gutters (`lib/utils/responsive_layout.dart:23-46`); `AppNavBarViewport` changes only the `MediaQuery.size` (`lib/navigation/app_nav_bar_layout.dart:16-23`), preserving the scaler. No shared/root typography defect was found.

## Change

Only the branch label and name line behavior changed in production. They use the inherited `MediaQuery.textScaler`: at default size they retain one-line ellipsis; once their effective text size is scaled, wrapping is enabled so the Header can grow naturally. No `TextScaler` override, scale cap, font-size multiplier, fixed-height text container, composition change, or notification/search interaction change was added. The full branch name remains in the Text semantics label and is visible in the existing branch picker.

Search and all requested default typography values remain unchanged. Search remains a launcher, preserving the existing focus/keyboard behavior of the actual Search screen.

## Validation

| Command / check | Result |
|---|---|
| `dart format lib/screens/home/home_screen.dart test/header_search_phase1_test.dart` | PASS; no formatting-only source changes |
| `flutter analyze` | PASS; no issues found |
| `flutter test test/header_search_phase1_test.dart --reporter expanded` | PASS: **38 tests** — RU/UZ × 320, 360, 390, 440, 600, 840dp × text scale 1.0, 1.3, 2.0, plus branch/notification/search action flows. Covers long branch names, full semantic label, title wrapping at scaled sizes, long Search-screen queries, hit areas, alignment and no layout exceptions. |
| `flutter test test/catalog_category_navigation_test.dart test/auth_protected_entry_points_test.dart --reporter expanded` | **34 passed, 1 failed.** Existing lower-Home assertion `first dish name and price clear the nav at 375x812` expected the price bottom `<675.0`, got `722.625` (`test/catalog_category_navigation_test.dart:244`). This concerns lower product/nav coordinates, outside this Header/Search scope; no lower components were changed. Test logs also contain notification WebSocket timeout and registration HTTP 400 warnings. |
| `git diff --check` | PASS |

The focused matrix uses linear `TextScaler` values; it does not reproduce every nonlinear native Dynamic Type curve. The simulator's numeric OS text-size preference was not exposed by the inspected preference key, so native large-text state is **UNKNOWN**. No simulator accessibility setting was changed.

## Native screenshots

All full screenshots were captured directly with `xcrun simctl io … screenshot` and inspected. Detail crops in the ZIP are crops of those PNGs. Screenshot archive contains PNGs only.

| Capture | Device / OS | Logical viewport / native image | Locale, branch and auth state | Banner | Time (+05:00) |
|---|---|---|---|---|---|
| Before | iPhone 17e / iOS 27.0 | 390×844dp / 1170×2532px | RU, Sardoba Geofizika, guest | Slide 3 | 2026-10-15 17:45:54 |
| After | iPhone 17e / iOS 27.0 | 390×844dp / 1170×2532px | RU, Sardoba Geofizika, guest | Slide 3, briefly paused for capture | 2026-10-15 17:56:48 |
| Baseline | iPhone 17 Pro Max / iOS 26.4 | 440×956dp / 1320×2868px | RU, Sardoba Geofizika, authenticated | Slide 1 | 2026-10-15 17:45:55 |

The iPhone 17e app was attached to its existing debug VM and hot reloaded after the change (**1 of 1809 libraries**); the captured Home state and Header/Search detail crop were visually inspected. Autoplay was restored after capture. The Pro Max app was running and its baseline was captured, but Flutter could not discover a VM service for that process; a post-change hot reload on Pro Max is **NOT RUN**. No Android device appeared in `flutter devices`, and `adb` was unavailable on PATH; Android verification is **NOT RUN**.

## Files and preservation

- Production: `lib/screens/home/home_screen.dart` — scaled Header reflow only.
- Test: `test/header_search_phase1_test.dart` — focused responsive, scaling, semantics and interaction coverage.
- Report: `docs/ui/HEADER_SEARCH_PHASE1.md`.
- Screenshots: `HEADER_SEARCH_PHASE1_SCREENSHOTS.zip`.

The working tree was already dirty with extensive unrelated user WIP and audit artifacts. Those changes were preserved; no reset, commit, push, dependency install, simulator-runtime install, deployment, or unrelated product edit was performed.
