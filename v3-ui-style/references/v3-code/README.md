# Bundled v3 code

A read-only copy of the mailcow Logs Viewer frontend at commit `8caf6e4` of [ShlomiPorush/mailcow-logs-viewer](https://github.com/ShlomiPorush/mailcow-logs-viewer), the code the behavior rules cite. Files keep their names and their place under `frontend/`, so a rule's `utils.js:939-954` is `references/v3-code/utils.js`, lines 939 to 954, and `ui.css:842` is `references/v3-code/assets/css/ui.css`, line 842.

Use it as a reference, not as a starter kit:

- Start at the cited lines and widen to the whole function and what it calls when you need to. The large files (`app.js`, `ui.css`, `index.html`, `settings.js`) are 135 to 265KB; read them by line range, never whole.
- The code is v3's product code: mailcow pages, endpoints, field names and wording. Take the behavior and the values, not the domain.
- Only the files the rules cite are here: the page scripts, `router.js`, `utils.js`, `index.html`, `login.html` and `assets/css/ui.css`. Not included: the fonts, icons, `assets/css/utilities.css` (a utility class build) and the libraries in `assets/libs/` (Chart.js, marked, DOMPurify, github-markdown-css). `ui.css` and `index.html` load them from `/static/`, so a copy of either does not run as is.
- Fonts: Onest for text, IBM Plex Mono for IDs and numbers, Noto Sans Hebrew for Hebrew in both. All three are open source fonts (SIL Open Font License). Serve them locally in the target project; `ui.css` lines 18 to 58 show the `@font-face` rules v3 uses.
