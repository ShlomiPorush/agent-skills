# agent-skills

Personal [Agent Skills](https://code.claude.com/docs/en/skills) that work with both **Claude Code** and **Codex**. Each skill is a folder with a `SKILL.md` file (`name` + `description` frontmatter) — the shared format both tools understand.

## Skills

| Skill | What it does |
|---|---|
| [`file-pr`](file-pr/SKILL.md) | Reviews the current Git branch and files a concise, review-ready pull request that follows the repository's contribution rules — without merging or deploying. |
| [`html-communication`](html-communication/SKILL.md) | Presents plans, specs, reports, and UI mock comparisons as self-contained Hebrew HTML documents with correct right-to-left layout. |

## Install

Clone the repo, then link every skill into the agent-specific skill folders (`~/.claude/skills/` and `~/.codex/skills/`):

```powershell
git clone https://github.com/ShlomiPorush/agent-skills
cd agent-skills
pwsh ./install.ps1
```

The script creates a directory junction per skill (Windows, no admin rights needed), so both agents read straight from this repo. On macOS/Linux, create symlinks instead:

```bash
for skill in */; do
  ln -sfn "$PWD/$skill" ~/.claude/skills/"$skill"
  ln -sfn "$PWD/$skill" ~/.codex/skills/"$skill"
done
```

## Updating

Edit a skill here (or through the linked folder — same files), then commit and push. On other machines, `git pull` is enough. After adding a **new** skill folder, rerun the install step once to link it.

## Layout

```
agent-skills/
  <skill-name>/
    SKILL.md            # instructions + name/description frontmatter
    agents/openai.yaml  # optional Codex display metadata
  install.ps1
```

## License

[MIT](LICENSE)
