---
name: html-email
description: Build, change or fix the HTML email an application sends (notifications, alerts, reports, summaries) so it reads well in light and dark mode across mail clients, especially Outlook in dark mode (the Android app and Outlook on the web), and keeps its direction in a right-to-left client; keep client-made date links from turning blue; put a small chart inside an email; and verify all of it with real test sends. Use when a task touches email templates, the email layout code, or a report that email looks wrong in a mail client. Not for web pages, HTML reports or documents, or reading and managing an inbox.
---

# HTML email

Rules for the HTML email an application sends, learned by measuring real clients. The evidence and its limits are in `references/outlook-dark-mode.md`. The test method is in `references/verification.md`. Read both before you change colours.

## First: find what exists

Before you change anything:

1. Find every place that builds email HTML: a shared layout, templates, inline builders. A fix must reach all of them.
2. Find what happens to the HTML after it is built. A CSS inliner or a template engine may drop `<style>` rules, attribute selectors or media queries. Check the final HTML that is sent, not the template.
3. Note the design: a light design with a dark-mode block, dark by default, or no `<style>` block at all. Keep the project's design. These rules fix how clients render it; they do not choose a new design.
4. Note which clients the users read mail in, when the owner knows. The measured facts below cover Outlook for Android and Outlook on the web only.

## Outlook in dark mode

What was measured in October 2026 on Outlook for Android and on Outlook on the web (outlook.office.com), both in dark mode:

- Both recolour the email after its own `@media (prefers-color-scheme: dark)` block has applied. Outlook on the web applies that block when the computer or browser prefers dark, not because of Outlook's own theme.
- **Near-grey tints are flattened.** Surfaces that are almost grey with a faint tint, light or dark (`#F4F6F5`, `#0E1110`, `#171B19`), all came out as one mid grey (about `#4B4D4C` on Android, `#555756` on the web). A palette with such a tint therefore turned the whole email into one flat grey slab, with panels blending into it. Saturated status tints were not flattened: warning and error backgrounds kept a brown and a red.
- **Neutral greys survive.** White became the client's own background (`#141414` on Android, `#292929` on the web). Light neutral greys (R = G = B) were inverted to dark greys. Dark neutral greys (`#333333`, `#202020`, `#141414`, `#000000`) stayed exactly as sent.
- Both mark each element they recolour with `data-ogsb` (background) or `data-ogsc` (text). **Outlook on the web writes its new colour inline with `!important` on every coloured element**, so no stylesheet rule reaches those elements there. On Android, descendant rules under the mark did take effect.

What to do, when an email shows this:

- **Make every surface a neutral grey**, in the inline light colours and in the dark-mode block alike: the background, panels, lines, muted tags, chart bars. This is the fix that reaches Outlook on the web, because there only the colours themselves count. On the measured setup a light panel of `#EEEEEE` and lines of `#E0E0E0`, with a dark block of `#141414` background, `#202020` panels and `#333333` lines, gave a dark email with distinct panels in both Outlooks. Choose the project's own neutral values; the visible change from a faint tint is small, but it is a design change, so show the owner a before and after.
- **Also give Outlook for Android neutral surfaces under its mark**, with descendant rules after the dark-mode block. White on the outer wrapper becomes the app background:

  ```css
  [data-ogsb] .email-bg    { background-color: #FFFFFF !important; }
  [data-ogsb] .email-panel { background-color: #202020 !important; }
  [data-ogsb] .email-line  { border-color: #333333 !important; }
  ```

  Use the project's own class names. The element you style must sit inside a marked ancestor; an element with an inline background is marked, so the `<body>` or an outer cell with a background colour serves. On Android this held even for styled elements with an inline colour of their own: panels with an inline `#F4F6F5` inside the marked body showed the rule's `#202020`. What failed was a coloured element with no marked ancestor:

  ```html
  <body style="background-color:#FFFFFF;">           <!-- Outlook marks this -->
    <table class="email-bg" style="background-color:#FFFFFF;">  <!-- matched -->
  ```

- **Never target the marked element itself**, and never join an attribute and a class in one selector (`[data-ogsb].email-bg`): Can I email lists that as unsupported in Outlook.com and the Outlook iOS and Android apps.
- **Leave status colours alone unless a test shows a problem.** Warning and error tints remapped to a readable brown and red in both clients.
- **Test both system preferences on the web.** Outlook on the web gave different results with the computer set to light and to dark, because the dark-mode block applies only in the second case.

## Direction

An email with no direction of its own takes the direction of the mail client. In Outlook on the web with a Hebrew interface, an English email was shown right to left: labels on the wrong side, the full stop at the start of a sentence.

- Declare the email's direction on the `<html>`, the `<body>` **and the outer tables** (`dir="ltr"` for a left-to-right email, `dir="rtl"` for a right-to-left one). Outlook on the web drops the attributes of `<html>` and `<body>` but keeps the tables'.

## Links the mail client adds

Outlook and Gmail turn dates, and sometimes times, phone numbers and addresses, into links of their own. On the device a plain `26.10.2026` became a blue link.

- **Client-made links take the text colour.** On the outermost wrapper: `.email-bg a { color: inherit !important; text-decoration: none !important; }`. Measured: the date stopped looking like a link.
- **Links the app makes keep their look on purpose.** That rule also reaches them. Give every intended link its underline inline with `!important`, and its colour inline with `!important` when it must differ from the text around it. Check the contrast in light and dark mode.
- **Addresses are a separate case.** If the project already wraps addresses in links with an explicit colour (because Outlook ignores `color: inherit` on its own address links), keep that, and make that colour inline with `!important` so the rule above cannot replace it with `inherit`. The date measurement does not justify removing it.
- Do not insert zero-width characters into dates. It worked, but a copy-paste then carries invisible characters.
- Do not rely on `<meta name="format-detection" content="date=no">` to stop Outlook date links; there was no evidence it helps. Keep format-detection settings the project already has for other reasons.

## A chart inside an email

- **Bars are table cells,** not an image or SVG. SVG does not display in Gmail or Outlook. A PNG does not follow dark mode, and clients often block images. Cells use the same classes as the rest of the email.
- **The Word recipe (Outlook for Windows):**
  - one row of percentage-width cells, each holding a nested table with a spacer cell above the bar cell;
  - heights as both an attribute and a style (`height="37" style="height:37px"`);
  - `font-size:1px;line-height:1px;mso-line-height-rule:exactly` on spacer and bar cells;
  - colours as both a `bgcolor` attribute and inline;
  - `table-layout:fixed`, the whole-number share in the `width` attribute and the exact share in the style.

  This recipe was not checked on Outlook for Windows for the chart itself. Test it.
- **Scale and edge cases:** the tallest bar is about 80px. A non-zero value gets at least 2px. Zero gets a 1px line so the axis reads. An empty or all-zero series must render without dividing by zero. Escape every label.
- **Colours:** use a neutral grey for ordinary bars, so the Outlook apps keep it. The highlight colour depends on meaning: the error colour fits the window of an alert, not every highlight. Give both dark-mode and `[data-ogsb]` rules.
- **Words as well as bars:** put `aria-hidden="true"` on the bar table and add a caption that says the same in words ("39 in the last hour, usually 0.6 an hour"). Label the axis start and end in the app's time zone. Add the date when the start is on another day, and the zone when daylight saving changed in between.
- **The data must match what the email is about.** Count with the producer's own filters and time bounds. If an alert counts without an upper time bound, so does its chart, or log lines dated ahead of the clock appear in one and not the other.
- **A failed chart never costs the email.** Read the chart data so that its failure cannot undo or block the alert: a separate read, or a savepoint, that fits how the project handles transactions. Do not roll back work that belongs to the producer (the alert record, deduplication state). Send the email without the chart and log why.
- Leave the plain-text part and other channels (webhooks, chat) as they were, unless the task asks otherwise.

## Verify on real clients

A change to email colours or links is done only when a real send was seen on the client it targets. The steps are in `references/verification.md`:

- a browser simulation of Outlook proves nothing;
- ask the owner before sending test emails through the project's mail settings, and send only to the addresses the project already notifies, or to ones the owner gives;
- send one email with numbered variants, and a calibration email of labelled swatches;
- for Outlook on the web, read the rendered message directly in a browser you control, with the owner signed in by the owner: its DOM, the `data-og*` marks and the computed colours, with the browser preference set to light and to dark;
- for a phone app, read the pixel values from a direct screenshot;
- send a final email from the real code;
- get the owner's look before the pull request.

Tests that pin the exact CSS rules and the chart output must fail on the old code.

When you report, name each client: what was seen on a real device, and what was not tested. As of the measurement, these were not tested: Outlook for iOS, Outlook.com with a personal account, Outlook on the web in its light theme, Outlook for Windows, the Gmail apps, and Apple Mail with the neutral palette or a chart.
