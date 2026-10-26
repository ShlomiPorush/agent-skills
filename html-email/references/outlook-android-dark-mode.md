# Outlook for Android in dark mode: what was measured

Evidence behind the `html-email` skill. Treat it as a dated measurement of one client. It holds for the setup below and is not a promise about other versions or clients.

## Setup

- Outlook for Android, dark mode, October 2026. The app and OS versions were not recorded; record them in the next measurement.
- Emails sent through the application's own SMTP settings, with a light inline design and a `<style>` block holding `@media (prefers-color-scheme: dark)` with a slightly green-tinted dark palette (`#0E1110` background, `#171B19` panels).
- Colours read as pixel values from direct phone screenshots (JPEG). PNG originals would be more exact. The app background read as `#141414`.

## Background colours

| Sent | Shown |
|---|---|
| `#FFFFFF` | `#141414`, the app's own background |
| `#FAFAFA` | `#171717` |
| `#EEEEEE` | `#1E1E1E` |
| `#E0E0E0` | `#272727` |
| `#CCCCCC` | `#353535` |
| `#999999` | `#5B5B5B` |
| `#666666` | `#6A6A6A` |
| `#333333` | `#333333` |
| `#202020` | `#202020` |
| `#141414` | `#141414` |
| `#000000` | `#000000` |
| `#F4F6F5` (light, tinted) | `#4B4D4C` |
| `#0E1110` (dark, tinted) | `#4B4D4C` |
| `#171B19` (dark, tinted) | `#494E4A` |
| `#F2EAD9` (light, warm tint) | `#504C40` |

Text: dark text (`#111814`) showed as white. Light text and saturated reds and ambers stayed readable. A red bar supplied as `#FF6B61` in dark mode showed as a darker red, still clearly red.

## What each attempt showed

| Attempt | Result |
|---|---|
| The original email: light inline colours plus the tinted dark-mode block | Whole email `#4B4D4C`, panels blended in. So Outlook applies the dark-mode block and then remaps it. |
| The same light email without any dark-mode rules | Card `#141414` (white turned into the app background), panels `#4B4D4C`, warning banner brown. Better than the original. |
| `[data-ogsb] .card` rules targeting the coloured element itself, with the dark palette | No visible effect: Outlook's inline `!important` wins on the marked element. |
| The dark palette set on an inner element without inline colour, under a marked ancestor | Applied, then remapped to the same mid grey. Descendant rules work, but tinted values do not survive. |
| An email dark by design (dark inline colours) | Card `#4B4D4C`: tinted dark colours are lifted to grey even inline. |
| Descendant rules giving white to the outer wrapper and `#202020` / `#333333` to panels and lines | Background `#141414`, panels `#202020` distinct, lines visible, tags and banners readable. This is the fix. |

## Dates

| Written as | Shown |
|---|---|
| `26.10.2026` | the date as a blue link |
| `26.&zwnj;10.&zwnj;2026` | not a link, but the text now holds invisible characters |
| inside a wrapper with `a { color: inherit !important; text-decoration: none !important; }` | not blue |

## Mechanism, from the sources

In dark mode Outlook.com and the Outlook apps add `data-ogsc` (original text colour) and `data-ogsb` (original background) to the elements they recolour, and write the new colour inline with `!important`. A stylesheet rule cannot beat that on the same element; a rule for a descendant can, and Outlook then passes the descendant's colour through the same filter. Class names are prefixed with `x_` in both the HTML and the CSS, so class selectors still match. An attribute joined to a class in one selector is not supported.

## Sources

- Can I email, `prefers-color-scheme`: https://www.caniemail.com/features/css-at-media-prefers-color-scheme/
- Can I email, attribute selectors: https://www.caniemail.com/features/css-selector-attribute/
- Parcel, colour scheme in email: https://parcel.io/guides/color-scheme-in-email
- Rémi Parmentier, Outlook.com dark mode: https://www.hteumeuleu.com/2021/emails-react-outlook-com-dark-mode/
- Litmus, dark mode for email: https://www.litmus.com/blog/the-ultimate-guide-to-dark-mode-for-email-marketers
