# Header + Search typography fix

2026-10-15, Asia/Tashkent. Baseline: `HEADER_SEARCH_BASELINE.md`.

## Changed

Only `lib/screens/home/home_screen.dart` changed in the application:
- Branch-title style at lines 359–364: 20sp, w700, explicit letterSpacing 0, height 1.1.
- Search-hint style at lines 519–524: 15sp, w400, explicit letterSpacing 0. No local height was added; runtime confirms inherited height **1.43**.

SF Pro Text, eyebrow, colors, icons, shapes, spacing, touch surfaces, overflow behavior, actions and inherited accessibility scaling remain intact. No global theme, MediaQuery, TextScaler, other Home component, dependency or app configuration was edited. No account/backend changes were performed.

This patch adjusts local visual emphasis. Header height remains 52dp and Search remains 50dp; it does not save vertical space or resolve other Home issues.

## Exact task diff

Diff against the working-tree file captured immediately before this task, including its existing uncommitted changes:

```diff
--- a/lib/screens/home/home_screen.dart (working tree before this task)
+++ b/lib/screens/home/home_screen.dart
@@ -358,8 +358,9 @@
                                       style:
                                           theme.textTheme.titleMedium?.copyWith(
                                         color: _kHomeTextPrimary,
-                                        fontSize: 21,
+                                        fontSize: 20,
                                         fontWeight: FontWeight.w700,
+                                        letterSpacing: 0,
                                         height: 1.1,
                                       ),
                                       overflow: TextOverflow.ellipsis,
@@ -517,8 +518,9 @@
                   overflow: TextOverflow.ellipsis,
                   style: theme.textTheme.bodyMedium?.copyWith(
                     color: _kHomeTextSecondary,
-                    fontSize: 16,
-                    fontWeight: FontWeight.w500,
+                    fontSize: 15,
+                    fontWeight: FontWeight.w400,
+                    letterSpacing: 0,
                   ),
                 ),
               ),
```

Source SHA-256:
- Before: `dbbfeb770c7d465370921e2d541f0d4f74dace768fd1e2563cbcdeaf28269ad8`
- After: `219f9ec236f653c274f6d13a051cbf732562787633616d63696383980974521e`

The complete resulting source equals the pre-task snapshot plus exactly these edits. Hashes of 363 pre-existing files were checked across source/native source/configuration/assets/tests/pubspec and audit artifacts: **only this one source file changed**. Existing dirty-worktree changes and original audit artifacts were preserved. No unrelated formatting was performed.

## Runtime verification on both simulators

Attached to the existing debug VMs and hot-reloaded with `r`, without reinstall/restart:
- iPhone 17e, iOS 27.0, UDID `F523F7C3-26D1-4BD2-BC42-8C0DD10AE938`, PID 42122: **1 of 1809 libraries reloaded**, 538ms.
- iPhone 17 Pro Max, iOS 26.4, UDID `BBC87BEC-6475-4966-8DBA-FF81DD0A04A2`, PID 47925: **1 of 1809 libraries reloaded**, 439ms.

Toolchain: Flutter 3.44.4 / Dart 3.12.2. Source HEAD remains `3c6dc2fde673246a0d659e3667a84ff31e686ada` plus uncommitted work. After hot reload, all **66/66 loaded app Dart sources** matched the current working tree on each VM.

Measurements were read through VM debugger expressions traversing the mounted Element tree, inspecting resolved `RichText.text.style`, inherited `MediaQuery`, `ScrollPosition` and RenderBox bounds. They are runtime values, not screenshot-derived estimates. Before samples: **15:39:42 +05:00**; after samples: **15:40:23 +05:00**.

### Resolved text styles

Identical on both devices; font family SF Pro Text:

| Text | Before | After |
|---|---|---|
| Branch title: size / weight / spacing / height | 21 / 700 / 0.15 / 1.1 | **20 / 700 / 0 / 1.1** |
| Search hint: size / weight / spacing / height | 16 / 500 / 0.25 / 1.43 | **15 / 400 / 0 / 1.43** |
| Eyebrow: size / weight / spacing / height | 12 / 600 / 0.4 / 1.1 | **unchanged** |
| Text component scaler override | null | **null** |
| Effective inherited scaler | SystemTextScaler (no scaling) | **unchanged** |
| scale(12), scale(16), scale(21) | 12, 16, 21 | **unchanged** |

### Rendered bounds

Logical `(x, y, width, height)`; text bounds are paragraph layout boxes. Bounds apply at confirmed vertical `pixels = minScrollExtent = 0`.

| Component | 17e before → after | Pro Max before → after |
|---|---|---|
| Header | (16, 51, 358, 52) → unchanged | (16, 66, 408, 52) → unchanged |
| Notification touch surface | (326, 53, 48, 48) → unchanged | (376, 68, 48, 48) → unchanged |
| Search touch surface | (16, 111, 358, 50) → unchanged | (16, 126, 408, 50) → unchanged |
| Branch title | (54, 74.5, 194.728714, 23) → (54, 75, 183.027344, 22) | (54, 89.5, 194.728714, 23) → (54, 90, 183.027344, 22) |
| Search hint | (73, 124.5, 283, 23) → (73, 125.5, 283, 21) | (73, 139.5, 333, 23) → (73, 140.5, 333, 21) |

Viewports/DPR remain 390×844/3 and 440×956/3. Root top safe insets remain 47/62dp; bottom remains 34dp. Page inset remains 16dp and Header/Search gap 8dp.

For the current RU branch and hint, both paragraphs report `didExceedMaxLines == false` on both simulators. Native screenshots were inspected and show no Header/Search clipping. The existing notification target remains 48×48; search remains 50dp high.

## Validation

- **flutter analyze:** passed, no issues.
- **Existing relevant tests:** `flutter test test/catalog_category_navigation_test.dart test/auth_protected_entry_points_test.dart --reporter expanded` — **35 passed**. Includes Home widths 320/360/375/390/430, 2.0-scale cases, navigation and landscape coverage already present.
- **Focused isolated widget matrix:** **36 passed**. RU/UZ × 320/390/440dp × 1.0/1.5/2.0 text scales × normal/long branch-name fixture. Tested the actual Home widgets with SF Pro Text loaded, expected resolved styles, no local scaler override, inherited scale values, one-line ellipsis, 48×48 notification target, 50dp search, 16dp inset and 8dp gap, with no framework exceptions. Fixtures and scaling were confined to a temporary test process.
- Temporary harness: `/tmp/sardoba-header-fix.v3pKD9/header_search_test.dart`; no production testing hooks or fixture data were added. Run command: `flutter test /tmp/sardoba-header-fix.v3pKD9/header_search_test.dart --reporter expanded`.
- **Simulator actions on both devices:** branch picker opened/dismissed without selecting another branch; Search opened/back worked; Notifications opened/back worked. No messages were tapped or marked read. Pro Max displayed its authenticated notification list; 17e displayed the existing guest login gate. No login or account changes were made.
- **Framework errors:** hot-reload/attach output had no new framework/overflow errors; simulator logs during the verification interval had no RenderFlex, EXCEPTION CAUGHT or Unhandled Exception entries. `git diff --check -- lib/screens/home/home_screen.dart` passed.
- Debug attachments were detached using `d` after validation, leaving both original app processes running.

Existing-test warnings: the test environment emitted notification WebSocket timeout and notification-registration HTTP 400 warnings. They did not fail assertions and were not addressed by this typography patch. Notification delivery, read marking and authentication were not tested as new backend operations.

## Fresh screenshot archive

`HEADER_SEARCH_FIX_SCREENSHOTS.zip` contains only two fresh native PNG captures plus `MANIFEST.md`:

| Archive path | Native pixel size | Capture time (+05:00) | State |
|---|---|---|---|
| iPhone_17e/01_header_search_after_true_top.png | **1170×2532** | **2026-10-15 15:42:46** | RU, Sardoba Geofizika, guest, true vertical top, slide 2 |
| iPhone_17_Pro_Max/01_header_search_after_true_top.png | **1320×2868** | **2026-10-15 15:41:55** | RU, Sardoba Geofizika, authenticated, true vertical top, slide 3 |

Produced by `xcrun simctl io <UDID> screenshot` directly into PNG files; no crop/resize/re-encoding was applied. The carousel's existing pause control was temporarily used to stabilize each frame and restored to autoplay afterwards. Authentication differences and existing product horizontal positions remain visible; this is a Header/Search validation, not a matched full-Home comparison.

## Remaining limitations

- Native simulator checks used current default text settings and RU. UZ/long-name/larger-text coverage was in isolated widget tests, not by changing simulator settings or real branch data.
- Scaling beyond 2.0, native nonlinear accessibility scaling, physical devices, VoiceOver and dark mode were not verified. Existing one-line ellipsis intentionally persists for long names or large text.
- Full native build provenance and unrelated Home components were not re-audited. Only the specified Header/Search source patch was applied.

