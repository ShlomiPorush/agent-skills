---
name: cross-review
description: Involve a partner agent from the other model provider in T3 Code to review plans and results, after a budget check of the partner's quota. Use before substantial, risky, or security-relevant work in T3 Code, after bug fixes and medium code changes, when the user says "with partner" or "without partner", or when choosing whether a cross-provider review is needed.
---

# Cross review

One main agent owns the work, the decisions, and the report to the user. A partner agent from the other provider reviews the plan, the result, or both, through T3 Code's `delegate_task`. Partner agreement never replaces the user's approval.

This skill needs an agent running inside a T3 Code thread with the `t3-code` MCP tools. Outside T3, say that cross review is unavailable and continue solo.

## Choose the tier

Risk beats the type of work at every tier.

| Tier | When | Partner does |
|---|---|---|
| Solo | A spot task with limited, clear impact. | Nothing. |
| Review-only | Bug fixes and medium code changes. | Reviews the result. |
| Full | Anything that needs a plan under the "substantial work, plan first" rule. Always, even when tiny: security, auth, migrations, data deletion, irreversible actions, CI or release, public API, and changes to agent instructions or skills. | Reviews the plan, then the result. |

The user's words win over the table: "without partner" means Solo, and "with partner" means at least Review-only.

## Order of work

- Review-only: execute, run the budget gate, partner reviews the result, fix, report.
- Full: write the plan, run the budget gate, partner reviews the plan, revise it, present the revised plan to the user when approval is needed, execute, run the budget gate again, partner reviews the result, fix, report.

Run the gate before every `delegate_task` call, not once per task. Plan and result reviews can be hours apart.

When presenting a revised plan for approval, present the full revised plan, not the changes since the earlier version.

## Choose the partner

Call `orchestrator_capabilities` first. It reports `inheritedProviderInstanceId` (the main agent) and every provider instance with its `driverKind`, models, and options. The partner's `driverKind` must differ from the main agent's. The rule is symmetric.

Pick the partner instance, model, and reasoning level in this order:

1. What the user names in the current request.
2. The default partner for the main agent's provider in the user's own instructions, such as a global `CLAUDE.md` or `AGENTS.md`.
3. Neither exists: list the eligible instances from `orchestrator_capabilities` and ask the user once which one to use. Suggest recording the answer in their instructions.

When the user's instructions name an instance but no model, use the strongest model that instance lists, at `high`.

- Always set the reasoning option explicitly. Defaults differ per model and are often `low`.
- Option ids differ per driver: `reasoningEffort` for Codex, `effort` for Claude. Use the ids that `orchestrator_capabilities` lists.
- If the default instance or model is missing, has `canRunCrossProviderChildTask: false`, or lists constraints, do not pick another account on your own. Tell the user what is unavailable and ask which instance to use, or whether to continue solo.

## Budget gate

The script reads only the `usageLimits` section of T3's per-instance cache, `~/.t3/caches/<providerInstanceId>.json`. It never prints anything else from that file, which also holds account data. Do not open that file yourself.

Run it on Windows (no installs needed):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill-directory>/scripts/check-partner-budget.ps1" -ProviderInstanceId <partner instance>
```

On macOS or Linux, use `pwsh -NoProfile -File "<skill-directory>/scripts/check-partner-budget.ps1" -ProviderInstanceId <partner instance>`.

Replace `<skill-directory>` with the directory that contains this `SKILL.md`. The script prints one JSON object with `result`, `reason`, `providerInstanceId`, `windowId`, `usedPercent`, `resetsAt`, `checkedAt`, and `dataAgeMinutes`.

| `result` | Exit code | Meaning | Action |
|---|---|---|---|
| `go` | 0 | Under 70% used, or the window resets within 72 hours. | Delegate. |
| `ask` | 1 | At least 70% used and the reset is more than 72 hours away. | Ask the user before delegating. Show `usedPercent` and `resetsAt`. Wait for the answer. |
| `unknown` | 2 | The budget could not be verified. | Delegate, and tell the user in one line: budget not verified, with the `reason`. |

Decide on the JSON `result`. If stdout has no JSON object, treat it as `unknown` with reason `no-output`, whatever the exit code. The exception is `invalid-instance-id`, which is a caller mistake: fix the id from `orchestrator_capabilities` and run the gate again.

How it decides:

- It uses the account-wide window: `id` `seven_day` if present, otherwise the only `weekly` window, otherwise the only `monthly` window. More than one candidate gives `unknown`. The session window never decides.
- `go` reasons: `below-threshold`, `reset-soon`. The `ask` reason: `high-usage-far-reset`.
- `unknown` reasons: `file-missing`, `file-unreadable`, `usage-limits-missing`, `checked-at-invalid`, `stale` (cache older than 15 minutes), `checked-at-in-future` (more than 5 minutes ahead of the local clock), `window-missing`, `window-ambiguous`, `used-percent-invalid`, `resets-at-invalid`, `reset-passed`, `invalid-instance-id`, `invalid-now`, `internal-error`.
- The cache is private to T3 and undocumented. A repeated `unknown` usually means T3 changed its format. Report it so the script can be fixed. After changing the script, run `scripts/tests/test-check-partner-budget.ps1` on both PowerShell 5.1 and 7.

## Reviewer prompt

The partner gets only the task text, with no history from this thread. Make every prompt self-contained:

1. The goal and the user's constraints, in a few lines.
2. What to review: the plan text, or the exact diff, such as `git diff <base>..HEAD` or a list of files and commits.
3. Unrelated existing changes in the checkout that are not under review.
4. For every later round: the ledger (see "Findings ledger") and the change since the previous round.
5. Read-only rules: "Do not edit files, commit, push, or run commands that change state. Report only."
6. What to return:
   - Each finding with an id, a severity (see "Severity"), its location, its impact, and the condition under which it fails.
   - Code, tests, guards, or options the goal does not need. Unneeded additions are findings too.
   - Risks, better alternatives, and evidence still needed. Do not ask for approval, ask for problems.
   - What the partner checked and what it did not check.
7. For a sensitive change (see "Severity"): "Look on purpose for defects in rare states: unusual or hostile input, partial failure, retries, concurrency, interrupted runs, old data, and permission edges. For each, describe the failure and a plausible route to it through users, callers, external input, stored data, or supported operations."

## Severity

Every finding has one severity.

| Severity | Meaning |
|---|---|
| `blocker` | The case the change exists for is still wrong, or the change breaks something that worked. |
| `should` | A real defect within the goal that users, callers, or real data will hit. |
| `nit` | Everything else: style, unrelated code paths, defects with no plausible route, small performance costs, extra compatibility. |

`blocker` and `should` are material.

The main agent checks each label against the code. Lowering a partner's material finding to `nit` is a disagreement, not a correction: the ledger keeps the partner's severity with the proposed `nit` beside it, and the finding stays material and `disputed` until the partner or the user accepts the change.

Sensitive changes are security, auth, migrations, data deletion, irreversible actions, CI or release, public API, and instructions or skills that control permissions, dangerous actions, recovery, or review. In a sensitive change, rarity never lowers severity: within the review scope, a defect with a plausible route is `should` or `blocker`, however rare. When the route is disputed, check it once with available evidence, such as code, a test, or a command. If it stays plausible, the finding stays `disputed` under the dispute rule.

## Findings ledger

Keep one ledger per review (plan or result). Give each finding a stable id, such as `P1` in a plan review and `R1` in a result review. A finding raised again keeps its first id. Record for each id the severity, the round that raised it, a one-line summary with its location and failure condition, the fix or response with its evidence, and one status:

- `open`: not handled yet.
- `fixed`: changed, waiting for the partner to confirm in the next round.
- `resolved`: the partner confirmed the fix or accepted the main agent's evidence.
- `disputed`: the main agent disagrees, with evidence such as file and line, a test, or command output.
- `declined`: not done, with a one-line reason. Only for a `nit`, or for an out-of-scope suggestion whose classification the partner accepted. Disagreement about whether a material finding belongs to the goal stays `disputed`.

Later rounds focus on `fixed` and `disputed` ids and the change since the previous round. They still report new material defects within the original review scope, including interactions with the change. They do not repeat a `resolved` or `declined` finding without new evidence.

## Keep the change small

- Fix a finding with the smallest change that resolves it. Prefer a fix that deletes or narrows code over one that adds a helper, option, lock, or cache.
- Decline a suggestion that adds behavior beyond the goal, in one line. Propose it as a follow-up only when it has value beyond this change. The user decides.
- In a sensitive change, fixing a reachable rare-state defect within the review scope is part of the goal, not scope growth. That includes regressions and interactions the change causes. An unrelated defect that existed before follows the out-of-scope rule above.
- In a result review, treat `git diff --shortstat <base>` before the first round and after each round of fixes as a signal. When the change grew, remove additions the goal does not need before the next round, and tie the remaining growth to ledger ids. Necessary fixes and tests may grow the change.
- Do not accept a finding only to end the loop.

## Delegation mechanics

- Use a new `delegate_task` call for each round, with `role: "review"`, `mode: "async"`, and `target` set to the partner `providerInstanceId`, `model`, and `options`. End the turn after the call. The completion notification wakes this thread, so do not poll.
- Give each round its own `clientRequestId`, such as `<task-slug>-plan-r1` or `<task-slug>-result-r2`. Reuse it only to resend the same call when its response was lost.
- Never continue a review by sending to the returned `childThreadId`. A new round is a new `delegate_task` call.
- Review in the shared checkout. `isolation: "worktree"` does not copy uncommitted edits. Do not edit files while a review runs.
- Leave `runtimeMode` unset. It is not a read-only switch, and the read-only rules belong in the task text.

## Rounds and disagreement

- Round budget per review (plan or result): up to 3 at the Review-only tier, up to 5 at the Full tier.
- The review ends when every material finding is `resolved`, `declined`, or escalated under the dispute rule below, and no behavior-changing fix waits for review. Otherwise start another round while budget remains. Mentioning an `open` or `fixed` finding to the user is not escalation, and an escalated finding blocks the affected work until the user decides.
- A fix changes behavior when it changes code paths or data, or, in instructions and skills, what an agent does, may do, or decides. Purely editorial fixes need no new round.
- A dispute exchange is the main agent's reply with evidence, plus the partner's verdict on it in the next round. A material finding still disputed after two exchanges goes to the user with both positions, two or three lines each. Do not spend more rounds on it alone.
- When the round budget runs out, stop delegating. Send every material finding that is neither `resolved` nor `declined`, and every behavior-changing fix the partner has not reviewed, to the user for a decision. Running out of budget is never an automatic approval.
- The main agent decides what to fix. A material disagreement that stays open goes to the user with both positions before the work is called done.

## Partner failure

- Whenever this thread wakes while a review is still running (a user message, another notification), call `task_status` for it. The task is stuck when it has run for more than 30 minutes without a result, or when it waits on a pending question that the reviewer prompt should have answered.
- Cancel a stuck task with `task_cancel` and retry the round once with a new `clientRequestId`, such as `<task-slug>-plan-r1-retry`.
- If the retry also fails, tell the user and let them decide whether to continue solo.
- Never silently drop to a lower tier, and never start a second review task while one is still running.

## Report

The final message is the only one the user is sure to read. It must stand alone: a user who skipped every earlier message, including the plan, the partner's reviews, and the round updates, must understand the whole outcome from it. Restate each point instead of referring back ("as above", "see round 2").

Write it in plain language, as one person explaining to another: short sentences, no jargon, and a technical term only where no plain word does the job. Explain what a finding means for the user, not only its id.

Order:

1. Outcome: what changed and what it does now, in a few lines.
2. Verification: what was checked and how, and what was not checked.
3. Decisions for the user: every escalated or disputed finding with both positions in two or three lines each, and every proposed follow-up.
4. Leftovers: uncommitted files, skipped checks, manual steps.
5. Review summary, kept short: tier, partner instance and model, gate result, number of rounds, change size before and after a result review, and the ledger as a table (id, severity, status, one-line summary with the fix or reason).
