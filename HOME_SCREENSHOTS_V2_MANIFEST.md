# Home audit v2 screenshot manifest

Capture date: 2026-10-15 (Asia/Tashkent)

All captures are real `xcrun simctl io screenshot` PNGs from the running installed `com.sardoba.app` build. Logical viewport is derived from physical pixels ÷ simulator scale. Exact Flutter scroll offsets were not exposed by Device Hub, so scroll positions are described by state rather than invented numeric values.

| File | Device / runtime | UI state | Authentication / branch | Banner | Scroll state |
|---|---|---|---|---|---|
| `iPhone_17e/01_top_true.png` | iPhone 17e, UDID `F523F7C3-26D1-4BD2-BC42-8C0DD10AE938`, iOS 27.0, 1170×2532 px, scale 3, derived 390×844 dp | True top: full header and search visible | Guest, Sardoba Geofizika | Slide 1 of 3 | Vertical min extent; horizontal products at initial position |
| `iPhone_17e/02_current_section.png` | Same | Loyalty/products/category region | Guest, Sardoba Geofizika | Slide 1 | Intermediate section capture; exact numeric offset unavailable |
| `iPhone_17e/03_final_scroll.png` | Same | Final visible vertical content: products/categories/nav | Guest, Sardoba Geofizika | Slide 1 | Deliberately dragged upward to final reachable extent |
| `iPhone_17e/04_products_horizontal_scrolled.png` | Same | Products after deliberate horizontal drag | Guest, Sardoba Geofizika | Slide 1 | Horizontal list deliberately scrolled left; vertical top preserved |
| `iPhone_17_Pro_Max/01_top_true.png` | iPhone 17 Pro Max, UDID `BBC87BEC-6475-4966-8DBA-FF81DD0A04A2`, iOS 26.4, 1320×2868 px, scale 3, derived 440×956 dp | True top: full header and search visible | Authenticated, Sardoba Geofizika | Slide 1 | Vertical min extent; horizontal products at initial position |
| `iPhone_17_Pro_Max/03_final_scroll.png` | Same | Final visible vertical content: products/categories/nav | Authenticated, Sardoba Geofizika | Slide 1 | Deliberately dragged upward to final reachable extent |
| `iPhone_17_Pro_Max/04_products_horizontal_scrolled.png` | Same | Products after deliberate horizontal drag | Authenticated, Sardoba Geofizika | Slide 3 | Horizontal list deliberately scrolled left; vertical section preserved |

The device states could not be made identical safely: the 17e was guest with a dash balance, while Pro Max was authenticated with 10 642,5 points. Banner autoplay also advanced independently; slide 1 was used for the primary true-top comparison and a slide-3 variant is preserved separately. No account, PIN, backend, or simulator accessibility setting was changed.
