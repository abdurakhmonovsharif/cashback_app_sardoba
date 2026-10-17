# Sardoba Home UI audit v2 (read-only evidence correction)

**Date:** 2026-10-15, Asia/Tashkent  
**Scope:** controlled evidence recheck of the existing Flutter Home screen on iPhone 17e and iPhone 17 Pro Max simulators.  
**Change policy:** no application source, configuration, assets, backend, simulator settings, or business logic were modified. The original `HOME_UI_AUDIT.md` and `HOME_SCREENSHOTS.zip` are preserved.

## What changed from v1

- The earlier Pro Max `top_home.png` was not a true top capture. It was vertically scrolled, with the header absent and search partially clipped. v2 replaces this with a fresh true-top capture.
- The earlier Pro Max pair had effectively the same vertical content position; v2 captures a true top, a final vertical extent, and a deliberate horizontal product-list drag.
- v2 does not use visual text size as proof of a different `TextScaler`. Native-pixel text bounds can match while logical viewports, state, font rendering, or screenshot crops differ.
- The partial left product is treated as scroll-state evidence, not a confirmed layout defect. It is captured deliberately at both min/initial and horizontally scrolled states.
- Guest/authenticated state and banner-slide differences are explicit in the manifest; they are not normalized by guessing or by mutating account/backend state.

## Build and device identity

| Item | Recorded value |
|---|---|
| Source revision | `3c6dc2fde673246a0d659e3667a84ff31e686ada` |
| Repository state | Dirty before audit; many pre-existing user WIP changes. No source files changed during v2. |
| Flutter | 3.44.4 stable |
| Dart | 3.12.2 |
| DevTools | 2.57.0 |
| App package | `com.sardoba.app` |
| App version/build on both simulators | `1.0.0 (1)` from `simctl listapps` |
| iPhone 17e | UDID `F523F7C3-26D1-4BD2-BC42-8C0DD10AE938`, iOS 27.0 |
| iPhone 17 Pro Max | UDID `BBC87BEC-6475-4966-8DBA-FF81DD0A04A2`, iOS 26.4 |

Physical display values came from `simctl getenv`: 17e 1170×2532 px at scale 3; Pro Max 1320×2868 px at scale 3. Derived logical viewports are 390×844dp and 440×956dp. The logical values are derived, not read from Flutter runtime.

## Accessibility settings evidence

Before captures, the simulator accessibility preference output was read without changing settings.

- Both devices: `AccessibilityEnabled=1`, `ApplicationAccessibilityEnabled=1`, `GrayscaleDisplay=0`, `InvertColorsEnabled=0`, `ReduceMotionEnabled=0`.
- The simulator defaults did not expose a Dynamic Type/text-size preference or numeric text scale. Therefore effective Flutter `TextScaler` remains **UNKNOWN**.
- No PNG, native-pixel text bounds, or apparent visual size is used as proof of a non-default scale.

## Controlled screenshot coverage

The full manifest is in `HOME_SCREENSHOTS_V2_MANIFEST.md` and is included inside `HOME_SCREENSHOTS_v2.zip`.

### iPhone 17e

- `01_top_true.png`: full header, search, banner, loyalty and first product row at vertical min extent; guest state; slide 1.
- `02_current_section.png`: loyalty/products/categories region.
- `03_final_scroll.png`: final reachable vertical content with categories and floating nav.
- `04_products_horizontal_scrolled.png`: deliberate horizontal product-list drag; partial left product is expected scroll state, not classified as a defect.

### iPhone 17 Pro Max

- `01_top_true.png`: full header, search, banner, loyalty and first product row at vertical min extent; authenticated state; slide 1.
- `03_final_scroll.png`: final reachable vertical content with categories and floating nav.
- `04_products_horizontal_scrolled.png`: deliberate horizontal product-list drag; slide 3 was active because autoplay was independent.

The states cannot be perfectly matched safely: 17e is guest (`—`, “Авторизуйтесь…”), Pro Max is authenticated (`10 642,5 балл`), and banner autoplay advanced independently. No account or backend mutation was performed.

## Runtime measurement status

The requested exact Flutter runtime values were not available from the existing debug session or Device Hub accessibility tree. No diagnostic code was inserted, and no source file was modified.

| Measurement | Status | Evidence / blocker |
|---|---|---|
| `physicalSize` | Known at simulator display level | `simctl`: 1170×2532 and 1320×2868 px |
| `MediaQuery.size` | Derived, not runtime-read | 390×844 and 440×956 from px ÷ scale |
| `devicePixelRatio` | Known | `simctl`: 3.0 for both |
| `padding`, `viewPadding`, `viewInsets` | Unknown numeric runtime values | Source confirms `SafeArea` and nav safe-bottom handling, but Flutter inspector was not attached |
| Effective `TextScaler` | Unknown | Simulator defaults do not expose Dynamic Type value; PNG evidence is insufficient |
| `scale(12/14/16/18/21/28)` | Unknown runtime values | No inspector/debugger readout available |
| Component rendered bounds | Screenshot-observable only | No Flutter render-tree inspector session attached |
| Vertical scroll offset/extents | Numeric values unknown | Device Hub drag reproduced min/intermediate/final states but did not expose ScrollPosition |
| Horizontal product scroll offset/extents | Numeric values unknown | Deliberate drag verified state change through AX product sequence; no numeric ScrollPosition |

### Exact capture path for the missing runtime values

Attach Flutter DevTools/Inspector to the already running debug session, select the Home `SingleChildScrollView` and product `ListView`, and read `MediaQueryData`, `MediaQuery.textScaler`, render boxes, and `ScrollPosition.pixels/maxScrollExtent`. If no debug session is available, a future audit needs a debug-only inspector hook or DevTools session; it must not be added to production source merely for this report.

## Source styling inventory (confirmed source values)

The following are source values, not runtime measurements.

### Shell, spacing, and page constraints

- `lib/screens/home/home_screen.dart:127-180`: `SafeArea(top: true, bottom: false)`; `RefreshIndicator`; bouncing always-scrollable `SingleChildScrollView`.
- `home_screen.dart:137`: `EdgeInsets.fromLTRB(16, 4, 16, navAwareBottomPadding(context, extra: 16))`.
- `lib/constants.dart:30-33`: related gap 8dp; section gap 12dp.
- `lib/constants.dart:21-28`: control/card radius 16dp; panel radius 24dp; border `#E2E8E4`; primary green `#0B5E3C`; title `#010F07`; body `#4B5563`.
- `lib/constants.dart:35-38`: shared `appCardShadow` is black/green alpha `0.06`, blur 14, offset y 4.

### Header and search

- `home_screen.dart:312-368`: branch row uses 48×48dp action, 26dp location icon, 12sp/600 eyebrow, 21sp/800 branch title, line height 1.1, 4–8dp internal gaps.
- `home_screen.dart:432-443`: notification button 48×48dp, 16dp radius, shared shadow.
- `home_screen.dart:492-525`: search height 50dp, 16dp radius, white surface, 1dp border, shared shadow, 26dp icon, 16sp/500 hint.

### Banner

- `lib/screens/home/components/home_banner_carousel.dart:16-33`: three assets, initial page 999, 5-second autoplay, 450ms animation.
- `home_banner_carousel.dart:204-223`: base height `(width / 2.5).clamp(144, 150)`; accessible/compact layout can grow from TextPainter measurement.
- `home_banner_carousel.dart:251`: 16dp card radius; `:306-315`: 14×6 current indicator, 6×6 inactive indicators, 3dp horizontal margins.
- `home_banner_carousel.dart:442-539`: normal 16dp horizontal/10dp top/12dp bottom padding; logo 22dp; title 18sp, subtitle 11sp, CTA 12sp/600; compact/accessibility branches reduce or expand these values.

### Loyalty card

- `lib/components/points_balance_card.dart:28-43`: minimum height 104dp, 14dp horizontal × 10dp vertical padding, 16dp radius, green gradient, border and shared shadow.
- `points_balance_card.dart:48-61`: icon surface 40×40dp, 22dp icon, 10dp gap.
- `points_balance_card.dart:74-116`: label 14sp/600, balance 28sp/700 tabular figures, unit 16sp/500, helper 14sp/500 with 1.4 line height.

### Products and categories

- `home_screen.dart:1542-1573`: product width breakpoint is 148dp under 360dp, 156dp under 390dp, 168dp otherwise, plus text-scale adjustment; 12dp horizontal gap; list height uses scaled 15sp/14sp line metrics.
- `home_screen.dart:1450-1488`: section header is a `Row` with an expanded `Theme.of(context).textTheme.titleMedium` title, color `titleColor`, weight 700; `TextButton` action uses `bodyTextColor`, 4dp horizontal padding, a weight-700 label, 4dp gap, and a 22dp rounded chevron. No explicit letter spacing is set, so theme/inherited typography applies.
- `home_screen.dart:1617-1678`: 16dp card radius, white surface, border/shadow, image `(width - 2) × 9/16`, content padding 12/8/10/8dp, name 15sp/700 at 1.25, price 14sp/700 at 1.25.
- `lib/screens/home/components/home_category_strip.dart:23-28`: height formula uses scaled 13sp × 1.3 × two lines plus 64dp image and 8dp padding.
- `home_category_strip.dart:37-90`: 10dp card gap, 16dp radius, 1dp border, 64×64dp image surface, 8dp internal padding.
- `home_category_strip.dart:28-34`: item width is `(scaled label size × 8.3).clamp(108, 224)`, so category width grows with text scale and is capped at 224dp; this is source behavior, not a runtime bound measurement.
- `home_category_strip.dart:145-148`: category label 13sp/600, line height 1.3, max two lines.

### Navigation

- `lib/navigation/app_nav_bar_layout.dart:30-108`: min height 96dp, panel top 14dp, tab top 27dp, 34dp icon height, 4dp label gap, 16dp bottom content padding; phone margin 8dp and bottom safe inset + 8dp.
- `app_nav_bar_layout.dart:80-91`: label 12sp/500 at 1.15, measured with `MediaQuery.textScaler`.
- `lib/components/floating_nav_bar.dart:52-71`: panel radius 28dp, outline border, upward shadow; `:176-230`: QR diameter up to 60dp and ordinary active icon container 48×34dp.

## Corrected findings

### Confirmed defects

1. **P1 — Evidence coverage defect in v1.** The original Pro Max “top” screenshot was vertically scrolled. Corrected by `iPhone_17_Pro_Max/01_top_true.png`.
2. **P1 — No numeric runtime typography evidence.** The current audit cannot confirm a non-default `TextScaler`; this remains a measurement gap, not an app defect.
3. **P2 — State mismatch across devices.** Guest/authenticated and banner-slide differences prevent direct visual comparison of loyalty content and hero state. This is documented and not treated as a UI defect.

### Visual-design observations

- At the captured 17e state, the header/search/loyalty typography occupies a high share of the viewport. This is a valid design observation, but the cause may be Dynamic Type, base sizes, or both.
- Pro Max has more logical width and shows more balanced product/category composition. This is a viewport comparison, not proof that its text scale differs.
- The same product strip can show a partially visible left item after a horizontal drag. That behavior is expected for a scrollable list and is not a confirmed defect.
- The floating navigation remains visible at final vertical extent; the captures do not prove that it permanently blocks content.

### Unverified hypotheses

- Simulator Dynamic Type may be above default; numeric scale is not available.
- Large base sizes (21sp branch title, 16sp search, 28sp balance) may make a high accessibility scale feel disproportionate.
- The first product may appear clipped because of horizontal scroll position rather than a layout constraint.

## Recommendations after measurement only

1. Obtain numeric `MediaQuery.textScaler` and `ScrollPosition` values through DevTools before any typography recommendation.
2. Re-run both devices with matched guest/auth state where safely possible and lock the carousel to one slide for the primary comparison.
3. If the effective scale is large, review hierarchy-specific styles rather than applying a global clamp or blanket font reduction; preserve accessible body text and verify large-text behavior.
4. Validate product-list appearance separately at `minScrollExtent` and after horizontal drag before classifying the left-edge partial card.
5. Use runtime render bounds and safe-area values to distinguish a true obstruction from content that is merely visually near the floating nav.

## Audit artifact validation

- `HOME_SCREENSHOTS_v2.zip` contains all v2 captures plus the manifest.
- Every PNG was captured with `xcrun simctl io screenshot` and inspected before packaging.
- No application files were modified during v2. The repository remains dirty only with pre-existing WIP and audit artifacts.

