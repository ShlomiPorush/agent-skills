# Outlook in dark mode: what was measured

Evidence behind the `html-email` skill. Treat it as a dated measurement of two clients, Outlook for Android and Outlook on the web. It holds for the setups below and is not a promise about other versions or clients.

## Outlook on the web

### Setup

- outlook.office.com with a work account and a Hebrew interface, Outlook's dark theme on, October 2026, read in a Chromium browser the agent controlled after the owner signed in.
- The same test emails as below. For each message the rendered DOM was read: the `data-og*` marks, the inline styles Outlook wrote, and the computed colours. Every measurement was made with the browser's colour preference emulated as light and as dark, reopening the message after each switch, because Outlook recomputes only when a message is rendered.

### What it does

- It keeps the email's `<style>` block, prefixes the classes with `x_` and scopes every rule under a `.rps_xxx` class. Media queries and attribute selectors survive.
- On every element with a colour it adds `data-ogsb` / `data-ogsc` (and `data-ogab` for a `bgcolor` attribute) holding the original colour, and writes its own colour inline with `!important`. A stylesheet rule therefore never reaches a coloured element, including `[data-ogsb]` descendant rules.
- With the browser preference dark, the email's `prefers-color-scheme: dark` block applies first, and Outlook remaps the result.
- The email body inherited `direction: rtl` from the Hebrew interface; the attributes of `<html>` and `<body>` are dropped, the tables keep theirs.

### Background colours, browser preference light

| Sent | Shown |
|---|---|
| `#FFFFFF` | `#292929`, the reading pane |
| `#FAFAFA` | `#2B2B2B` |
| `#EEEEEE` | `#313131` |
| `#E0E0E0` | `#393939` |
| `#CCCCCC` | `#434343` |
| `#999999` | `#616161` |
| `#666666`, `#333333`, `#202020`, `#141414`, `#000000` | unchanged |
| `#F4F6F5` (tinted) | `#555756` |
| `#0E1110` (tinted) | `#545756` |

Text: `#111814` showed as `#EAF3EE`, `#5E6863` as `#A6B1AC`, `#C42B1C` as `#FF7A5D`, `#9A6200` as `#DD9B43`; the light and bright text samples (`#97A29C`, `#F2F5F3`, `#FF6B61`, `#F0B03F`) stayed as sent.

### The email, before and after

| Email | Preference | Background (pane `#292929`) | Panels | Direction |
|---|---|---|---|---|
| Tinted palette (light `#F4F6F5` panels, dark `#0E1110` / `#171B19`) | light | `#292929` | `#555756` | right to left |
| same | dark | `#545756`, one flat slab | `#535755`, blending in | right to left |
| Neutral palette (light `#EEEEEE` panels, `#E0E0E0` lines; dark `#141414` / `#202020` / `#333333`) and `dir="ltr"` on the tables | light | `#292929` | `#313131` | left to right |
| same | dark | `#141414` | `#202020` | left to right |
| Neutral palette, outer background left transparent in the dark block | dark | `#292929` | `#202020`, darker than the background | left to right |

The neutral palette was then checked on Outlook for Android in dark mode and looked right there too.

### Status tags

Four styles of a 12px tag, each in five tones, on the background and in a panel. Values for the error tone, background colour and text colour as rendered:

| Style | Preference light | Preference dark |
|---|---|---|
| Tinted fill `#F8E0DE`, text `#C42B1C` (dark theme `#3D2220` / `#FF6B61`) | fill `#655250`, muddy | fill `#6E4F4C`, muddy |
| Outline: no fill, 1px border and text `#C42B1C` (dark theme `#FF6B61`) | no fill, border and text `#FF7A5D` | no fill, border and text `#FF6B61` |
| Neutral fill `#EEEEEE` (dark theme `#2A2A2A`), tone text | fill `#313131`, the same as the panel, so the chip disappears there | fill `#2A2A2A` |
| Solid fill `#C42B1C`, white text | fill `#AE0E0C` | fill `#AA1922` |

The other tones behaved the same way: the tinted fills came out as muddy mid tones (`#5C5648` warning, `#4C5951` ok, `#4F5762` info), the outlines kept a clear tone colour. The outline was chosen and then checked in Outlook on the web and on Outlook for Android. A warning banner with a tinted fill came out as a readable brown (`#5C5648` light, `#62553E` dark) and was kept.

## Outlook for Android

### Setup

- Outlook for Android, dark mode, October 2026. The app and OS versions were not recorded; record them in the next measurement.
- Emails sent through the application's own SMTP settings, with a light inline design and a `<style>` block holding `@media (prefers-color-scheme: dark)` with a slightly green-tinted dark palette (`#0E1110` background, `#171B19` panels).
- Colours read as pixel values from direct phone screenshots (JPEG). PNG originals would be more exact. The app background read as `#141414`.

### Background colours

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

### What each attempt showed

| Attempt | Result |
|---|---|
| The original email: light inline colours plus the tinted dark-mode block | Whole email `#4B4D4C`, panels blended in. So Outlook applies the dark-mode block and then remaps it. |
| The same light email without any dark-mode rules | Card `#141414` (white turned into the app background), panels `#4B4D4C`, warning banner brown. Better than the original. |
| `[data-ogsb] .card` rules for the coloured card, with the dark palette | No visible effect on the card: it had no marked ancestor, so the rule did not match it. The panels inside it, which did match, took the tinted dark value and were remapped to the same mid grey. |
| The dark palette set on an inner element without inline colour, under a marked ancestor | Applied, then remapped to the same mid grey. Descendant rules work, but tinted values do not survive. |
| An email dark by design (dark inline colours) | Card `#4B4D4C`: tinted dark colours are lifted to grey even inline. |
| Descendant rules giving white to the outer wrapper and `#202020` / `#333333` to panels and lines | Background `#141414`, panels `#202020` distinct, lines visible, tags and banners readable. This is the fix. |

### Dates

| Written as | Shown |
|---|---|
| `26.10.2026` | the date as a blue link |
| `26.&zwnj;10.&zwnj;2026` | not a link, but the text now holds invisible characters |
| inside a wrapper with `a { color: inherit !important; text-decoration: none !important; }` | not blue |

## Mechanism, from the sources

In dark mode Outlook.com and the Outlook apps add `data-ogsc` (original text colour) and `data-ogsb` (original background) to the elements they recolour, and write the new colour inline with `!important`. A stylesheet rule cannot beat that on the same element. On Outlook for Android a rule for a descendant of a marked element did take effect, and Outlook then passed its colour through the same filter. On Outlook on the web it did not: there every coloured element, descendant or not, gets its own inline `!important` colour, so only the colours the email itself carries count. Class names are prefixed with `x_` in both the HTML and the CSS, so class selectors still match. An attribute joined to a class in one selector is not supported.

## Sources

- Can I email, `prefers-color-scheme`: https://www.caniemail.com/features/css-at-media-prefers-color-scheme/
- Can I email, attribute selectors: https://www.caniemail.com/features/css-selector-attribute/
- Parcel, colour scheme in email: https://parcel.io/guides/color-scheme-in-email
- Rémi Parmentier, Outlook.com dark mode: https://www.hteumeuleu.com/2021/emails-react-outlook-com-dark-mode/
- Litmus, dark mode for email: https://www.litmus.com/blog/the-ultimate-guide-to-dark-mode-for-email-marketers
