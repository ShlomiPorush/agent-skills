---
name: project-map
description: Draw or update a project map, a single self-contained Hebrew HTML page that shows the project's main parts, the status of each part with evidence, what is blocked and on what, progress toward the next milestone, open decisions waiting on the user, and the recommended next step. Use when the user asks for a project map, project status, progress overview, or "where are we?"; before starting a long autonomous run; and after reaching a milestone. For general plans, reports, or write-ups use html-communication instead.
---

# Project Map

A project map is a living status page for one repository. It answers four questions at a glance: what the project is made of, how far each part has gotten, what is stuck and on what, and what to do next.

## Boundaries

- Write only inside `.project-map/` at the repository root. Never change source, configuration, `.gitignore`, `.git/info/exclude`, issues, or pull requests.
- Read code, Git history, branches, the working tree, the README and other project documents, and open issues and pull requests when a read-only CLI such as `gh` is available.
- Do not run the project's builds, tests, installs, migrations, or servers just to compute status. Use evidence that already exists: commits, files, recorded test results, CI status, issues, and the current conversation.
- Keep the map local. Do not publish or upload it unless the user explicitly asks.
- Check `git check-ignore -q .project-map`. If the folder is not ignored, do not edit any ignore file. Report it and suggest adding `.project-map/` to the repository's `.gitignore`.
- Parts belong to this repository. Other worktrees of the same repository are evidence for the matching parts. Work in another repository that a part depends on appears as that part's `blockedOn` and evidence, not as a part of its own.

## Running it

- If you are already running as a subagent, build the map inline. Otherwise, if the host supports background subagents, delegate the map to one at medium effort so the main session keeps working. If it does not, build it inline and keep it brief.
- Run it before a long autonomous stretch, after each milestone, and when the user asks where the project stands. When the user asks "where are we?", answer from a freshly updated map.
- There is no first-run style interview and no stored style preference. Use the visual rules below.

## Files

```
.project-map/
  state.json   # source of truth for the agent; read before updating, write after
  index.html   # rendered map; opens by double-click
```

`state.json` keeps what must survive between updates:

```json
{
  "version": 1,
  "updatedAt": "2026-01-31T18:00:00Z",
  "lastCommit": "<full SHA of HEAD at the last update>",
  "parts": [
    {
      "id": "auth",
      "name": "Authentication",
      "status": "done | in-progress | not-started | blocked | unknown",
      "summary": "One short sentence",
      "evidence": ["commit abc1234", "tests/auth.test.ts passes in CI run 812"],
      "blockedOn": "What it waits on, when blocked"
    }
  ],
  "milestones": [
    {
      "id": "m1",
      "name": "Public beta",
      "parts": ["auth", "billing"],
      "status": "proposed | approved | reached"
    }
  ],
  "decisions": [
    {
      "id": "d1",
      "question": "Which payment provider?",
      "options": ["Stripe", "Paddle"],
      "recommendation": "Stripe, because ...",
      "blocks": ["billing"],
      "status": "open | answered",
      "answer": null
    }
  ],
  "nextStep": "One concrete action"
}
```

Set `blockedOn` to `null` unless `status` is `blocked`. Preserve user edits. If the user has renamed parts, edited milestones, or answered decisions in `state.json`, keep those changes and build on them.

## Building the map

1. Read the existing `state.json` if it exists. Collect `git log`, `git diff --stat <lastCommit>..HEAD`, `git status`, branches, open issues and pull requests, and the README.
2. Split the project into a small number of main parts, usually 4 to 8, named the way the user would name them. Keep part IDs stable across updates.
3. Give each part one status and cite evidence for it. Use `unknown` when evidence is missing. Never guess a status. A part is `blocked` only when it names what it waits on: another part, an external dependency, or an open decision.
4. Milestones belong to the map. If the user has not named any, propose a first version from the README, commit history, and issues and mark each one `proposed`. Only the user can mark a milestone `approved`. Mark an approved milestone `reached` when every part it lists is `done`.
5. Record product decisions the agent may not make on its own as `open` decisions, with options and a recommendation. Do not pick a default and proceed. Work that depends on an open decision stays blocked, and only independent work continues. A pending merge, review, or release that the user owns is a dependency, not a decision.
6. Choose one concrete next step that does not depend on an open decision.
7. Compare with the previous state to find what changed: new parts, status changes, reached milestones, answered decisions, and the commit range since `lastCommit`. On the first run there is nothing to compare; say that this is the first map, name its baseline commit, and highlight parts with uncommitted changes instead. Uncommitted changes count as evidence for status, but list them separately from the commit range.
8. Write `state.json`, then render `index.html` from it with `/* project-map:fonts */` inside its `<style>` element, and run `embed-fonts`.
9. Run `check`. Fix every reported problem in `state.json` or the page, then run `check` again. Report the map only after it passes.

## Scripts

`scripts/check-map.ps1` runs from the repository root and needs no installs on Windows. On macOS or Linux it needs PowerShell 7 (`pwsh`); if it is missing, ask the user before installing it ([instructions](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)).

- Windows: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-directory>/scripts/check-map.ps1" <command>`
- macOS and Linux: `pwsh -NoProfile -File "<skill-directory>/scripts/check-map.ps1" <command>`

Commands:

- `embed-fonts` replaces the font marker, or a previous embed, in `.project-map/index.html` with the Heebo `@font-face` rules. Never write the base64 by hand.
- `check` validates `state.json` and `index.html` against the rules in this skill. It exits non-zero and lists each problem when something fails.

## The page

Top of the page, always in this order:

- How many parts remain before the next milestone, and which milestone that is. The next milestone is the first approved one that is not reached. If none is approved, use the first proposed one and label it as proposed.
- The recommended next step.
- Open decisions waiting on the user, or a short line saying there are none.
- What changed since the last update, with changed parts highlighted in the part list.

Then the parts, each with its status, one-line summary, evidence, and what it waits on when blocked. Add other panels only when they help this specific project, for example a dependency view, a risk list, or recent activity. Do not use a fixed template.

## Visual and technical rules

- Produce exactly one self-contained HTML file no larger than 512 KB. Embed all CSS, scripts, icons, and data. The page must work from `file://`, so embed the state data in the page and do not fetch `state.json` or anything else at runtime.
- Write all visible prose in Hebrew. Use `<html lang="he" dir="rtl">` and CSS logical properties. Isolate English names, code, paths, commit hashes, and numbers with `dir="ltr"` or `<bdi>` where needed. Evidence items such as commit references, paths, and tool output may stay in their original language.
- Use Heebo for all text, including headings. Create hierarchy with size and weight only. Code, paths, and commit hashes may use a monospace font.
- Embed Heebo from this skill's `assets/fonts/` with `embed-fonts`, which declares the family `"Heebo Variable"`. Use `font-family: "Heebo Variable", Heebo, system-ui, sans-serif`. The fonts are licensed under `assets/fonts/OFL.txt`.
- Support light and dark themes through `prefers-color-scheme`. Use large, confident typography and clear status colors that remain distinguishable without color through labels or icons. Avoid purple.
- Make it readable on a laptop and on a phone.
- Do not use the dash characters U+2010 through U+2015 or U+2212 in visible prose. The Hebrew maqaf is allowed.
- If the `frontend-design` skill is available, load it before rendering. Its guidance applies where it does not conflict with this section, and the map must be correct without it.
- Write it as a working status page, not a marketing page.

## Reporting back

After each update, reply briefly with: the path to `index.html`, whether `check` passed, the next milestone and how much remains, the recommended next step, any open decisions, and whether `.project-map/` still needs to be ignored.
