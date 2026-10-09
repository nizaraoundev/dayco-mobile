# Accessibility Audit: Commercial Map — drawer, action bar, client form

**Standard:** WCAG 2.1 AA · **Date:** 2026-10-09 · **Platform:** Flutter / Android

Scope: the commercial map screen and the three areas it owns — the floating
button layer, the navigation drawer, and the create/update client form.

---

## Summary

| | Count |
|---|---|
| Issues found | 14 |
| 🔴 Critical | 4 |
| 🟡 Major | 7 |
| 🟢 Minor | 3 |
| **Fixed in this pass** | **13** |
| Deferred | 1 (see *Not fixed*) |

Contrast ratios below were computed with the WCAG relative-luminance formula,
not estimated by eye.

---

## Findings

### Perceivable

| # | Issue | Criterion | Severity | Fix |
|---|-------|-----------|----------|-----|
| 1 | `Colors.green` behind white text on the confirm-position button = **2.78:1** | 1.4.3 Contrast | 🔴 Critical | New `successStrong` #00893F → 4.52:1 |
| 2 | Brand blue `#008DD2` used as **text** on white = **3.66:1** (button labels, field icons, chips, badges) | 1.4.3 Contrast | 🔴 Critical | Split the role: `brandInk` #00689B (6.08:1) for text, `brandStrong` #007DBB for fills behind white |
| 3 | `textTertiary` `#898989` on white = **3.50:1**, used for metadata text | 1.4.3 Contrast | 🟡 Major | Darkened to #6B7680 → 4.64:1 |
| 4 | Count badge: brand-on-brand-tint ≈ 3.1:1 at 12px | 1.4.3 Contrast | 🟡 Major | `AppCountBadge` uses `brandInk` on tint |
| 5 | Field prefix icons announced as content before the label | 1.1.1 Non-text Content | 🟢 Minor | Wrapped in `ExcludeSemantics` |

### Operable

| # | Issue | Criterion | Severity | Fix |
|---|-------|-----------|----------|-----|
| 6 | Chip delete targets 18×18dp — less than half the 44px minimum | 2.5.5 Target Size | 🔴 Critical | `_RemovableChip` gives the remove action a 36dp hit box inside a 48dp row |
| 7 | Language buttons were bare `OutlinedButton`s with no height floor | 2.5.5 Target Size | 🟡 Major | `AppA11y.minTouchTarget` (48dp) enforced on every control |
| 8 | Submit button sat below ~700px of scroll — unreachable without scrolling the whole form every time | 2.4.3 Focus Order | 🔴 Critical | Footer is now pinned; header pinned too |
| 9 | Confirm-position button hard-positioned at `bottom: 100`, a magic number assuming the bar below was 76px — the two could overlap | 2.4.3 | 🟡 Major | Both are siblings in one column; overlap is now structurally impossible |
| 10 | No visible focus indicator on filled buttons | 2.4.7 Focus Visible | 🟡 Major | Focus/overlay colour + 2px focused border on fields |
| 11 | Keyboard covered the focused field — no inset handling | 2.4.3 | 🟡 Major | Dialog padding tracks `viewInsets.bottom` |

### Understandable

| # | Issue | Criterion | Severity | Fix |
|---|-------|-----------|----------|-----|
| 12 | Every label carried "(optionnel)" inline; no consistent required/optional convention | 3.3.2 Labels or Instructions | 🟢 Minor | `AppTextField.isRequired` renders a single consistent marker; labels cleaned |
| 13 | 20 controls in one flat column — identity, contact, commercial and location interleaved with no grouping | 1.3.1 Info and Relationships | 🟡 Major | Five `AppFormSection`s with `Semantics(header: true)` |

### Robust

| # | Issue | Criterion | Severity | Fix |
|---|-------|-----------|----------|-----|
| 14 | Icon-only controls (menu, close, recentre, remove-photo) had **no accessible name** — announced as unlabelled buttons | 4.1.2 Name, Role, Value | 🔴 Critical | Every icon-only control now carries an explicit `Semantics(button: true, label: …)` |

---

## Colour Contrast — before and after

| Element | Foreground | Background | Before | After | Required | Pass |
|---|---|---|---|---|---|---|
| Confirm-position label | white | `Colors.green` → `successStrong` | 2.78:1 | **4.52:1** | 4.5:1 | ✅ |
| Primary button label | white | `#008DD2` → `brandStrong` | 3.66:1 | **4.52:1** | 4.5:1 | ✅ |
| Secondary button label | `#008DD2` → `brandInk` | white | 3.66:1 | **6.08:1** | 4.5:1 | ✅ |
| Field prefix icon | `#008DD2` → `brandInk` | white | 3.66:1 | **6.08:1** | 3:1 (UI) | ✅ |
| Metadata text | `#898989` → `#6B7680` | white | 3.50:1 | **4.64:1** | 4.5:1 | ✅ |
| Body secondary text | `#626D77` | white | 5.29:1 | 5.29:1 | 4.5:1 | ✅ (already) |
| Error text | `#E31E24` | white | 4.69:1 | 4.69:1 | 4.5:1 | ✅ (already) |

Brand colours kept **as fills only**, where the 4.5:1 text rule does not apply:
`secondaryColor` #7ED6C9 (1.70:1) and `tertiaryColor` #FBCB07 (1.54:1) must
never carry text on a light surface.

---

## Screen reader

| Element | Was announced as | Now |
|---|---|---|
| Menu button | *"button"* (no name) | *"Menu, button"* |
| Close button | *"button"* | *"Fermer, button"* |
| Recentre button | *"button"* | *"Ma position, button"* |
| Language option | *"🇫🇷 FR"* (flag read as country) | *"Français, selected, button"* |
| Map type switch | subtitle text only | *"Carte hybride, switch, off"* |
| Section heading | plain text | heading, navigable as a landmark |
| Submit while saving | name lost during spinner | name preserved |

---

## Not fixed

**Form validation (3.3.1 Error Identification).** `AppTextField` accepts a
`validator` and renders errors correctly, but no field currently passes one —
the form has always submitted without client-side validation. Wiring real rules
(which fields are mandatory, phone/email formats, tax-ID shape) is a product
decision about what the backend requires, not a styling one, so it is left
as a deliberate next step rather than guessed at.

---

## Code health, as a side effect

| | Before | After |
|---|---|---|
| `commercial_map_page.dart` | 2,031 lines | **1,158 lines** |
| Client form | one 630-line method, nested ~20 deep | its own widget, 5 named sections |
| Drawer | 200-line method inside the page | its own widget, 3 labelled groups |
| Corner radii in use on this screen | 8, 10, 12, 14, 16, 20 | 3 tokens (`sm`/`md`/`lg`) |
| Button elevations | 4 and 6, chosen ad hoc | 3 named roles |
| `flutter analyze` | 111 issues, 0 errors | **99 issues, 0 errors** |

New shared layer, reusable beyond this screen:

- `lib/core/theme/design_tokens.dart` — spacing, radius, elevation, a11y
  constants, and the semantic colour roles with their measured ratios
- `lib/core/shared/widget/buttons/app_button.dart` — 5 intent-based variants
- `lib/core/shared/widget/forms/app_text_field.dart` — one field, styled once
- `lib/core/shared/widget/forms/app_form_section.dart` — section, field group,
  count badge

---

## Testing performed

- Contrast: computed for all 15 palette pairs.
- Rendered: Pixel 10 Pro emulator (Android, `google_apis_playstore`) — map
  screen, drawer, and B2B form all verified visually, no layout exceptions.
- Static: `flutter analyze` clean of errors and of any new warnings.

**Not performed:** real screen-reader passes (TalkBack / VoiceOver) and a 200%
font-scale check. The semantics are declared correctly in code, but hearing
them is the only way to confirm phrasing reads naturally.
