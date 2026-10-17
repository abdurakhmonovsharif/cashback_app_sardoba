# Header + Search runtime baseline

Captured 2026-10-15, Asia/Tashkent. Scope: the existing Home Header and Search only. **No patch applied.**

## Corrections to V2 evidence

- Pro Max `01_top_true.png` shows **banner slide 2**, not slide 1.
- 17e `01_top_true.png` has a partially visible leading product; it does **not** establish horizontal `minScrollExtent`.
- 17e `02_current_section.png` and `04_products_horizontal_scrolled.png` are byte-identical: SHA-256 `7130a2d3e8e0686fd7179368123cfb6d0b03fe9ae807a6c27cb440a5466fbe69`.
- Pro Max `03_final_scroll.png` contains a mixed/transition banner frame; it is unsuitable for a stable banner comparison.
- V2's branch-title `w800` entry is incorrect for the current source/runtime: **w700**.
- The original reports, manifests and ZIP archives are preserved. These corrections supersede their conflicting claims.

## 1. Source/build correspondence — verified and bounded

| Identity | iPhone 17e | iPhone 17 Pro Max |
|---|---|---|
| Simulator UDID | F523F7C3-26D1-4BD2-BC42-8C0DD10AE938 | BBC87BEC-6475-4966-8DBA-FF81DD0A04A2 |
| Runtime | iOS 27.0 | iOS 26.4 |
| Existing app process PID | 42122 | 47925 |
| Bundle / version | com.sardoba.app / 1.0.0 (1) | com.sardoba.app / 1.0.0 (1) |
| Loaded app Dart sources vs working tree | **66/66 exact matches** | **66/66 exact matches** |
| Installed SF Pro Text font files vs working tree | Regular, Medium, Semibold, Bold: all exact matches | Same |

Source HEAD: `3c6dc2fde673246a0d659e3667a84ff31e686ada`, with pre-existing uncommitted changes. Toolchain: Flutter 3.44.4, framework `ad70ec4617`; Dart 3.12.2; DevTools 2.57.0. Both VMs report Dart 3.12.2.

**Method:** before attaching, queried each existing Dart VM using `getVM → getScripts → getObject`; compared each loaded `package:sardoba_app/` script's source with the corresponding local `lib/` file. No mismatches or unavailable sources among those 66. This includes current uncommitted Header/Search, theme, localization and responsive-wrapper source. `lib/screens/home/home_screen.dart` loaded/disk SHA-256 on both:
`dbbfeb770c7d465370921e2d541f0d4f74dace768fd1e2563cbcdeaf28269ad8`.

**Limit:** this establishes loaded Dart source correspondence, not a reproducible full native build. Native binaries, compile-time defines, unloaded Dart files and unrelated assets/configuration were not mapped to a build provenance record. Version 1.0.0 (1) is descriptive, not proof of source identity. The four installed font assets were separately byte-compared and match.

## 2. Flutter runtime measurements

Initially, VM expression evaluation returned `No compilation service available; cannot evaluate from source`. Attached to each already-running VM using `flutter attach -d <UDID> --debug-url=<existing VM URI> --no-dds`. Attachment supplied the expression compiler; Flutter reported its normal DevFS sync. **No rebuild, reinstall, hot reload, hot restart, source edit or configuration change was invoked.** Detached using `d`; both original app PIDs remain running.

Read-only debugger expressions traversed `WidgetsBinding.instance.rootElement`, reading `MediaQuery.of(element)`, the actual `Text/RichText` styles and scalers, `findRenderObject().size/constraints/localToGlobal(Offset.zero)`, and ancestor `ScrollPosition`. Expressions allocated temporary result strings; no widget state was set. The following are **RUNTIME VALUES**, sampled at **15:27:41 +05:00**, not PNG estimates.

### MediaQuery

Insets below are ordered **left, top, right, bottom**.

| Runtime field | 17e | Pro Max |
|---|---|---|
| `MediaQuery.size` at Header and Search | 390 × 844 | 440 × 956 |
| `devicePixelRatio` | 3.0 | 3.0 |
| Root `padding` / `viewPadding` | (0, 47, 0, 34), both | (0, 62, 0, 34), both |
| Header/Search `padding` / `viewPadding` | (0, 0, 0, 34), both | (0, 0, 0, 34), both |
| `viewInsets` | zero | zero |
| Effective scaler at Header/Search and text paragraphs | `SystemTextScaler (no scaling)` | Same |
| `scale(12), scale(16), scale(21)` | **12.0, 16.0, 21.0** | **12.0, 16.0, 21.0** |
| `boldText` | false | false |
| MediaQuery line-height / letter-spacing overrides | null / null | null / null |
| Vertical `pixels / minScrollExtent` | **0 / 0** | **0 / 0** |

The zero top inset at the component context is expected: Home's top `SafeArea` already consumes the root inset. Neither device has enlarged effective text scaling **in this measured session**. This does not retrospectively prove the scaler during earlier captures.

### Resolved text styles — identical on both devices

Read from the built `RichText.text.style`; font size is unscaled logical size, height is a multiplier, spacing is logical pixels.

| Text | Font family | Size | Weight | Letter spacing | Height | Origin of style |
|---|---|---:|---:|---:|---:|---|
| Branch eyebrow | SF Pro Text | 12 | 600 | 0.4 | 1.1 | bodySmall + local copyWith |
| Branch title | SF Pro Text | 21 | 700 | 0.15 | 1.1 | titleMedium + local copyWith |
| Search hint | SF Pro Text | 16 | 500 | 0.25 | 1.43 | bodyMedium + local copyWith |

All three `Text.textScaler` overrides are null; the resulting paragraphs use the inherited system scaler. Resolved styles have `inherit: false`. Letter spacing is inherited from theme styles, since these components do not specify it locally. Header icons use MaterialIcons: location 26, chevron 22, bell 24; Search icon 26. Their icon paragraphs use `TextScaler.noScaling`, as Flutter icons normally do.

Source locations:
- `lib/main.dart:83-85`: ThemeData / SF Pro Text.
- `lib/screens/home/home_screen.dart:328-337`: eyebrow; `:355-365`: title; `:514-522`: search hint.
- `lib/main.dart:123` and `lib/utils/responsive_layout.dart:25-46`: ResponsiveViewport; widths below 600 use the full width and zero wrapper side padding. It introduces no typography or text-scaler override.

### Rendered bounds at true top

**RUNTIME layout bounds**, in logical pixels as `(x, y, width, height)`, relative to Flutter's view origin. Text entries are paragraph layout boxes, not ink/glyph bounding boxes. Fractional widths below are rounded to 6 decimals for display.

| Component | 17e | Pro Max |
|---|---|---|
| Header | (16, 51, 358, 52) | (16, 66, 408, 52) |
| Eyebrow | (54, 55, 127.806252, 13) | (54, 70, 127.806252, 13) |
| Branch title | (54, 74.5, 194.728714, 23) | (54, 89.5, 194.728714, 23) |
| Notification button | (326, 53, 48, 48) | (376, 68, 48, 48) |
| Search surface | (16, 111, 358, 50) | (16, 126, 408, 50) |
| Search hint layout box | (73, 124.5, 283, 23) | (73, 139.5, 333, 23) |
| Search icon | (34, 123, 26, 26) | (34, 138, 26, 26) |

Runtime constraints: Header/Search max width 358/408, unbounded parent height; branch title/eyebrow max width 226/276, unbounded height; search text tight width 283/333 and max height 48. Header-to-Search gap is 8 on both. The 15dp global-y difference follows the measured root top insets (62 − 47), not a typography difference.

## 3. Scoped proposal — not applied

**Conclusion:** no Header/Search scaling mismatch or clipping was reproduced for the current Russian branch name. Their logical text sizes are equal on both devices. The visual heaviness is a local hierarchy observation: a 21sp bold branch title plus a 16sp medium search hint in a compact area. A modest local typography adjustment is now reviewable; it is not a fix for a proven scaler bug.

| Property / source | Before (verified) | Proposed after |
|---|---|---|
| Branch title, home_screen.dart:361-363 | 21sp, w700, spacing 0.15 inherited, height 1.1 | **20sp, w700, spacing 0 explicit, height 1.1** |
| Search hint, home_screen.dart:520-522 | 16sp, w500, spacing 0.25 inherited, height 1.43 | **15sp, w400, spacing 0 explicit, height 1.43 inherited** |

Retain eyebrow 12/w600, all colors, branding, icons, localization strings, one-line ellipsis behavior, branch/notification/search actions, 48×48 notification touch target, 50dp search touch surface, 16dp page inset and 8dp Header/Search gap. System accessibility scaling remains inherited. The header is currently governed by its icon row and padding; **no vertical-space saving is promised** by these typography changes. Do not touch global Theme/TextScaler or any other Home section.

Minimal **proposal only**, both hunks in `lib/screens/home/home_screen.dart`:

```diff
@@ branch-title style, lines 359–364
-                                        fontSize: 21,
+                                        fontSize: 20,
                                         fontWeight: FontWeight.w700,
+                                        letterSpacing: 0,
                                         height: 1.1,
@@ search-hint style, lines 518–522
-                    fontSize: 16,
-                    fontWeight: FontWeight.w500,
+                    fontSize: 15,
+                    fontWeight: FontWeight.w400,
+                    letterSpacing: 0,
```

After approval, verify these two components with both locales, a longer branch name and larger system text sizes; keep scaling enabled. Proposed rendering and accessibility at increased scales are **not yet validated**.

## Fresh screenshots and remaining limits

Both fresh PNGs were captured from the running simulators and inspected. Full Header and Search are visible; debugger measurements confirm vertical `pixels == minScrollExtent == 0`. Products remain horizontally scrolled and are outside this baseline.

| Artifact | Capture time (+05:00) | Actual state |
|---|---|---|
| [HEADER_SEARCH_17e_TOP.png](HEADER_SEARCH_17e_TOP.png) | 2026-10-15 15:27:17 | 1170×2532; ru; Sardoba Geofizika; guest; banner slide 2 |
| [HEADER_SEARCH_PRO_MAX_TOP.png](HEADER_SEARCH_PRO_MAX_TOP.png) | 2026-10-15 15:27:42 | 1320×2868; ru; Sardoba Geofizika; authenticated; banner slide 3 |

Authentication and banner state differ; neither was changed to produce this Header/Search baseline. No runtime measurement blocker remains for the requested Header/Search fields. Native build provenance and increased-scale/other-locale behavior remain unverified.

**Read-only verification:** SHA-256 inventories before/after matched all **359 checked files** across application source, native source/configuration, assets, tests, pubspec files and original audit artifacts. Generated Pods, symlinks and Flutter ephemeral directories were excluded. No app files changed. Only this Markdown baseline and the two fresh PNG audit artifacts were added; no tests/builds/formatters were run.

