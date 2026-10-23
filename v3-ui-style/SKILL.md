---
name: v3-ui-style
description: Only for projects that adopted the mailcow Logs Viewer v3 style. Use it only when the project's AGENTS.md or CLAUDE.md says its UI follows v3-ui-style, the mailcow Logs Viewer v3 style or the v3 style or look, or the user asks for that design in this conversation. In any other UI task do not use it, do not open it and do not mention it. Being installed or listed, or a screen that resembles an admin or mail UI, is not adoption. Holds the v3 design rules, behaviors and bundled code.
---

# v3 UI style

## First: check that this design was adopted

Apply this skill only when one of these is true:

- a user instruction in this conversation asks for this design: `v3-ui-style`, the mailcow Logs Viewer v3 style, or the v3 style or look;
- the AGENTS.md or CLAUDE.md that applies to the files you change says the UI follows one of those.

Before you announce that you use this skill or read anything under `references/`, name the user instruction or quote the project line that adopts the design. If there is none, stop here and build the UI in the project's own design, or as the request asks. These are not adoption: the skill being installed or listed, a README or screen that looks like an admin or mail UI, a product version that happens to be called v3, and a mention made only to describe, review or exclude this skill.

## About the style

The design system of the [mailcow Logs Viewer](https://github.com/ShlomiPorush/mailcow-logs-viewer) v3 frontend: a dense, flat admin UI where the text colour is the accent and colour means status. The look is half of the style; the other half is how things behave. This skill holds both as rules, plus the v3 code they were taken from.

## When it applies

- A project adopts the style with one line in its AGENTS.md or CLAUDE.md, for example "UI follows the `v3-ui-style` skill." In such a project every UI task uses this skill.
- Precedence, highest first:
  1. The target project's own design system, domain and decisions: its names, endpoints, statuses, languages and wording.
  2. "Do not copy" in the principles file.
  3. The principles file.
  4. The area rules.
- The rules describe v3, an admin UI for a mail server. Adopt the behavior and its values; adapt the names, endpoints, fields and domain values to the target project.
- Decisions that are part of the style, even where a common default differs:
  - Animations stay when the system asks for reduced motion; add no reduced-motion override (AX-8).
  - The copy icon shows on hover only, on pointer devices; copying works by click or tap without it (FB-12).
  - A click outside closes only windows without typed input, and only when the press started outside. A window with typed input asks "Discard your changes?" before it drops a change (DS-9).
  - An action the server can take back by a receipt (dismissing alerts) acts at once and offers Undo instead of asking first; DS-20 lists what still asks first and what acts on one click without Undo (FB-16, DS-20).
  - Every hover style is gated by `@media (hover: hover)`; focus styles are not, and a tooltip that is the only way to read a value stays reachable by tap (MO-4).
  - Dates and times follow the Date Format and Time Format the user picks (by default the browser's date order and the 24-hour clock), always as numbers without month names, and go through one set of format helpers that a test keeps every page on (FW-9).
- Two items are still open in v3 itself: results shown only in colour on some buttons, and a visual order that differs from the DOM order; and the Copy button on a selected log line, reached with a mouse only (LD-14). Build both right from the start.

## How to read

1. Read `references/v3-design-principles.agents.md` fully: core rules, tokens with CSS, type scale, layout, components, copy, behavior principles, signature behaviors, the interaction rules, "Do not copy", the pitfall index and the checklist.
2. Choose area files from the table below by what the screen contains, not only by its page type. Read each chosen file fully. Do not load all sixteen at once.
3. When a rule names a rule of another area by ID (for example "AX-7") and your screen uses that part, read that rule too. The prefix gives the file.
4. Some rules end with a part marked "Before the interaction fixes (history ...)". Where it differs from the first part, the first part is the rule; details the first part does not cover still hold.
5. Open the bundled code only when a rule is not enough. `references/v3-code/README.md` says how its `file:line` references resolve and what is not included.

All area files are in `references/behaviors/`.

| Prefix | File | Read when the screen has |
|---|---|---|
| DS | `DS-dialogs-and-sheets.md` | a dialog, phone sheet, confirmation or any layer over the page |
| TB | `TB-tables-and-lists.md` | a table or list, sorting, rows that open |
| FS | `FS-forms-settings-and-secrets.md` | a form, a settings page, a secret or password, sign in |
| SV | `SV-saving-validation-and-refresh.md` | anything the user edits and saves, or data that refreshes |
| SR | `SR-search.md` | a search box or a global search |
| MP | `MP-menus-pickers-and-popovers.md` | a menu, dropdown, date or value picker, popover or tooltip |
| NL | `NL-navigation-layout-and-routing.md` | a new page or tab, navigation, page state in the URL, Back and Forward |
| LD | `LD-live-data-and-logs.md` | polling, live updates, logs |
| FB | `FB-feedback-loading-and-empty-states.md` | loading, empty and error states, toasts, click to copy |
| FW | `FW-formatting-and-wording.md` | numbers, dates, times, labels, messages |
| CH | `CH-charts.md` | a chart |
| MO | `MO-mobile.md` | phones in scope |
| AX | `AX-accessibility-and-motion.md` | always |
| RT | `RT-rtl-and-i18n.md` | always: right to left, languages, user text |
| EM | `EM-email.md` | email the app sends |
| OT | `OT-other.md` | patterns from single v3 pages (message details, DMARC records, dashboards); skim the rule titles |

Common starting sets, before adding what the screen contains:

- Any new page: AX, RT, FB, FW and NL; MO when phones are in scope.
- Settings page: add FS, SV, DS and MP.
- Data table page: add TB, SR and MP; LD when it refreshes; DS when a row opens a dialog.

## Done

- Work through the checklist at the end of the principles file. It is the done gate.
- Check the result in the running app: light and dark, desktop, the rail range up to 1100px and a phone up to 760px, and right to left when the project supports it.
- Report which checklist items you did not verify and which rules of the areas you read you dropped on purpose, with the reason.
