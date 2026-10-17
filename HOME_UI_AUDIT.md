# Sardoba Home Screen UI/UX Audit

**Audit date:** 2026-10-15  
**Scope:** read-only visual and source audit of the Flutter Home screen on the available iPhone 17e and iPhone 17 Pro Max simulators.  
**Evidence rule:** screenshots in `HOME_SCREENSHOTS.zip` were captured during this audit run. No application source, configuration, backend, or business logic was changed.

## Executive summary

The Home screen is functional and the overall visual language is coherent: SF Pro Text, dark Sardoba green, light neutral background, rounded cards, a three-slide hero, a shared loyalty card, horizontal product/category strips, and floating five-tab navigation. The dominant issue is text scale. On iPhone 17e, the same logical styles that look compact on iPhone 17 Pro Max render very large, causing the header, search hint, loyalty card and product cards to consume most of the first viewport. The source does not override Flutter's `MediaQuery.textScaler`; therefore simulator Dynamic Type/accessibility scaling is the leading runtime explanation. A secondary issue remains at the normal scale: horizontal product cards intentionally expose the next card, but the first card is clipped at the left edge in the 17e capture, reducing scanability.

The Pro Max was available and captured in both top and scrolled states. The 17e was available and captured in both states. Both devices were already booted and the app was installed. Simulator accessibility defaults did not expose a text-scale key through `defaults`, so the exact Dynamic Type setting cannot be proven from the command line alone; this is recorded as an evidence limitation rather than guessed.

## Device and runtime evidence

| Device | iOS | Screenshot pixels | Reported scale | Logical viewport derived from pixels | App state | Evidence |
|---|---:|---:|---:|---:|---|---|
| iPhone 17e | 27.0 | 1170 × 2532 | 3.0 | 390 × 844 | Home, selected branch, guest points state | `iPhone_17e/top_home.png`, `iPhone_17e/scrolled_products_categories.png` |
| iPhone 17 Pro Max | 26.4 | 1320 × 2868 | 3.0 | 440 × 956 | Home, selected branch, authenticated points state | `iPhone_17_Pro_Max/top_home.png`, `iPhone_17_Pro_Max/scrolled_products_categories.png` |

Pixel dimensions and scale came from `simctl`; logical sizes are the arithmetic quotient and are labelled derived. Both screenshots show the simulator status bar and app content, not a fabricated mock. The Pro Max screenshot was captured after the app was already in a scrolled state; no PIN or account action was entered.

### Screenshot step list

1. **17e top viewport — healthy with scale imbalance.** Header, search, banner, points card, first products, category heading, and navigation are visible. Text is disproportionately large and the first product is clipped at the left edge. See `iPhone_17e/top_home.png`.
2. **17e scrolled products/categories — healthy interaction evidence.** A real upward drag reveals product prices, categories, and the bottom navigation; the nav remains visible and content is not permanently hidden. See `iPhone_17e/scrolled_products_categories.png`.
3. **17 Pro Max top viewport — healthy baseline.** The wider logical viewport presents the same hierarchy with considerably more balanced text and card proportions. See `iPhone_17_Pro_Max/top_home.png`.
4. **17 Pro Max scrolled products/categories — healthy.** Products and categories are visible together; horizontal strips remain horizontally scrollable and the nav floats above the content. See `iPhone_17_Pro_Max/scrolled_products_categories.png`.

## Widget hierarchy

`EntryPoint`/app shell → `Stack` → `HomeScreen` body + `FloatingNavBar`.

`HomeScreen` → `Scaffold` → `SafeArea(top: true, bottom: false)` → `RefreshIndicator` → `SingleChildScrollView(AlwaysScrollable, Bouncing)` → `RepaintBoundary(_HomeHeader)` → `_HomeSearchBar` → `HomeBannerCarousel` → `_LoyaltyStats`/`PointsBalanceCard` → `_HomeMenuPreview` → product section header + horizontal product `ListView` → categories section header + `HomeCategoryStrip`.

Nested content includes branch selection and notification actions in `_HomeHeader`, `Image.network` product/category images, `PageView` banner slides, semantics for the banner slider and pause action, and the five `FloatingNavBar` destinations (Home, Menu, QR, Branches, Profile).

## Current styling specification

### Page, safe area, and spacing

- `lib/screens/home/home_screen.dart:127-180`: top `SafeArea`; bottom is intentionally handled by `navAwareBottomPadding`, not by `SafeArea`.
- `home_screen.dart:137`: page padding is `EdgeInsets.fromLTRB(16, 4, 16, navAwareBottomPadding(context, extra: 16))`.
- Related gaps are `AppSpacing.related = 8dp`; major section gaps are `AppSpacing.section = 12dp` (`lib/constants.dart:30-33`).
- Refresh uses `RefreshIndicator` around an always-scrollable, bouncing `SingleChildScrollView`.
- `AppRadius.control/card = 16dp`; panel radius is 24dp (`lib/constants.dart:21-28`).

### Header

`lib/screens/home/home_screen.dart:189-470` (`_HomeHeader`). The branch row uses a 48dp action button (`:432-443`), a 26dp location icon, 12sp branch eyebrow (`:334-336`, weight 600, line height 1.1), and a 21sp branch title (`:361-363`, weight 800, line height 1.1). Internal row gaps are 4–8dp; the notification button is 48 × 48dp with the shared 14dp blur/4dp downward shadow. The title has the strongest evidence of oversizing on the 17e: 21sp is large before Dynamic Type scaling and competes with the banner headline.

### Search

`home_screen.dart:475-529` (`_HomeSearchBar`). Fixed height 50dp, 16dp radius, white surface, `appBorderColor` border and `appCardShadow`. Leading icon is 26dp with 17dp left space; text gap is 13dp; trailing space is 17dp. Hint is 16sp, weight 500 (`:520-525`). The screenshot confirms the hint scales along with all other Flutter text.

### Banner carousel

`lib/screens/home/components/home_banner_carousel.dart:16-540`.

- Three assets: `soup.webp`, `kebab.webp`, `manti.webp`; `PageController(initialPage: 999)` and 450ms `easeInOutCubic` page animation (`:16-33`).
- Autoplay every 5 seconds (`:16`, `:75-80`), with pause on lifecycle/focus/hover/reduced-motion/accessibility and an explicit 48dp pause hit target (`:327-356`).
- Base height is `(availableWidth / 2.5).clamp(144, 150)` (`:204-223`): approximately 2.5:1, capped at 150dp. Accessible/compact layouts can grow using `TextPainter` measurement (`:105-121`, `:204-210`).
- Card radius is 16dp (`:251`); image uses `BoxFit.cover` and a device-pixel cache width (`:405`).
- Normal slide padding is 16dp horizontal, 10dp top, 12dp bottom; compact widths reduce top/right/bottom padding (`:442-450`). Logo is 22dp normal / 16dp compact (`:457-458`), title 18sp normal / 14sp compact / 16sp accessible (`:466-491`), subtitle 11sp / 10sp compact (`:503-506`), CTA 12sp semibold (`:532-539`).
- Indicators are 14 × 6dp for the current page and 6 × 6dp for others, 3dp horizontal margin (`:306-315`).

The implementation is responsive and preserves autoplay/swipe/pause. In the 17e evidence, the large system text scale makes the banner typography visually compete with the artwork despite the dynamic height guard.

### Loyalty points card

`lib/components/points_balance_card.dart:28-151`.

- `ConstrainedBox(minHeight: 104dp)` and padding 14dp horizontal × 10dp vertical (`:32-34`).
- Radius 16dp, dark-green gradient, subtle white-alpha border, and `appCardShadow` (`:41-43`).
- Icon surface 40 × 40dp, icon 22dp, 10dp gap (`:48-61`).
- Label 14sp semibold line height 1.2 (`:74-76`), balance 28sp bold tabular figures line height 1.1 (`:100-103`), unit 16sp medium, helper 14sp medium line height 1.4 (`:114-116`), chevron 24dp.

The balance is correctly the visual primary element at normal scale. On 17e guest state, the 28sp balance slot is still large even though it contains “—”; the helper wraps to two lines and makes the card tall. On Pro Max authenticated state it is balanced.

### Products / menu preview

`home_screen.dart:1265-1714` (`_HomeMenuPreview`, `_HomeProductCard`). Section header is at `:1472-1481`; product section gap is 8dp and category section gap is 12dp (`:1558-1584`). Product card widths are breakpoint-driven: 148dp under 360dp, 156dp under 390dp, otherwise 168dp, with a text-scale adjustment (`:1542-1549`). Horizontal gap is 12dp (`:1565-1573`).

- Card radius 16dp, white background, border and shared shadow (`:1617-1631`).
- Image ratio is 16:9: `imageHeight = (cardWidth - 2) * 9 / 16` (`:1640-1643`); `BoxFit.cover`, device-pixel cache width (`:1713`).
- Content padding is 12dp left, 8dp top/bottom, 10dp right (`:1653-1654`). Product name is 15sp bold, 1.25 line height, max two lines (`:1664-1666`); price is 14sp bold, 1.25 line height (`:1676-1678`).
- Ordering is deterministic in `_orderedHomeEntries`; it does not randomly reshuffle. The display heading is localized `Из меню` / `Menyudan`, not an unsupported popularity claim.

The first item is clipped in the 17e top screenshot because the horizontal list is positioned at the edge while the first card’s long title expands visually; the Pro Max capture is easier to scan. This is a visual issue, not evidence of a backend price or availability defect.

### Categories

`lib/screens/home/components/home_category_strip.dart:7-190`.

- Compact horizontal list with 10dp item gaps (`:37-43`).
- Card radius 16dp, 1dp neutral border, selected state uses primary green (`:59-62`).
- 8dp internal padding (`:70`), icon/image surface 64 × 64dp (`:74-90`), and label 13sp semibold, line height 1.3, max two lines (`:145-148`).
- Height is computed from scaled 13sp text plus 8dp top/bottom and 64dp image (`:23-28`), which is the correct overflow-safe pattern.

The localized `Категории` heading and `Все` action are present in the source and visible in both captured states.

### Bottom navigation

`lib/components/floating_nav_bar.dart:7-252` and `lib/navigation/app_nav_bar_layout.dart:30-108`.

- Five-tab floating panel; panel radius 28dp, surfaceContainerLowest background, outline-variant border and shadow (`floating_nav_bar.dart:52-71`).
- Layout padding is calculated from safe bottom inset: 8dp side margin on phone, safe bottom + 8dp bottom (`app_nav_bar_layout.dart:67-69`). Minimum height is 96dp; panel top is 14dp; tab top is 27dp; icon height is 34dp; label gap is 4dp; bottom content padding is 16dp (`app_nav_bar_layout.dart:30-49`).
- Label style is 12sp, weight 500, line height 1.15 and measured with `MediaQuery.textScaler` (`:80-91`).
- QR is a separate elevated center action up to 60dp with a white ring; ordinary active tab has a 48 × 34dp mint container (`floating_nav_bar.dart:176-230`).
- Exactly one destination is selected by the caller; QR is not marked as a selected tab.

The scrolled captures show the nav floating above content and remaining usable. At the 17e large scale, the nav consumes a much larger visual fraction of the viewport because labels and icons are both scaled by system text/accessibility behavior.

## Why the text looks oversized

1. `main.dart:84-85` and `theme.dart:10` set the font family to SF Pro Text, but neither file clamps or overrides Flutter text scaling.
2. The implementation consistently calls `MediaQuery.textScalerOf(context)` for banner measurement, product-card width/height, category height, and nav label measurement, so a large device text scale is intentionally honoured rather than ignored (`home_banner_carousel.dart:105-121, 204-210`; `home_screen.dart:1542-1551`; `home_category_strip.dart:23-28`; `app_nav_bar_layout.dart:80-91`).
3. Several base sizes are already assertive: header title 21sp, search 16sp, loyalty balance 28sp, product title 15sp, and nav label 12sp. If Dynamic Type is above the default, all of these increase together and the screen loses hierarchy.
4. Fixed visual slots do not all grow equally. The header action remains 48dp, search remains 50dp, banner baseline remains 144–150dp, while text can grow. This produces the observed imbalance and wraps helper/product text.
5. `simctl spawn ... defaults read com.apple.Accessibility` only exposed `GrayscaleDisplay = 0` on both simulators; no text-scale value was available. Therefore the exact accessibility scale is **unknown**, not assumed. A Settings-based capture or Flutter runtime diagnostic is needed to prove the numeric `MediaQuery.textScaler`.

There is no source evidence of a screen-specific font multiplier or a custom global `textScaleFactor`. The strongest root-cause hypothesis is simulator Dynamic Type combined with large fixed base sizes, not a second hidden font family.

## Side-by-side findings

| Area | iPhone 17e (390dp derived) | iPhone 17 Pro Max (440dp derived) | Finding |
|---|---|---|---|
| Header | Very large branch title and eyebrow; notification remains 48dp | Balanced title-to-action ratio | P1 hierarchy risk on 17e / large scale |
| Search | 50dp field with oversized hint and icon | Same field reads compact | P1 text-scale mismatch |
| Banner | Hero copy occupies a large share of the 144–150dp slot | Copy and artwork balance better | P1 readability/competition risk |
| Points | Guest helper wraps; card dominates first viewport | Authenticated balance is legible and proportionate | P1 adaptive-height/scale risk |
| Products | First card clipped at left; long title and price are dominant | Names and prices fit more naturally | P1 horizontal scanability issue |
| Categories | Heading begins behind the nav at top state; visible after drag | Categories visible in the same general viewport | P1 first-viewport visibility issue on 17e |
| Navigation | Large labels and 60dp QR dominate bottom | Proportional and clear | P1 scale perception; no functional overlap observed |

## Prioritized issues and recommendations

1. **P0 — Establish a measured text-scale policy.** Capture `MediaQuery.textScalerOf(context).textScaleFactor` (or equivalent numeric scale) in a debug-only audit build and record iOS Dynamic Type settings. Then decide whether Home should use a bounded scale for decorative/compact labels while preserving accessibility for body text. Do not silently clamp before accessibility review.
2. **P1 — Reduce competing base sizes.** Re-evaluate the 21sp branch title, 16sp search hint, 28sp points balance, and 15sp product title as a group. Preserve the balance card’s primary emphasis but lower secondary hierarchy before changing card geometry.
3. **P1 — Make first product fully visible.** Ensure the horizontal list starts with a complete first card at 16dp page inset; use a consistent card width and allow the next card to peek only on the trailing edge.
4. **P1 — Protect first viewport.** At 390dp with the measured text scale, verify that the category heading is not hidden behind the floating nav. The current bottom padding is present, but first-viewport composition still places the heading at the nav boundary.
5. **P1 — Test the five required widths and large text.** Run 320, 360, 375, 390, and 430dp with default, large, and largest accessibility scales. Check header title wrapping, banner CTA, points helper, two-line product names, category labels, and nav labels.
6. **P2 — Consolidate typography tokens.** Keep SF Pro Text and existing colors/radii, but define named title/body/label styles so 21/16/15/14/13/12sp are reviewed as a scale rather than independently tuned values.
7. **P2 — Keep runtime behavior as-is until visual fixes are approved.** Autoplay, swipe, pause, branch-specific catalog data, deterministic ordering, refresh wiring, authentication state and navigation were not changed by this audit.

## Validation and limitations

- `HOME_SCREENSHOTS.zip` contains the four accepted screenshots captured on the two booted simulators. Each was inspected before packaging.
- The audit did not modify source code. Existing project validation before this audit was reported as `flutter analyze` clean and `flutter test` passing (98 tests); this turn did not rerun or alter those checks.
- Exact `MediaQuery` text-scale and SafeArea values were not directly exported by the running app. Safe-area handling is source-confirmed through `SafeArea` and `AppNavBarLayout`, while numeric insets remain runtime-unmeasured.
- No physical iPhone 17e/17 Pro Max hardware was used; evidence is from the named iOS simulators.
- Product data and prices are real app-rendered values from the current local runtime; this report does not infer popularity or backend ranking.

### If a future run needs numeric text-scale proof

Run the app on each simulator, open Settings → Accessibility → Display & Text Size, record the selected text size, then return to Home and capture a debug-only runtime readout of `MediaQuery.textScalerOf(context)`. Repeat at default and the user-reported large setting. This is the only reliable way to separate a simulator accessibility setting from a fixed application typography issue.

