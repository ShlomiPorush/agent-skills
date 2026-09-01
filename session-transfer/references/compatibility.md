# Session compatibility reference

Use this reference only when a user asks whether a particular session can be resumed or moved. Session behavior changes by product version, account, storage mode, and working directory, so verify the current official page if a command is not listed here.

## Matrix

| Source to target | Direct ID resume? | Safe guidance |
|---|---|---|
| Claude Code CLI to Claude Code CLI | Conditional | `claude --resume <SESSION_ID>` or `/resume <SESSION_ID>`. The target needs the same accessible local transcript store and project/worktree context. |
| Claude Code local CLI to Claude web | No by ID alone | Local CLI transcripts are not automatically web sessions. Export a handoff or use a supported shared/cloud workflow. |
| Claude web/cloud to Claude Code CLI | Conditional, via Claude flow | Use `claude --teleport <SESSION_ID>` for a supported cloud session. This is different from local `--resume`. |
| Codex interactive to Codex interactive | Conditional | `codex resume <SESSION_ID>`. The session is local or tied to the configured backend; working-directory differences may require a choice, and `--all` broadens selection. |
| Codex exec/SDK to Codex exec | Conditional | `codex exec resume <SESSION_ID>` or `--last`; use the exec command for an exec session. `--include-non-interactive` may be needed when listing/selecting. |
| Codex interactive to Codex exec, or reverse | Do not assume | Confirm the recorded session type and the current CLI version. If uncertain, use a handoff packet. |
| Claude Code to Codex, or Codex to Claude Code | No | Session IDs and transcript formats are not interoperable. Transfer decisions and artifacts, not the ID. |

"Conditional" means that an ID is only useful after access and scope are verified. It is not a share token. The ID does not transport the working tree, tool permissions, approvals, environment variables, or secrets.

## T3 Code and Codex IDs

An ID copied from a T3 Code UI can be a T3 wrapper or conversation identifier rather than the Codex rollout identifier. For Codex local sessions, verify the native ID against the first `session_meta` record in the relevant JSONL file (`payload.session_id` and `payload.id`) and the `rollout-...-<id>.jsonl` filename. This mapping is an observed local-format check, not a documented T3 API. If the copied UI ID is not present in Codex session metadata, do not pass it to `codex resume`; use T3's own flow or request the native ID and a handoff.

T3's server state may contain an explicit provider mapping in `~/.t3/userdata/state.sqlite`. For a local, authorized lookup, query the exact T3 thread row and parse `provider_session_runtime.resume_cursor_json.threadId`; the bundled `scripts/resolve_t3_session.py` performs this read-only lookup. In one verified local example, the T3 thread ID resolved to the Codex rollout ID in that cursor. This is a T3 implementation detail, not a public cross-machine API, so validate the result against the provider's native session metadata. Do not parse or mutate T3's LevelDB/cache as a resolver, and do not infer a mapping when the cursor is absent.

On Windows, use `scripts/resolve_t3_session.ps1`, which calls the system `winsqlite3.dll` and requires no Python, Node, or `sqlite3` installation. The Python helper remains an optional alternative where Python is already available.

## Official documentation

- Claude Code session management: https://code.claude.com/docs/en/sessions
- Claude Code cloud teleport: https://code.claude.com/docs/en/claude-code-on-the-web
- Claude Code CLI reference: https://docs.anthropic.com/en/docs/claude-code/cli-usage
- Codex CLI developer commands: https://developers.openai.com/codex/cli/reference/
- Codex CLI overview: https://developers.openai.com/codex/cli/
- T3 upstream issue documenting `~/.t3/userdata/state.sqlite` provider cursor state: https://github.com/pingdotgg/t3code/issues/3604

Last checked: 2026-09-01.
