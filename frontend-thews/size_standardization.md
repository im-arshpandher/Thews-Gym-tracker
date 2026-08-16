# Flutter UI Size & Typography Standardization

Audit and standardize the entire Flutter application's UI sizing system.

## Objective

The application currently has inconsistent UI sizing across different screens and components:

* Some text is too large.
* Some text is too small.
* Similar text uses different font sizes.
* Buttons and inputs have inconsistent heights.
* Icons vary unnecessarily.
* Padding and spacing are inconsistent.
* Cards, dialogs, buttons, and inputs use inconsistent border radii.
* Some screens look good while others appear oversized or undersized.
* UI elements do not scale consistently across different screen sizes.

Fix these inconsistencies and establish a **sleek, modern, compact, professional, and responsive design system** across the entire application.

Do NOT redesign the application.

Preserve:

* Existing layouts
* Existing colors
* Existing functionality
* Existing navigation
* Existing component structure where reasonable
* Existing visual identity

Only standardize sizing, typography, spacing, radius, and responsive behavior where necessary.

---

# 1. Typography System

Use the following typography scale throughout the application:

| Usage                  | Size |  Weight | Line Height |
| ---------------------- | ---: | ------: | ----------: |
| Hero / Display         |   32 |     700 |        1.15 |
| Page Title             |   26 |     700 |        1.20 |
| Section Title          |   22 |     600 |        1.25 |
| Card / Component Title |   18 |     600 |        1.30 |
| Large Body             |   16 | 400/500 |        1.45 |
| Standard Body          |   14 |     400 |        1.45 |
| Secondary Text         |   13 |     400 |        1.35 |
| Caption / Metadata     |   12 | 400/500 |        1.30 |
| Tiny Label             |   11 |     500 |        1.20 |
| Button / Input Label   |   14 | 500/600 |        1.20 |

Avoid arbitrary font sizes.

Prefer:

```text
11, 12, 13, 14, 16, 18, 22, 26, 32
```

Do not introduce sizes such as:

```text
15, 17, 19, 21, 23, 27
```

unless there is a clear and documented UI reason.

---

# 2. Use Flutter TextTheme

Centralize typography using Flutter's `TextTheme`.

Map typography approximately as follows:

```dart
displayLarge   → 32px
headlineLarge  → 26px
headlineMedium → 22px
titleLarge     → 18px
bodyLarge      → 16px
bodyMedium     → 14px
bodySmall      → 13px
labelLarge     → 14px
labelMedium    → 12px
labelSmall     → 11px
```

Prefer:

```dart
Text(
  'Account Settings',
  style: Theme.of(context).textTheme.titleLarge,
)
```

instead of:

```dart
Text(
  'Account Settings',
  style: TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.bold,
  ),
)
```

Do not create local `TextStyle` values when an equivalent theme style already exists.

---

# 3. Spacing System

Use the following spacing scale:

```text
4   → tiny spacing
8   → small spacing
12  → compact spacing
16  → standard spacing
20  → medium spacing
24  → large spacing
32  → section spacing
40  → large section spacing
48  → major separation
```

Preferred values:

```text
4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48
```

Avoid arbitrary spacing such as:

```text
13 / 17 / 19 / 23 / 27 / 31
```

unless required by a specific layout.

---

# 4. Standard Component Sizes

Use these values as the application's baseline.

## Buttons

```text
Small:    40px
Standard: 48px
Large:    56px
```

Default to `48px`.

Use `40px` only for compact secondary actions.

Use `56px` only when a large primary CTA is visually justified.

---

## Input Fields

Target:

```text
48–52px
```

Inputs of the same type should have consistent heights.

---

## Icons

```text
Small:    18px
Compact:  20px
Standard: 24px
Large:    28px
XL:       32px
```

Default icon size:

```text
24px
```

Do not randomly mix values such as `21`, `23`, `25`, `27`, etc.

---

## Avatars

```text
Small:    32px
Standard: 40px
Large:    56px
```

---

# 5. Border Radius

Use a restricted radius system:

```text
8px  → small elements
12px → buttons / inputs
16px → cards / containers
20px → dialogs / large surfaces
```

Suggested defaults:

```text
Button: 12px
Input:  12px
Card:   16px
Dialog: 20px
```

Do not use different radii on visually identical components.

---

# 6. Responsive Scaling

The UI must work properly across different phone sizes and larger displays.

Use approximately:

```text
390px
```

as the reference mobile width.

Do NOT directly calculate every font or component size from screen width.

Bad:

```dart
fontSize: MediaQuery.sizeOf(context).width * 0.05
```

This can produce excessively large or small UI.

Instead, use controlled/clamped scaling.

Example:

```dart
class AppScale {
  static double factor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return (width / 390).clamp(0.90, 1.15);
  }

  static double font(BuildContext context, double size) {
    return size * factor(context);
  }

  static double spacing(BuildContext context, double size) {
    return size * factor(context);
  }

  static double icon(BuildContext context, double size) {
    return size * factor(context);
  }
}
```

Expected approximate behavior:

```text
360px screen → ~0.92x
390px screen → 1.00x
430px screen → ~1.10x
Large screen → maximum 1.15x
```

Do not allow unrestricted scaling.

---

# 7. Responsive Layout vs UI Scaling

Do not treat responsive design as simply making everything bigger.

For larger screens/tablets, adjust:

* Maximum content width
* Number of columns
* Grid layout
* Navigation layout
* Horizontal spacing
* Dialog width
* Card arrangement

while keeping typography relatively restrained.

For example:

Bad:

```text
Phone:
14px body

Tablet:
24px body
```

Better:

```text
Phone:
14px body + single-column layout

Tablet:
14–16px body + wider/two-column layout
```

---

# 8. Centralized Design Tokens

Create or improve a centralized theme structure such as:

```text
lib/
└── core/
    └── theme/
        ├── app_theme.dart
        ├── app_typography.dart
        ├── app_spacing.dart
        ├── app_sizes.dart
        ├── app_radius.dart
        └── app_scale.dart
```

Adapt this structure to the existing project architecture rather than forcing it if equivalent files already exist.

Example:

```dart
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const medium = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}
```

```dart
abstract final class AppSizes {
  static const iconSmall = 18.0;
  static const iconCompact = 20.0;
  static const icon = 24.0;
  static const iconLarge = 28.0;
  static const iconXL = 32.0;

  static const buttonSmall = 40.0;
  static const button = 48.0;
  static const buttonLarge = 56.0;

  static const avatarSmall = 32.0;
  static const avatar = 40.0;
  static const avatarLarge = 56.0;
}
```

```dart
abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const dialog = 20.0;
}
```

---

# 9. Audit the Entire Existing Application

Before making changes, inspect the entire UI codebase.

Find:

* Hardcoded `fontSize`
* Hardcoded icon sizes
* Hardcoded button heights
* Hardcoded input heights
* Random `SizedBox` dimensions
* Random `EdgeInsets`
* Random border radii
* Duplicate `TextStyle` definitions
* Duplicate component sizing
* Excessive `MediaQuery` sizing calculations
* Fixed widths that break smaller screens
* Overflow-prone rows
* Inconsistent card padding
* Inconsistent dialog sizing
* Inconsistent AppBar typography
* Inconsistent bottom navigation sizing
* Inconsistent list item sizing

Determine which existing screens already look correct and use them as additional visual references.

Do not blindly replace every number.

Understand the purpose of the component before changing it.

---

# 10. Preserve Accessibility

Responsive scaling must not break Flutter/system accessibility behavior.

Do not globally disable user text scaling merely to force the design to remain visually identical.

Layouts should tolerate increased text sizes where reasonably possible.

Avoid fixed-height text containers when the text may wrap.

Prefer flexible constraints where appropriate.

---

# 11. Implementation Strategy

Perform the work in this order:

1. Audit the current UI.
2. Identify repeated sizing patterns.
3. Identify inconsistent/outlier values.
4. Create or improve centralized design tokens.
5. Configure the application's `TextTheme`.
6. Standardize common/shared components first.
7. Update individual screens.
8. Remove unnecessary hardcoded sizing.
9. Add controlled responsive behavior.
10. Test major screen sizes.
11. Run Flutter analyzer/tests.
12. Fix any UI overflow or regression introduced by the changes.

Do not make unrelated refactors.

---

# 12. Screen Sizes to Verify

At minimum, verify the UI around:

```text
320px  → very small phone
360px  → small phone
390px  → reference phone
412px  → common Android phone
430px  → large phone
600px+ → tablet / larger display
```

Pay special attention to:

* Text wrapping
* `RenderFlex` overflow
* Button labels
* AppBars
* Dialogs
* Bottom sheets
* Forms
* Navigation
* Cards
* Lists
* Empty states
* Long titles
* Long user-generated content

---

# 13. Final Standard

The resulting design system should approximately follow:

```text
TYPOGRAPHY

11 → Tiny
12 → Caption
13 → Secondary
14 → Body / Button
16 → Large Body
18 → Card Title
22 → Section Title
26 → Page Title
32 → Hero


SPACING

4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48


ICONS

18 / 20 / 24 / 28 / 32


BUTTON HEIGHT

40 / 48 / 56


INPUT HEIGHT

48–52


RADIUS

8 / 12 / 16 / 20


RESPONSIVE REFERENCE

390px


CONTROLLED SCALING

Minimum → 0.90x
Reference → 1.00x
Maximum → 1.15x
```

---

# DOs

### DO use centralized typography

Good:

```dart
Text(
  'Orders',
  style: Theme.of(context).textTheme.headlineMedium,
)
```

### DO use standardized spacing

Good:

```dart
Padding(
  padding: const EdgeInsets.all(AppSpacing.base),
  child: ...
)
```

### DO use consistent icons

Good:

```dart
Icon(
  Icons.settings,
  size: AppSizes.icon,
)
```

### DO use flexible layouts

Good:

```dart
Expanded(
  child: Text(
    product.name,
    overflow: TextOverflow.ellipsis,
  ),
)
```

### DO clamp responsive scaling

Good:

```dart
(width / 390).clamp(0.90, 1.15)
```

### DO reuse existing components

If the application already has a shared button, input, card, or typography component, improve that component rather than creating another duplicate.

---

# DON'Ts

### DON'T randomly choose font sizes

Bad:

```dart
fontSize: 17
```

Better:

```dart
style: Theme.of(context).textTheme.bodyLarge
```

---

### DON'T use random padding

Bad:

```dart
padding: const EdgeInsets.all(19)
```

Better:

```dart
padding: const EdgeInsets.all(AppSpacing.base)
```

---

### DON'T scale directly from screen width

Bad:

```dart
fontSize: MediaQuery.sizeOf(context).width * 0.06
```

Better:

```dart
fontSize: AppScale.font(context, 16)
```

---

### DON'T make tablet UI simply larger

Bad:

```text
Phone → 14px
Tablet → 24px
```

Better:

```text
Phone → 14px + 1 column
Tablet → 14–16px + 2 columns
```

---

### DON'T hardcode widths unnecessarily

Bad:

```dart
Container(
  width: 350,
)
```

Better:

```dart
SizedBox(
  width: double.infinity,
)
```

or use appropriate constraints.

---

### DON'T create duplicate styles

Bad:

```dart
TextStyle(fontSize: 18, fontWeight: FontWeight.w600)
```

repeated across 20 files.

Better:

```dart
Theme.of(context).textTheme.titleLarge
```

---

### DON'T change unrelated UI

Do not change:

* Colors
* Business logic
* API behavior
* Navigation
* Features
* Data models
* State management
* Animations unless sizing causes a problem

The task is **UI sizing and consistency**, not a redesign.

---

# Expected Result

After completion, the application should have:

* Consistent typography hierarchy
* Consistent component sizes
* Consistent spacing
* Consistent border radius
* Consistent icons
* Better behavior on small phones
* Better behavior on large phones
* Appropriate tablet layouts
* No unnecessarily huge text
* No excessively tiny text
* Minimal hardcoded arbitrary sizing
* Reusable centralized design tokens
* No new overflow issues
* No functionality regressions

The final UI should feel **sleek, compact, balanced, modern, and consistent** rather than oversized or cramped.

After implementation, provide a short report containing:

1. Files added or modified.
2. Design tokens/theme introduced.
3. Major inconsistencies fixed.
4. Screens/components updated.
5. Any remaining hardcoded sizing and why it remains.
6. Responsive behavior added.
7. Analyzer/test results.
8. Any UI areas that should be manually visually verified.
