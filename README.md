# agent-skills

Personal [Agent Skills](https://code.claude.com/docs/en/skills) that work with both **Claude Code** and **Codex**. Each skill is a folder with a `SKILL.md` file (`name` + `description` frontmatter), the shared format both tools understand.

## Skills

| Skill | What it does |
|---|---|
| [`file-pr`](file-pr/SKILL.md) | Reviews the current Git branch and files a concise, review-ready pull request that follows the repository's contribution rules, without merging or deploying. |
| [`html-communication`](html-communication/SKILL.md) | Presents plans, specs, reports, and UI mock comparisons as self-contained Hebrew HTML documents with correct right-to-left layout. |

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
