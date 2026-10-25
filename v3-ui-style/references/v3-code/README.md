# Bundled v3 code

A read-only copy of the mailcow Logs Viewer frontend at commit `72e43c4` of [ShlomiPorush/mailcow-logs-viewer](https://github.com/ShlomiPorush/mailcow-logs-viewer), the code the behavior rules cite. Files keep their names and their place under `frontend/`, so a rule's `utils.js:939-954` is `references/v3-code/utils.js`, lines 939 to 954, and `ui.css:842` is `references/v3-code/assets/css/ui.css`, line 842.

Use it as a reference, not as a starter kit:

- Start at the cited lines and widen to the whole function and what it calls when you need to. The large files (`app.js`, `ui.css`, `index.html`, `settings.js`) are 135 to 330KB; read them by line range, never whole.
- The code is v3's product code: mailcow pages, endpoints, field names and wording. Take the behavior and the values, not the domain.
- Only the files the rules cite are here: the page scripts, `router.js`, `utils.js`, `index.html`, `login.html`, `authorize.html` and `assets/css/ui.css`, plus two guard tests under `tests/`. Not included: the fonts, icons, `assets/css/utilities.css` (a utility class build) and the libraries in `assets/libs/` (Chart.js, marked, DOMPurify, github-markdown-css). `ui.css` and `index.html` load them from `/static/`, so a copy of either does not run as is.
- Fonts: Onest for text, IBM Plex Mono for IDs and numbers, Noto Sans Hebrew for Hebrew in both. All three are open source fonts (SIL Open Font License). Serve them locally in the target project; `ui.css` lines 18 to 58 show the `@font-face` rules v3 uses.

## The guard tests

`tests/` holds two of v3's CI tests, from `.github/tests/` in the same commit. They keep a rule true for every new page, so add the same kind of test to the target project:

- `tests/popups.test.cjs` fails on a popup built outside the shared builders (DS-24).
- `tests/page-refresh-coverage.test.cjs` fails on a page that has no refresh of its own and no reason listed for it (SV-10).

They run with `node --test` and need no packages. They are v3's code: adapt them, do not copy them as they are.

- Paths: both read the frontend at `path.join(__dirname, '../../frontend')`. Point them at the target project's source.
- What they read: the popup test reads every `.js` file directly in that folder (not subfolders), `index.html` and the one stylesheet `assets/css/ui.css`. The refresh test runs `utils.js`, `router.js` and `app.js` in a `vm` sandbox with a stub DOM, then compares the pages in `TAB_LABELS` with the refreshes they registered (`pageRefreshers`); it also fails on a refresh registered for no page. A project with `src/` folders, TypeScript or JSX components, or several stylesheets needs the file list and the patterns changed, or popups and pages go unchecked.
- Allowlists: `BUILDERS` (file and function), `STATIC_LAYERS` (ids in the HTML), `FLOATING_CSS` (selectors) and `NO_REFRESH` (pages) name v3's builders and exceptions, each with its reason. Replace them with the project's own, and keep a reason on every entry. The test that every listed entry still exists keeps the lists honest.
- CI: run them in the project's CI with its other unit tests (v3 runs `node --test .github/tests/*.test.cjs`).
- Proof: keep the self-tests that add one bypass each and expect the check to catch it. After adapting the paths, add one bypass of the project's own (a dialog written by hand in a page script) and see the test fail before you rely on it. The self-tests write a copy of the frontend to `os.tmpdir()`.
