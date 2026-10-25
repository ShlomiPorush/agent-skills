# UI design rules (v3 style)

Instructions for coding agents building or changing UI. Derived from the mailcow Logs Viewer v3 design system (its stylesheet is bundled in this skill at `references/v3-code/assets/css/ui.css`). Follow these rules unless the project's own design system overrides them.

Two parts: this file (look, layout, components, copy, behavior principles, process, checklist) and the behavior rules in `references/behaviors/`, one file per area (every behavior as a rule with exact values). Read this file fully, then the area files for what you build (the skill's SKILL.md maps tasks and ID prefixes to area files); the look without the behaviors is not the style. Paths in these files are relative to the skill folder.

## Core rules

1. **The accent is the ink.** No brand colour. Primary buttons, active chips, active tabs and the active nav item use the text colour (near black in light, near white in dark).
2. **Colour means status, never decoration.** Green = ok, amber = warning, red = failure, pink = spam (or one domain specific category), blue = info and focus; v3 also gives mail direction three colours of its own (`--ui-dir-in`, `--ui-dir-out`, `--ui-dir-int`). Do not add colour for any other reason. No purple.
3. **Flat surfaces.** A panel is set apart from the page by a tinted background, not by a border or shadow. Shadows only on floating layers (popover, menu, toast, dialog).
4. **Dense on purpose.** Body 14px, controls 34px high, 14px gap between blocks. Admin screens show a lot of data.
5. **Strong type contrast.** Large heavy page title, small quiet body, large numbers for key figures.
6. **Nothing disappears without an explanation.** A control that needs something missing (API key, permission, setting, disabled feature) is replaced by a locked area that says what is missing, why it matters, and links to where it is set.
7. **Direction aware by default.** Logical CSS properties only. RTL must work without a separate stylesheet.

## Tokens

Define every visual value as a CSS custom property with one project prefix. Light theme on `:root`, dark theme on `.dark` on `<html>`. Components never use raw hex, font sizes or spacing values outside the tokens.

Starting values (neutrals have a slight green tint; keep them, replace status colours with the new domain's statuses):

```css
:root {
    --ui-font: 'Onest', 'Noto Sans Hebrew', system-ui, sans-serif;
    --ui-mono: 'IBM Plex Mono', 'Noto Sans Hebrew', ui-monospace, monospace;

    --ui-fs: 14px;
    --ui-fs-sm: 12.5px;
    --ui-h1: 28px;
    --ui-radius: 12px;
    --ui-radius-sm: 8px;
    --ui-pad-y: 9px;
    --ui-pad-x: 16px;
    --ui-gap: 14px;
    --ui-ctl-h: 34px;

    --ui-bg: #FFFFFF;
    --ui-panel: #F4F6F5;
    --ui-raise: #FFFFFF;
    --ui-ink: #111814;
    --ui-muted: #5E6863;
    --ui-line: #E3E7E5;
    --ui-accent: #111814;
    --ui-on-accent: #FFFFFF;
    --ui-focus: #1F5FBF;

    --ui-ok: #12803F;
    --ui-warn: #9A6200;
    --ui-fail: #C42B1C;
    --ui-spam: #A62A63;
    --ui-info: #1F5FBF;
}

.dark {
    --ui-bg: #0E1110;
    --ui-panel: #171B19;
    --ui-raise: #0E1110;
    --ui-ink: #F2F5F3;
    --ui-muted: #97A29C;
    --ui-line: #262C29;
    --ui-accent: #F2F5F3;
    --ui-on-accent: #0E1110;
    --ui-focus: #7DB3FF;

    --ui-ok: #3FCF7F;
    --ui-warn: #F0B03F;
    --ui-fail: #FF6B61;
    --ui-spam: #F07FB0;
    --ui-info: #7DB3FF;
}

:root { color-scheme: light; }
.dark { color-scheme: dark; }
```

- Status tints: derive backgrounds from the status colour with `color-mix(in srgb, var(--ui-ok) 14%, transparent)` (12 to 15%). This works in both themes without extra tokens.
- Dark status colours are lighter and more saturated than light ones. Give every status colour a separate dark value; check contrast in both themes.
- Prefix every component class (`ui-`) so it cannot collide with utility classes during a migration.

### Type scale

Define this scale as tokens and do not add sizes outside it.

| Level | Size | Weight | Letter spacing | Use |
| --- | --- | --- | --- | --- |
| H1 | 28px | 800 | -0.035em | Page title, line-height 1.1 |
| Key figure | 22 to 26px | 750 | -0.02em | KPIs and stats |
| Item title | 19px | 700 | -0.01em | Title in a detail view |
| H2 | 16px | 650 (dialog and sheet titles 700) | -0.01em (dialog and sheet titles 0) | Dialog and section titles |
| Panel title | 15px | 650 | 0 | Panel header |
| Body | 14px | 400 | 0 | Default text |
| Control | 13px | 600 (chips 500) | 0 | Buttons and chips |
| Small | 12.5px | 600 | 0 | Labels, table headers |
| Meta | 12px | 500 to 700 | 0 | Time, tags, second lines |

- Fonts are self hosted (no CDN), woff2 split by `unicode-range`, `font-display: swap`, licence files shipped next to them. Use a Latin font plus a Hebrew font in one stack so mixed text falls back automatically. Use a mono font for addresses, IDs, IPs and hashes at 0.9em. If only some weights of the mono font ship, declare the heaviest file for the weights above it (`font-weight: 500 900`), so a mono value in bold text keeps its real letters instead of a bold the browser fakes (RT-3).
- Every number in a column, KPI, counter or time uses `font-variant-numeric: tabular-nums`.

### Spacing, radius, depth

| Token | Value | Use |
| --- | --- | --- |
| `--ui-pad-x` | 16px | Horizontal padding of every row and panel |
| `--ui-pad-y` | 9px | Vertical padding of a row |
| `--ui-gap` | 14px | Gap between blocks on a page |
| `--ui-ctl-h` | 34px | Field and button height (small button 28px, chip 30px) |
| `--ui-radius` | 12px | Panel, table, banner, dialog |
| `--ui-radius-sm` | 8px | Button, field, log line |
| fixed | 6px / 999px | Status tag / chip and switch |

Depth has three levels only: none (page and panels), floating (`0 12px 32px rgb(0 0 0 / .14)` on the popover; v3's row menu `0 8px 24px` at .14, toast `0 10px 30px` at .16 and nav flyout `0 12px 32px` at .18 are near variants, so pick one), modal (`0 24px 60px rgb(0 0 0 / .25)` over a 45% black backdrop).

## Layout

- **The browser never scrolls.** The app frame is `100dvh`; each page scrolls inside it. A page with a header, tabs and filters marks one scroll region so the header stays in place.
- **Shell breakpoints:**

| Width | Navigation | Counters | Content padding |
| --- | --- | --- | --- |
| above 1100px | 240px sidebar: brand, status card, labelled groups, tools at the bottom | Number in an amber or red tag | 22px top, 28px sides |
| 761 to 1100px | 72px icon rail, no labels, flyout names on hover | 8px dot | 22px |
| up to 760px | 56px top bar with blur, 64px bottom tab bar, every other page in a "More" bottom sheet | Red pip; the Needs attention bell in the top bar | 16px top, 12px sides |

- Active nav item: full accent fill plus `aria-current="page"`, not a coloured line.
- Nav counters appear only when there is something to act on; colour follows severity.
- Phone: add `env(safe-area-inset-bottom)` to the tab bar and the bottom padding; sheets open above the tab bar; touch targets at least 44px.
- **Page structure:** H1 with a help button beside the title and a one line muted description under it, page actions aligned to the bottom on the opposite side; then tabs and filters; then a column of panels with `--ui-gap`. Two column dashboards use `minmax(0, 1.9fr) minmax(260px, 1fr)`.
- **Narrow screens reorder by priority, not by DOM order.** Collapse columns (`display: contents`) and move "needs attention" first with `order`.
- **List, detail views:** three panes (filters 212px, list 300 to 380px, reading pane) from 1280px; below 1280px the filters become picker buttons above the list; below 1000px the reading pane goes away, the list stands alone and an item opens as a dialog (a sheet on phones). On wide screens open the first item automatically and mark the open row.
- Phones: the page scrolls as one, tabs become sticky; secondary filters fold behind a "Filters" button (search, Apply and Clear stay); inputs use 16px font so iOS does not zoom; actions move under the text, aligned with the text column.

## Components

Build every page from a small component set. Add a new component only when no existing one fits.

- **Panel with rows** is the base unit: `--ui-panel` background, 12px radius, no border, no shadow. Header: 15px/650 title, muted count beside it, an underlined "more" link on the far side. Rows are separated only by a 1px top border. Lists, tables, key value facts and alerts all use this shape.
- **Table:** CSS grid with a per table `--ui-cols`; muted 12.5px header; cells truncate with ellipsis and show the full value in a tooltip; numbers align to `end`; minimum width 560px with horizontal scroll, or stacked rows on phones.
- **Key value row:** muted label at the start, value 650 weight at the end.
- **Alert row:** 4px status colour bar, text, one action.
- **Item with status:** 3px status edge on `border-inline-start`; the ok edge at 55% opacity so healthy rows stay quiet.
- **KPIs:** large number over a muted label; draw cell lines with `outline` so an incomplete last row leaves no grey block.
- **Meter:** 6px high, colour by threshold.
- **Buttons:** default has a `--ui-line` border that darkens to muted on hover. At most one primary (accent fill) per area. Danger is red text (`.ui-btn-danger`); a red fill (`.ui-btn-danger-solid`) is kept for bulk deletes and for the confirm button of a destructive question. Icon button 34x34, no border.
- **Tag vs chip:** a tag shows status (6px radius, 12px/700, not clickable). A chip is a filter (pill, 30px high, small count inside, active state in `aria-pressed`). Never mix the two.
- **Fields:** 34px, `--ui-bg` background even inside a panel, accent border on focus, muted 12.5px/600 label above.
- **Tabs:** 2px accent underline on the active tab, others muted; scroll sideways instead of wrapping.
- **Switch** (not a checkbox) for turning a feature on; mirror the knob with a `[dir="rtl"]` rule.
- **Popover:** anchored with `inset-inline-start`, 320px wide, never off screen. Row "More" menus are popovers so a table cannot clip them. On phones they stay popovers, clamped inside the screen (MP-5, MP-7); the phone bottom sheet is for dialogs, row details and help (DS-1 to DS-4).
- **Dialog:** up to 1100px wide and 90% high, fixed header with title and X, scrolling body, the actions in a foot. Every dialog built in code comes from one builder that needs a width (460, 680 or 1100px) and a close function for its X; a dialog written in the HTML keeps the same frame, the few layers that differ are listed with a reason, and a test fails on a dialog, sheet, menu, picker or toast made any other way (DS-24). On phones every dialog is a bottom sheet that opens at 80% and grows with the scroll (DS-1); it reaches full screen without radius only by growing, except a live log, which opens at full height at its end (LD-2).
- **Confirm:** same dialog frame without an X; the confirm button is red only for destructive actions; Escape, Cancel and on a phone a pull down all cancel; say what will happen and how many items are affected.
- **Toast:** bottom end corner (above the tab bar on phones), 4px status edge, one at a time (a new one replaces the current one), closes after 4 seconds but waits while the pointer or the focus is on it and then keeps at least 1.5 seconds; errors `role="alert"`, others `role="status"` (FB-2).
- **Save bar:** one floating save bar per editable page, shown only with unsaved changes, hidden with its page or tab.

### States: no area is ever blank

- **Loading:** 24px spinner with a short muted sentence. Never show stale data without an indicator.
- **Empty:** one bold factual sentence about what is missing, a muted line under it.
- **Locked:** dashed border, lock icon, title, what is missing and why, and a button to where it is set.
- **Banner:** page level notice in the status colour on a 12 to 14% tint; title coloured, body in ink.

## Data

- **The status text is the status; colour only reinforces it.** Map every status to a tone in one central table and render it through one helper. Do not add a check mark or cross when the tone already says it.
- In tight spaces use an icon with an accessible name and a tooltip with the full message.
- **Thresholds are fixed and documented** (example: pass rate green from 95%, amber from 80%, red below; storage amber above 75%, red above 90%).
- Thousands separators on every count (`toLocaleString()`); a network's size stays a plain figure, since a separator there changes with the browser's language (FW-3).
- Times in the application's configured time zone, not the browser's, written by one set of helpers in the date and time formats picked in Settings (24-hour clock by default, numbers instead of month names); a page never formats a date itself, and a test enforces it (FW-9). In lists: time only for today, day and month earlier this year, the whole date before.
- IDs, addresses and IPs in mono and **click to copy**: faint background and copy icon on hover; copies the full value (not the truncated one); the icon turns into a check for 1.5s; a toast says "Copied: <value>".
- **Every count is a link** to the list it counts, filtered exactly.
- **User content keeps its own direction:** `dir="auto"` on the element and the text wrapped in `<bdi>`. Hex colours and other values that start with a neutral character also need an LTR isolate inside RTL text.
- Escape everything that comes from the server. Country flags are local PNG images, never emoji (Windows shows flag emoji as two letters).
- **Charts:** prefer simple CSS bars over a chart library when they suffice. Two meaningful colours at most (clean in ink, bad in fail). A chart is a filter: clicking a bar selects it and dims the others to 30%. Sparse time axis: label every third bar, hide minor labels on phones.

## Motion, interaction, accessibility

- Motion explains a state change and nothing else. Default 0.15s ease (chevrons, switches, grip, background colour); 0.12s for tooltips and flyouts; 0.2s ease for sheet and dialog movement (0.2s ease-out for the phone More sheet); 2s flash on a search target. Full inventory in AX-8. Animations are part of the design: they stay when the system asks for reduced motion (the owner turns animations off in the operating system and still wants them in the app), so add no reduced-motion override.
- Hover: 4 to 6% accent tint on clickable rows only. Gate every hover style behind `@media (hover: hover)` so tapped items do not stay grey (v3 gates all of them, Tailwind included); split a rule that also styles `:focus-visible`, and leave ungated a tooltip that is the only way to read a value, so a tap shows it. The copy icon appearing on hover is a hover cue on purpose; do not show it all the time.
- State lives in ARIA, not only in classes: `aria-pressed`, `aria-current`, `aria-expanded`. Style by the attribute.
- Every page, tab, open item and filter is reflected in the URL so it can be bookmarked, shared and reloaded. Old URLs redirect to the matching screen.
- Persist preferences in `localStorage` (v3 keeps the theme, the collapsed nav and the log viewer's newest-first order). A table's header sort lives in memory: it survives refreshes, not page loads (TB-3).
- There is no Refresh button: the open page updates by itself, at a pace that fits how often its data changes (30 seconds for most pages, a minute or five minutes for slower data), draws only what changed, and never moves an open item or redraws what the user works in (SV-10, SV-6, SV-13). It runs only while its page is open and stops when leaving; a hidden browser tab reads nothing and catches up once when shown; a read that fails keeps what is shown. Needs attention is the exception: it refreshes on every page, for the header bell (NL-19).
- Focus: `:focus-visible` with a 2px `--ui-focus` outline and 2px offset. Escape closes the topmost floating layer only, and Back does the same at every width, the phone back gesture included (DS-8, DS-10); a confirm dialog puts the focus on its confirm button, so Enter confirms, but a question that drops work (Discard, Leave) or picks between outcomes puts it on the safe button, so Enter keeps the work; arrow keys move through menus and flyouts.
- RTL: only logical properties (`margin-inline-start`, `padding-inline-end`, `inset-inline-start`, `border-inline-start`, `text-align: start | end`). Add an explicit `[dir="rtl"]` rule only for things that do not flip by themselves (`translateX` of a switch knob, a directional chevron, a side inset shadow). Test full RTL in the browser; the source project was English only.

## Copy

- Page description: the question the page answers, in plain words ("Who tries to get in, what stops them, and what is waiting for you").
- Subtitles with data count what there is and what needs action.
- Locked area: what is locked, what is missing, where to set it, with the full path using arrows ("Settings → Mailcow → Connection") and a button.
- Success toast: what happened, with the value ("IP 1.2.3.4 added to the allowlist"). Error toast: what failed, then the server's reason.
- Action names are verbs (Release, Check now, Fetch reports), never "OK" or "Submit". Panel titles are short nouns (Needs attention, Blocked senders).
- Numbers instead of vague words ("3 need a DNS change", not "some domains have issues").
- One term per concept everywhere; a repeated sentence is one shared constant.
- No exclamation marks, no emoji. Quiet and factual.
- In a redesign, keep the existing wording of toasts, confirmations and empty states unless a change is decided.

## Behaviors

The look is half of the style; the other half is how things behave. These rules record the micro-interactions of v3: how sheets open and grow, what Escape and Back close, what survives a refresh, how search moves under the keyboard. Many took several iterations to get right. Replicate them, not only the tokens.

**Every behavior has a full rule in the area files under `references/behaviors/`** (234 rules in 16 areas, with exact values, keyboard and screen reader behavior, the pitfalls from earlier attempts and v3 code references). Before building or changing a dialog, sheet, table, form, search, menu, live view or navigation, read the area's file. This chapter holds what applies everywhere: the principles, the signature behaviors, the interaction rules v3 follows since its fixes and what not to copy.

### Behavior principles

1. **Locked, not hidden.** A control that cannot work stays and says what is missing and where to set it. (FB-1, FS-7, SV-5)
2. **Nothing is lost in a rebuild.** Every id, handler and gated state of the old screen is kept, verified with an inventory and a catalog check. (OT-7, FS-9, FS-11)
3. **Never redraw what someone is working on.** Timers and background refreshes skip open windows, unsaved changes, focused fields and selected text in the part they would redraw, checked again when the answer arrives; when they do redraw, the focus, the row in view, checked rows and open rows stay; sheets keep their scroll; new lines and new mail never take away a text selection or the reader's place, they are offered at the edge instead. Prefer a narrow guard to one that blocks real updates. (SV-6, SV-13, DS-7, TB-10, TB-12, FS-16, MP-2, LD-2, LD-14, LD-15)
4. **Back closes the thing on top, and no press is wasted.** Escape does the same on desktop. (DS-10, DS-8)
5. **Everything has an address.** Tabs, sections, nested levels and old addresses; when an address names nothing, correct it instead of stacking a new history entry. (NL-3, NL-4)
6. **A number is the rows a click on it shows.** Counts follow the search and filters, come from the server when the client holds only part of the data, and are tested against each other. (TB-18, CH-2, TB-17, OT-10)
7. **No data is not bad data.** "-" instead of 0%, "No mail in the last 30 days", "Not checked yet", since when the data starts, and unknown is never reported as "not enabled" or as a made-up 0: a source that did not answer says Unknown. (FB-8, FB-9, LD-12)
8. **One shared component per behavior.** Locked area, save bar, sheet, picker, filter bar and the count helper are each built once and reused; a new page says "like Messages" instead of inventing a variant. Every popup comes from the builder of its kind or keeps its frame in the HTML, the few that differ are listed with a reason, and a test fails on any other. (OT-2, FB-1, SV-1, DS-2, MP-1, TB-17, FW-3, DS-24)
9. **Remove friction.** Whole rows and whole switch rows are clickable; fields are editable at once without an Edit mode; a pick from a list is added at once and closes its panel; the page reloads only when it must; a secret is asked for only when the user starts replacing it or changes its server; an action the server can take back acts at once and offers Undo instead of asking first. (TB-8, FS-1, SV-1, FS-15, MP-1, SV-4, FS-3, FS-5, DS-20, FB-16)
10. **Wording.** Say what happened and what to do next; plain verbs for actions ("Fetch reports", "Ban 1w"); correct singular and plural ("1 entry"); names that cover what a setting really does; help titles as words; drop hints that only explain the page; email subjects without emoji; short tooltips. (FW-7, FW-8, FB-3, FB-4, SV-5, SV-12, FW-3, RT-4, EM-5, MO-6)
11. **Problems first, and open where they are handled.** What needs a look is reachable from every page through the header bell. (TB-11, NL-12, FB-10, NL-19)
12. **Phones get their own layout; wide screens stay unchanged.** Phones fold secondary content behind buttons with a badge, put the main action on the title line, turn tables into lists and leave out what is said elsewhere. (MO-6, MP-6, NL-14, TB-14, MO-7, MO-9)
13. **Keep the layout still.** Rows stay while reloading, dialogs open at their top, the sheet grows by exactly the scrolled distance, counts get their own line so filters do not push them, action buttons keep one width, notes hang under their button, and a panel keeps one size whatever its content, period, zoom or a failed load; a list panel grows with its items up to a cap instead of leaving empty space. (TB-5, DS-6, DS-1, TB-17, TB-23, NL-15, FB-17)
14. **Verify the way the user sees it.** Screenshots in light and dark at 1440, 1000 and 390px; pixel comparisons for "unchanged" claims; a recording for anything timing-related; measured panel heights; real Gmail and Outlook sends for email; tests that fail on the old code; and an explicit list of what was not checked. (AX-11, EM-2, EM-3, TB-5, NL-2, FS-1, RT-1)

### Signature behaviors

The behaviors that make the style feel like v3. Short form; the full rule with every value is in the area file for the same ID prefix.

- **Phone sheet grows with the scroll (DS-1).** On phones every dialog is a bottom sheet that opens at `80dvh`. Scrolling first raises the sheet by exactly the scrolled distance, then the content scrolls. At full height the corners square off and the content clears the notch.
- **Drag and pull (DS-3).** Dragging the grip or head up grows the sheet with the finger. Pulling down past `min(120px, panelHeight / 4)` closes it; a shorter pull springs back (`.2s ease`). A pull from the content moves the sheet only when the content is at its top.
- **Grip (DS-4).** A `40x4px` line in a `120x20px` hit area that becomes `56x5px` in ink while held. Add `touch-action: none` to it.
- **Reading gauge (DS-5).** In help and release-notes dialogs the grip plus head fills from the start side with a faint accent tint as the text is read. A text that does not scroll shows no gauge.
- **Fresh opening (DS-6).** Every opening starts at the top, on the first tab. Every close clears the state of that opening.
- **Top layer only (DS-8, DS-10).** Escape and the Back button close only the topmost layer and stay on the page. Closing by hand removes the extra history entry, so the next Back really leaves.
- **Whole toggle row (FS-1).** The whole row of an on/off setting is the `<label>` of its switch.
- **Secrets on demand (FS-3).** A stored secret shows "Stored" with Replace and Remove. The password field appears only on Replace, and an unchanged secret is never sent again.
- **Header sort (TB-1).** Clicking any column header sorts by it: numbers high to low first, text A to Z first, each click reverses. The label is a button (Enter and Space sort); a real column header (`th`) carries `aria-sort`, a div list header says its order in words and draws its arrow from `data-sort-state`; opt out with `data-nosort`.
- **One Sort button per list (TB-28).** Every list whose header row can hide has one Sort button at every size, beside its search or at the end of its header row: a menu with Sort by and Order, worded per column, in one state with the headers; a dot shows an order other than the default.
- **Rows stay while reloading (TB-5).** The current rows stay until the answer replaces them and dim only after `200ms`. A dialog never collapses to a spinner.
- **Open stays open (TB-10, SV-6, SV-13).** Expanded rows, groups and checked rows survive refreshes, and the row in view and the focus stay where they were. A background refresh skips whatever the user is editing, typing in, selecting or has open.
- **New mail at its edge (LD-15).** Messages takes new mail in by itself where it lands (the top, newest first) with every filter; scrolled away it stays put and offers "N new messages" at that edge, like "N new lines" on the Logs page (LD-2).
- **Search keyboard (SR-4).** `/` focuses search. Up and Down move the result while the user keeps typing. Tab switches the result kind once there is a query. Enter opens; Escape closes without closing the dialog beneath.
- **Save bar (SV-1).** No autosave and no Edit mode. A floating bar with "3 unsaved changes", Discard and Save changes appears only while something differs from what was loaded.
- **Zoom in time, with an overview strip (CH-9, CH-10).** A time chart zooms by a drag across bars, Ctrl+wheel or a pinch, and by buttons; a strip under it shows the whole period with a window to drag, resize or move by keyboard (its edges are sliders); every change snaps to the chart's bars.
- **Act, then offer Undo (FB-16).** An action the server can take back, such as dismissing alerts, acts at once and offers Undo for `10000`ms in its toast; the server's receipt makes Undo re-open exactly what that action changed.
- **A calendar of days (CH-12).** One square per day over the data kept, its colour by rate and its strength by volume; one Tab stop with arrows by day and week; time runs left to right in both directions.
- **Needs attention from every page (NL-19).** A bell in the header counts every open item, red, amber or plain by the worst of them, and opens the same list with the same actions: a window under the bell, a sheet on a phone. A check that cannot run keeps what it showed and says so instead of all clear.
- **Dates the user's way (FW-9).** Every date and time goes through one set of helpers that follow the Date Format and Time Format settings; a date cell sorts by its instant, not its text.
- **Click to copy (FB-12).** Every ID, address and IP copies on click, shows "Copied: value" and turns its icon into a check for `1500ms`. Inside a clickable row, copying does not open the row.

### Interaction rules v3 follows since its interaction fixes

These were gaps in v3 until the interaction fixes (October 2026), the layers F to J (#474 to #483) and #484 to #494. v3 meets them now, except where an item says it is still open; build all of them from the start. The full rules are in the area files under the IDs given.

- **Animations stay.** Do not turn them off under `prefers-reduced-motion`: the owner wants them even with the system setting on (AX-8).
- **Hover only with a pointer, everywhere.** Gate every hover style with `@media (hover: hover)`, including utility frameworks, so a tapped button, facet or tab does not stay shaded on touch; keep focus styles ungated and keep a value-only tooltip reachable by tap (MO-4).
- **RTL without exceptions.** Use logical properties for every inset, padding, margin, radius, shadow and position computed in JS. An edge mark drawn with an inset shadow gets an RTL counterpart, a flyout opens toward the side its sidebar is on, and `[dir="auto"]` text aligns with the page (left, or right under RTL). Keep geometry physical where it is geometry: centring by `left: 50%` and `translateX(-50%)`, and charts, which read left to right in both directions (`direction: ltr` on the chart). Check that LTR does not move: compare the bounding box of every element before and after. v3 is English today; it was checked with `dir="rtl"` forced.
- **Header sort reachable by keyboard and on phones.** Make sortable headers buttons that sort on Enter and Space; keep `aria-sort` on a real column header and say the order in words on a div list. Stacked phone tables hide the header row, so every such list gets one Sort button at every size, in one state with the headers; tables in help text do not sort (TB-1, TB-28).
- **Every clickable row is focusable.** Rows, journey headers and list items that open on click get `tabindex="0"`, a role and both Enter and Space; a row that holds controls of its own opens from a chevron button instead, so no control sits inside another (AX-5).
- **Focus management in every dialog and sheet.** Move focus into the dialog or sheet when it opens, keep it inside while open (make the rest `inert` rather than trapping Tab), and return it to the trigger on close. One Escape handler closes only the top layer; every dialog closes on Escape (DS-8, DS-2, DS-12).
- **Complete semantics.** The search input points to its active result with `aria-activedescendant`; dialog tab buttons use `role="tab"`; every dialog has `role="dialog"`; loading blocks have `role="status"`; icon-only controls have an accessible name (a `title` alone counts as one, but an `aria-label` is clearer); a status shown only as a coloured dot has a spoken name.
- **No result only in colour (still open in v3).** Result states on buttons carry text or an icon, not colour alone; keep the visual order equal to the DOM order, or set the reading order explicitly. v3 named its colour-only status dots, but some button result states are still colour only and the dashboard and DMARC reorders still make the visual order differ from the DOM order. The copy icon stays a hover cue (copying works by click or tap anyway).
- **Unsaved changes are protected.** Ask before leaving the page or navigating inside the app with unsaved changes (`beforeunload` plus one guard in the router, Back and Forward included, without changing the history), ask before a typed dialog drops its changes, and check fields on the client, naming the field, before the save round trip (SV-1, DS-9).
- **Login helps the user.** A show-password toggle, a Caps Lock warning and an announced error (FS-23).
- **The router updates `document.title`** for every page and tab, and restores each scrolling area's position on Back and Forward (NL-3).
- **Toasts pause while hovered or focused** (FB-2).
- **One backdrop rule per dialog kind, written down.** Windows without typed input close on a backdrop click, and only when the press started on the backdrop, so a text selection that ends outside keeps the window open; windows with typed input do not close on it (DS-9).
- **A text selection is never an action.** The end of a selecting gesture (a drag, a double click, Shift+click) in a list row never opens the row (TB-8); a click on a log line selects the whole line with a Copy button, and new lines neither scroll it away nor trim it (LD-2, LD-14). Still open in v3: the Copy button is reached with a mouse only.
- **Panels keep one size.** A panel draws its frame before the first answer and keeps its height through every period, zoom, picked item and failed load. A list panel is the exception: it is as tall as its items up to a cap, then scrolls inside with a count line, and at its end the page scrolls on (FB-17).
- **Undo instead of a confirmation where the server can take an action back.** Dismissing alerts acts at once and offers Undo backed by a server receipt; a toast can carry one action and stays while it runs (FB-16, FB-2).
- **One list at a time.** A list that loads more as it scrolls follows a cursor after the last row shown, drops what an older load still had on its way, and lets a failed next page wait for Try again (TB-6, SV-10).

### Do not copy

Problems found in the v3 code at the snapshot `deb075d`. Do not reproduce them. Those marked fixed are correct in the code now; do not "fix" them again.

- **Duplicate top-level function names in classic scripts.** dmarc.js declared `dmarcPolicyTag` twice; the later one won, so the all-domains table showed "Missing" in every row. One name, one function. Fixed: now `dmarcDomainPolicyTag` and `dmarcPolicyTag`.
- **A live update that queries a selector the markup no longer renders.** Live service counts updated through `.font-mono` while the list rendered the count in `<small>` (logs-viewer.js:817 vs 123 at deb075d), so the badges never moved. Query by a data attribute the renderer sets. Fixed: the update now reads `small` (logs-viewer.js:829).
- **Turning auto-scroll back on jumps to the bottom in newest-first order.** Follow must go to the newest line, wherever the order puts it. Fixed by #474: `setLogAutoScroll` goes to the newest edge for the button and for "N new lines" (logs-viewer.js:965-977).
- **A default stated in three places that disagree** (Hide Zero Activity: the fallback is `false` at mailbox-stats.js:332 and `true` at mailbox-stats.js:532, and Reset at mailbox-stats.js:783-785 checks it under a comment that calls unchecked the default; still in the code). Define each default once.
- **UTC written into a `datetime-local` input** with `toISOString().slice(0, 16)` (spam_filter.js:722, 771, 782 at deb075d). Format local time, or the app time zone, for local inputs. Fixed: `toZonedInputValue` (spam_filter.js:984, 1031, 1040; utils.js:538).
- **Overridden rules left in the stylesheet.** v3 keeps an earlier phone rule that makes dialogs full screen, overridden by the sheet rule, and an old content bottom padding superseded by the frame layout. Carry over only the rule that wins.
- **A delivery key built from the wrong capture (at ab0f644, fixed by #491).** The message details mean to resolve Dovecot verdicts per LMTP delivery session, but the prefix regex lost its backslashes and the key takes the user, so two deliveries to one mailbox merge and a store in one cancels a pending discard in the other (message-details.js:598-631). Key each delivery on the session in the line prefix (OT-18); v3 does since #491, so do not "fix" it again.
- **A padding reset that drops the safe-area inset (at 1d4f3e08, fixed by #509).** The message details sheet set its scroller to `padding: 0`, which beat the sheet rule that adds `env(safe-area-inset-bottom)`, so its last line sat under the phone home bar (ui.css:491, 3046). Keep the inset on whatever element scrolls (DS-11); v3 does since #509, so do not "fix" it again.
- **A refresh that draws without comparing.** Status redraws each of its sections on every refresh the guard lets through, also when nothing changed (app.js:5326, 5391, 5706), and the Outbound suppression list and the Dashboard's Security card and system summary are read again and drawn on every refresh, with no check for selected text and without keeping the focus (spam_filter.js:23-34, 527-597; app.js:3315, 3379; still in the code). Compare with what is shown and draw only a change (SV-10).
- **A failed refresh that wipes the last good value.** The Dashboard's blocklist figure turns into "-" with "Could not load" when one refresh fails (app.js:5653-5656), the figures at the top of Status do the same (app.js:5259, 5351, 5452, 5665), and a failed Security overview or suppression list read replaces its list with the error (security.js:82-85; spam_filter.js:591-595; still in the code). Keep the last good value and say it could not be updated.
- **Breakpoint in the history disagrees with the code.** The docked reading pane docks at `min-width: 1000px` in the code; an older PR says 1200px. Use the code value.

### Pitfall index

Browser and platform traps that cost v3 a fix. Check new code against them.

- `overflow: hidden` on a grid child gives it a zero minimum height (NL-2).
- A scroll container's top padding offsets its sticky children; a leftover sticky `top` offset leaves a band (DS-14, NL-16).
- `position: sticky` creates a stacking context that traps dialogs; keep dialogs at body level (DS-15).
- `100vh` is taller than a phone's visible screen; use `dvh` with a `vh` fallback (FS-23, DS-1).
- A phone keyboard pans the window and can leave it panned; `scrollIntoView` pans the frame (MO-1, FS-10).
- Scroll anchoring drags new rows down after a content swap (TB-7).
- A hidden element cannot be scrolled; reset the scroll after showing it (DS-6).
- CSS resets remove list bullets in a new container (DS-19).
- A rule meant for tablets leaks into the phone sheet; hover sticks on touch (NL-9, MO-4).
- The utility `.hidden` must beat component classes, or "Loading..." stays visible after loading (OT-1).
- Underscores in route ids break routing (FS-10, NL-3).
- A negative pull-up margin is cut inside a scroll region (NL-5).
- A grid column grows to its widest unbreakable value; give columns `minmax(0, ...)` (TB-15).
- Row menus inside scrolling tables must be popovers and close on scroll (MP-7, TB-13).
- A hover flyout needs a bridge over the gap, or it closes on the way to it (NL-8).
- A loading spinner that replaces rows collapses and re-expands a dialog (TB-5).
- Stacked phone tables hide the header row, so header sort is unreachable there; a phone-only sort row and separate sort drop-downs then disagree with the headers (TB-1, TB-28).
- A text selection that ends on the backdrop closes the dialog unless the press must start there too (DS-9).
- New live lines scroll a selection away and trim it (LD-2, LD-14).
- Overlapping loads of one list let an old answer replace the new list; offset paging skips or repeats rows when rows come and go (TB-6, SV-10).
- A dialog that stops click propagation breaks shared drop-downs inside it (MP-1).
- Popups built by hand drift apart: an X goes missing, buttons end up inside the scrolling body, sheets draw another X, a log is no sheet on phones; build each through its builder, or its frame where it lives in the HTML, list the exceptions with a reason, and let a test fail on any other (DS-24).
- A long header above a dialog's tabs pushes the content out of reach; scroll header, tabs and content as one with the tabs sticky (DS-14).
- Outlook for Windows: no `max-width`, no padding outside cells, growing VML overlaps, the last row's bottom border is dropped (EM-2).
- The SMTP 998-character line limit breaks HTML mid-tag; send base64 (EM-3).
- `toLocaleString()` on a figure follows the browser's language, so a value a test or a user reads as one number changes ("4.096" or "4,096") (FW-3).
- A date a page formats itself bypasses the user's format and the app's zone; scan for it in a test (FW-9).
- A regex written inside a string or a template can lose its backslashes; test the key it builds against two inputs that must stay apart (OT-18).

## Process

1. Mock the richest data page first and derive the tokens from it.
2. Put tokens and base components in one stylesheet with a class prefix.
3. Before changing an existing UI, catalogue every behavior (click to copy, tooltips, toasts, confirmations, empty and locked states, deep links, keyboard handling) and keep or drop each one on purpose.
4. Redesign one page at a time. A page is done only when every catalogued behavior on it is kept or its removal is recorded in the pull request.
5. Guard with tests: an inventory of pages, actions and fields against a baseline; every editable setting has a place in the UI; no external script, stylesheet, font or image.
6. Verify each layer in the running app, in light and dark, at desktop, rail and phone widths.

## Checklist for every new page

- [ ] No hex value, font size or spacing outside the tokens
- [ ] Colour appears only as status, focus or direction
- [ ] Loading, empty and error states exist for every area
- [ ] Every control that depends on a permission or setting is replaced by a locked area with an explanation and a link
- [ ] Checked in light and dark, including native controls and charts
- [ ] Checked at 1280px and up, in the rail range (up to 1100px) and on a phone (up to 760px)
- [ ] Phone: actions under the text, secondary filters folded, 16px inputs, 44px touch targets
- [ ] Logical properties only; user values have `dir="auto"`
- [ ] Numbers use tabular figures and thousands separators (a network's size excepted, FW-3); dates and times use the app time zone and go through the format helpers
- [ ] IDs and addresses in mono with click to copy
- [ ] Page state is in the URL
- [ ] All assets (fonts, libraries, images) are served locally
- [ ] Focus visible from the keyboard; focus moves into a dialog or sheet and returns to its trigger
- [ ] Escape and Back close only the top layer and leave no extra history step
- [ ] Phone dialogs are sheets that open at 80% (a live log at full height, at its end), grow with the scroll, and have a grip and pull to close; a question pulled down cancels
- [ ] Every popup comes from its shared builder (dialog, sheet, picker, menu, toast) or keeps the builder's frame in the HTML, exceptions are listed with a reason, and a guard test fails on any other; where a layer has an X it is the shared one
- [ ] Help and long information dialogs have the reading gauge; every opening starts at the top
- [ ] Whole rows are clickable (toggle rows, list rows) and inner controls keep their own click
- [ ] Sortable headers work by click and by keyboard; every list whose header row can hide has one Sort button (documented exceptions aside)
- [ ] No Refresh button: the page updates by itself at a pace that fits its data, reads nothing while the browser tab is hidden, and a read that fails keeps what is shown
- [ ] Refreshes keep rows on screen, keep open and checked items, the focus and the row in view, and never redraw what the user is editing or selecting
- [ ] The end of a text-selection gesture never opens a row or closes a dialog (a plain click still opens a row)
- [ ] Panels keep one size in every state: loading, empty, failed, zoomed; a list panel grows to a cap, then scrolls
- [ ] An action the server can take back offers Undo; DS-20 says what asks first and what acts on one click
- [ ] Animations stay under reduced motion; every hover is gated by `(hover: hover)`, focus styles are not
- [ ] Leaving unsaved changes asks (in the app, on Back and Forward, and through the browser); typed dialogs ask before dropping changes
- [ ] The area's file in `references/behaviors/` was read and every rule there is kept or consciously dropped
