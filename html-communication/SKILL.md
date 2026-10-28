---
name: html-communication
description: Create plans, specifications, write-ups, finding summaries, reports, comparisons, and sets of UI mocks as readable self-contained Hebrew HTML documents with correct right-to-left layout. Use when the user asks to communicate through an HTML document or mentions "HTML" without additional context. Do not use for HTML that will ship as part of a product or codebase.
---

# HTML Communication

## Create the document

- Work with two files: an editable source, such as `plan.src.html`, and the published file built from it, such as `plan.html`. Choose readable names and keep both across iterations.
- The published file is one self-contained `.html` file no larger than 512 KB. Embed all CSS, images, and icons. Do not create companion files or require runtime fetches.
- Do not use JavaScript, event handler attributes, forms, frames, `<link>`, or remote resources. YAAPS rejects them. Use CSS-only patterns such as `<details>` when the reader needs to expand something.
- Embed images as base64 data URLs of PNG, JPEG, WebP, GIF, or AVIF. Put SVG inline as `<svg>` markup, not as a data URL.
- Write all visible prose in Hebrew. Set `<html lang="he" dir="rtl">` and make the page direction right to left.
- Implement RTL correctly with CSS logical properties. Isolate English terms, code, URLs, numbers, and other left-to-right fragments with appropriate HTML directionality such as `dir="ltr"`, `<bdi>`, or `<bdo>` when needed.
- Write and structure the document like a practical specification, report, or working artifact. Do not style it as a marketing landing page.

## Visual style

Every document shares one look. Start each new source from a copy of `assets/document.html` in this skill's directory.

- Keep its tokens, fonts, and component classes. Build new components in the same idiom, with the `doc-` class prefix and the `--doc-` tokens.
- The accent is the ink color itself. Use the status tones (`doc-ok`, `doc-warn`, `doc-fail`, `doc-info`) only for status, and always with a word, never color alone.
- Separate surfaces by background tone, not borders. Use hairline rules only between rows.
- The theme follows the reader's system setting through `prefers-color-scheme`. Do not add a manual theme switch.
- The template is a component library, not an outline. Keep the order the content needs, use only the components it calls for, and delete the rest, including the template's comments.
- For reports and findings, lead with the verdict and end with the decisions that need the user and what was not verified.
- Put prose inside `.doc-text`. Its typography applies only there.

## Present UI mock options

- Label the options `A`, `B`, and `C` so the user can select one unambiguously. Mark the recommended option with `doc-rec` and say so in its title.
- Lay out the options side by side for direct comparison. Add responsive behavior within the same file when needed for narrow screens.
- Put each mock in a `.doc-figure` with a `.doc-frame`, as a sibling of `.doc-text` and never inside it. The frame belongs to the document; the mock inside shows the product's own design, with its own scoped class names. Set `dir` and `lang` on the mock's root element to match the product.
- Mocks are static. Controls such as `<button disabled>` may appear, but no script and no forms.

## Build and check

Run the bundled script from any directory. It needs no installs on Windows. On macOS or Linux it needs PowerShell 7 (`pwsh`); if it is missing, ask the user before installing it.

- Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-directory>/scripts/doc.ps1" <command>`
- macOS and Linux: `pwsh -NoProfile -File "<skill-directory>/scripts/doc.ps1" <command>`

Resolve `<skill-directory>` to this skill's installed directory and keep it quoted.

1. `embed-fonts <source> <output>` writes the published file from the source, replacing the `/* html-communication:fonts */` marker with the embedded fonts. It never writes the source. Never write the font data by hand.
2. `check <output>` checks the published file for the size limit, RTL root, embedded fonts, and the constructs YAAPS rejects. Fix every reported problem in the source, then run both commands again.

`check` is a pre-flight, not the YAAPS validator. It does not verify full HTML parsing, CSS validity, or nesting depth. If YAAPS still rejects the file, fix the problem it reports and publish again.

## Publish and iterate

- Publish the checked file through YAAPS using the `yaaps` skill. Do not upload it to any other host.
- The first publish creates a draft; note its draft ID and public URL. On later iterations publish a new version to that same draft with `--draft-id` so the public URL stays stable.
- Return the draft's public URL and identify the local HTML files when a local workspace copy exists.
- Do not open a browser to verify the HTML unless the user explicitly asks.
