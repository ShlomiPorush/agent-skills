# agent-skills

Personal [Agent Skills](https://code.claude.com/docs/en/skills) that work with both **Claude Code** and **Codex**. Each skill is a folder with a `SKILL.md` file (`name` + `description` frontmatter), the shared format both tools understand.

## Skills

| Skill | What it does |
|---|---|
| [`cross-review`](cross-review/SKILL.md) | Brings a partner agent from the other model provider into T3 Code to review plans and results, by risk tier. A bundled PowerShell gate reads only the usage limits from T3's cache and says whether the partner's quota allows a review. |
| [`file-pr`](file-pr/SKILL.md) | Reviews the current Git branch and files a concise, review-ready pull request that follows the repository's contribution rules, without merging or deploying. |
| [`html-communication`](html-communication/SKILL.md) | Presents plans, specs, reports, and UI mock comparisons as self-contained Hebrew HTML documents with correct right-to-left layout. |
| [`html-email`](html-email/SKILL.md) | Builds and fixes the HTML email an application sends so it reads well in light and dark mode, including dark mode in the Outlook app and Outlook on the web, keeps its direction in a right-to-left client, keeps client-made date links from turning blue, puts small charts inside an email, and verifies everything with real test sends. Backed by measurements on real clients. |
| [`project-map`](project-map/SKILL.md) | Draws and updates a self-contained Hebrew HTML map of the project: its main parts, the status of each part with evidence, blockers, progress toward the next milestone, open decisions, and the recommended next step. A bundled PowerShell script embeds the fonts and validates every map before it is reported. |
| [`session-transfer`](session-transfer/SKILL.md) | Classifies session IDs for same-platform resume and routes cross-platform moves through a safe handoff packet. For T3 IDs, its Windows resolver uses the system `winsqlite3.dll`; Python is not required. |
| [`v3-ui-style`](v3-ui-style/SKILL.md) | Replicates the mailcow Logs Viewer v3 design system in another project: the look as tokens and component rules, and 234 behavior rules in 16 area files (dialogs and phone sheets, tables, forms, saving, search, navigation and more). The v3 frontend code the rules cite is bundled for reference. |

## Third-party skills

`install.ps1` also links a curated subset of [mattpocock/skills](https://github.com/mattpocock/skills), cloned as a **sibling** of this repo (never vendored, so upstream updates arrive with a `git pull`):

| Skill | Why it's here |
|---|---|
| `grilling` + `grill-me` | Relentless interview that closes every design branch before any code is written. |
| `diagnosing-bugs` | Disciplined debug loop with instrumentation, instead of guess-and-retry. |
| `handoff` | Compacts a long conversation into a handoff document (written to the OS temp dir). |
| `prototype` | Throwaway prototype answering one design question: a single HTML file or UI variations. |

Edit the `$externalPaths` list in `install.ps1` to change the selection.

## Install

Clone both repos as siblings, then link every skill into the agent-specific skill folders (`~/.claude/skills/` and `~/.codex/skills/`):

```powershell
git clone https://github.com/ShlomiPorush/agent-skills
git clone https://github.com/mattpocock/skills mattpocock-skills   # optional
cd agent-skills
pwsh ./install.ps1
```

The script creates a directory junction per skill (Windows, no admin rights needed), so both agents read straight from the source repos. It links only directories that contain a `SKILL.md`, so non-skill folders are ignored. On macOS/Linux, create symlinks instead:

```bash
for skill in */SKILL.md ../mattpocock-skills/skills/*/{grilling,grill-me,handoff,diagnosing-bugs,prototype}/SKILL.md; do
  [ -e "$skill" ] || continue
  dir=$(cd "$(dirname "$skill")" && pwd)
  ln -sfn "$dir" ~/.claude/skills/"$(basename "$dir")"
  ln -sfn "$dir" ~/.codex/skills/"$(basename "$dir")"
done
```

## Updating

Edit a skill here (or through the linked folder, same files), then commit and push. On other machines, `git pull` is enough. After adding a **new** skill folder, rerun the install step once to link it.

## Layout

```
agent-skills/
  <skill-name>/
    SKILL.md            # instructions + name/description frontmatter
    agents/openai.yaml  # optional Codex display metadata
  reports/              # generated HTML write-ups (git-ignored, never linked)
  install.ps1
```

## License

[MIT](LICENSE)
