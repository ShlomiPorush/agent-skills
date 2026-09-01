---
name: session-transfer
description: Handle an agent session ID or a request to continue work in another agent. Classify same-platform resume versus cross-platform handoff before attempting any session command.
---

# Session transfer

Use this skill when a user supplies a session ID (often a UUID such as `de31dd36-06a4-4ae8-8fb4-2f32b1a582dd`), asks to move work to another agent, or asks for a second opinion on an existing session.

## First response: classify, do not guess

Treat a session ID as an opaque, platform-scoped pointer. Do not spend a turn trying to decode it, searching arbitrary files, or running a resume command before identifying the source platform and surface.

### T3 Code IDs are a separate case

When the ID was copied from a T3 Code UI context menu, do not assume it is the Codex rollout ID. T3 may expose its own wrapper, conversation, or UI identifier. The Codex-native ID is the `session_id`/`id` in the first `session_meta` record of the matching Codex JSONL rollout, and normally also appears in the `rollout-...-<id>.jsonl` filename. Do not infer a mapping between the two UUIDs. Use T3's own reopen/share flow for a T3 ID, or obtain the Codex-native ID from the platform's session UI or authorized local session metadata.

Do not rely on undocumented T3 LevelDB/cache files as a resolver. A raw occurrence of the T3 UUID there can be UI state, a project index, or cached content and does not establish a relation to a Codex rollout. Never match IDs by timestamp, filename proximity, or text similarity.

T3 desktop/server installations may persist an explicit provider cursor in `~/.t3/userdata/state.sqlite`. This resolver is T3-only; never run it for a bare Claude or Codex ID. On Windows, use the dependency-free PowerShell helper [scripts/resolve_t3_session.ps1](scripts/resolve_t3_session.ps1). On systems with Python, [scripts/resolve_t3_session.py](scripts/resolve_t3_session.py) is an optional alternative. Both read `provider_session_runtime.resume_cursor_json.threadId` for the exact `thread_id`; neither scans transcripts or mutates the database. Treat a missing or stale cursor as no mapping, and verify the returned native ID against the provider's own session metadata before resuming.

Classify the request in this order:

1. Identify the source and target: Claude Code or Codex, and CLI, IDE, desktop, web, or SDK/exec where relevant. Infer only when the surrounding context makes it explicit.
2. Decide whether the target can access the same session store or remote backend. A UUID alone does not grant access and does not carry the transcript, files, credentials, approvals, or working directory.
3. If the platform or surface is unknown, say so immediately and ask for the missing platform (one short question). In the meantime, offer the handoff packet below instead of attempting a resume.
4. If this is cross-platform, state that direct resume by ID is unsupported and switch to a text/artifact handoff.

Never claim that a session was opened unless the platform command actually ran and reported success. If it fails, report the exact scope mismatch or missing local/remote session and fall back to a handoff.

## The old session does not need to run this skill

The receiving agent can apply this skill as soon as the user gives it the ID. Do not tell the user to first invoke the skill in the old session.

- If the receiver has access to the same platform session store, it can attempt the documented resume command itself. The old agent does not need to produce a new message first.
- If the old session has exhausted credits, is crashed, or cannot accept another turn, direct resume may still be useful for reading/continuing only if the platform and account permit it. Do not promise that opening it bypasses usage limits.
- If direct resume is unavailable, the ID alone is insufficient. Ask for an existing handoff, exported transcript, repository artifacts, commits, diff, or other context the user can provide. Do not ask the unavailable old agent to generate a handoff.
- Reading local session files or exporting a transcript is a fallback only when the user explicitly authorizes it and the relevant platform stores them locally. Treat those files as sensitive and do not search arbitrary directories.

## Compatibility rules

Use the detailed matrix in [references/compatibility.md](references/compatibility.md) when the user needs a platform-specific answer. The short version:

- Claude Code CLI to Claude Code CLI can resume with `claude --resume <SESSION_ID>` only when the receiving environment can see the same local Claude session store and project context. A different machine, `CLAUDE_CONFIG_DIR`, account, or unrelated project may not have the transcript.
- Claude web/cloud sessions use the Claude-specific teleport flow (`claude --teleport <SESSION_ID>` where supported). Do not present `--resume` as a way to pull an arbitrary local session into the web app.
- Codex interactive sessions use `codex resume <SESSION_ID>`; `--all` affects selection across working directories. Codex exec sessions use `codex exec resume <SESSION_ID>` (or `--last`), and interactive and exec commands must not be treated as interchangeable without checking the session type.
- Claude and Codex do not share a session-ID namespace or transcript format. Claude ID to Codex and Codex ID to Claude are never direct resume operations. Use a handoff packet, committed artifacts, or an exported transcript instead.
- Same-company does not automatically mean same-session: different products, clients, accounts, machines, config directories, repositories, and local versus cloud storage can each break direct resume. Verify the specific surface and scope.

These rules describe documented behavior, not a promise that future CLI versions will keep the same flags. For a current command or an unfamiliar surface, consult the official documentation linked in the reference before advising the user.

## Handoff mode

When direct resume is unavailable, ask the sender to provide or generate a compact handoff. Do not require the receiver to reconstruct the entire transcript. Prefer an artifact in the repository or a temporary redacted Markdown file over pasting sensitive logs into chat.

Use this packet shape:

```markdown
# Session handoff
- Source: Claude Code | Codex
- Surface: CLI | IDE | desktop | web | exec/SDK
- Session ID: <optional, for same-platform lookup only>
- Repository and working directory: <path or URL>
- Branch and commit: <branch>, <commit>
- Objective: <one sentence>
- Status: <what is complete and what is not>
- Decisions and constraints: <bullets>
- Files or artifacts changed: <paths>
- Verification: <commands and observed results>
- Next action: <one concrete action>
- Risks or open questions: <bullets>
```

The receiving agent should read the packet, inspect the current workspace and Git state, and continue from the stated next action. It should not infer missing approvals, secrets, or requirements from the session ID. Redact credentials, tokens, private user data, and unnecessary transcript content.

## Second-opinion and exhausted-usage cases

For a second opinion, preserve the original session and create a fork/branch when the platform supports it. Claude Code supports `/branch` or `--fork-session`; Codex supports `codex fork <SESSION_ID>` (and `/fork` from an active chat). If the goal is only review, share the relevant diff, tests, and handoff packet instead of opening the original session concurrently.

When usage is exhausted, do not promise that switching accounts or providers will preserve context. A new account may not have access to local transcripts, and a different provider requires the handoff packet. Preserve progress in files, commits, or an export before switching.
