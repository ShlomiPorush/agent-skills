---
name: html-communication
description: Create plans, specifications, write-ups, finding summaries, reports, comparisons, and sets of UI mocks as readable self-contained Hebrew HTML documents with correct right-to-left layout. Use when the user asks to communicate through an HTML document or mentions "HTML" without additional context. Do not use for HTML that will ship as part of a product or codebase.
---

# HTML Communication

## Create the document

- Produce exactly one self-contained `.html` file no larger than 512 KB.
- Embed all CSS, JavaScript, icons, and other required assets in that file. Do not create companion files or require runtime fetches.
- Write all visible prose in Hebrew. Set `<html lang="he" dir="rtl">` and make the page direction right to left.
- Implement RTL correctly with CSS logical properties. Isolate English terms, code, URLs, numbers, and other left-to-right fragments with appropriate HTML directionality such as `dir="ltr"`, `<bdi>`, or `<bdo>` when needed.
- Write and structure the document like a practical specification, report, or working artifact. Do not style it as a marketing landing page.
- Choose a readable filename and preserve that same file across iterations.

## Present UI mock options

- Label the options `A`, `B`, and `C` so the user can select one unambiguously.
- Lay out the options side by side for direct comparison. Add responsive behavior within the same file when needed for narrow screens.

## Publish and iterate

- Upload the HTML file to PostPlan when available. Otherwise use an available public file host.
- Preserve the same hosted item and URL across iterations by updating the existing file rather than publishing a new one.
- Return a link to the published document and identify the local HTML file when a local workspace copy exists.
- Do not open a browser to verify the HTML unless the user explicitly asks.
