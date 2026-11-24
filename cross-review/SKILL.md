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
| Full | Anything that needs a plan under the "substantial work, plan first" rule. Always, even when tiny: security, permissions, migrations, data deletion, and irreversible actions. | Reviews the plan, then the result. |

Never send a change to this skill, or to the user's rules for review tiers and escalation, to the partner for review.

The user's words win over the table: "without partner" means Solo, and "with partner" means at least Review-only.

## Order of work

- Review-only: execute, run the budget gate, partner reviews the result, fix, report.
- Full: write the plan, run the budget gate, partner reviews the plan, revise it, present the revised plan to the user when approval is needed, execute, run the budget gate again, partner reviews the result, fix, report.

Run the gate before every `delegate_task` call, not once per task. Plan and result reviews can be hours apart.

A Full-tier plan states the simplest design that delivers the required behavior, and lists every mechanism that goes beyond it, each with its real route to failure. A mechanism is something such as an extra state file or copy, a lock, a flag, a retry, a journal, a backup, or a state the user can get stuck in.

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
   - Risks, better alternatives, and evidence still needed. Do not ask for approval, ask for problems.
   - What the partner checked and what it did not check.
7. Always: "For each finding, say whether a simpler design would remove the whole class of problem, and describe it. Prefer that over a guard." In a plan review, also: "Check the plan's list of mechanisms beyond the simplest design. Flag each one without a real route to failure, and each mechanism the plan adds but does not list." For a sensitive change (see "Severity"), also: "Look for defects in rare states that real users, callers, external input, or stored data can reach: partial failure, retries, concurrency, interrupted runs, old data, and permission edges. For each, describe the concrete route. A case with no such route is a `nit`."
8. In the simplicity pass only (see "Rounds and disagreement"), a simplicity section: "Propose only removals, never new code, guards, or tests. The one exception is restoring comment text, as below. Judge by concept, not by line. Report a mechanism or a piece of user friction, such as a dead-end state, that the goal does not need, when removing it drops the whole concept. Report a helper, parameter, or similar small item only when it sits in lines this change wrote. Report code that still handles a case the ledger closed as an accepted risk. Report comments that this change added, or left in the code it touched, and that break this rule: <the user's comment rule, or by default: no comments in code, tests and doc comments included, except text that a tool or a license requires there, and one line that says what would break, when the code looks like a mistake, changing it would break something, no test would fail, and no name can say it; comments may explain settings in configuration files, environment files, and a script's settings section>. Report deleted comment text that the rule allows and whose code stays, and propose restoring only that text. Mark each finding as inside or outside the area this change touches."
9. Always: "A tracked working value for a secret-like setting, such as a password, key, token, signing or encryption secret, or connection string with credentials, is a `blocker`, whatever its label (fake, dev-only, test, not a secret), its binding (loopback only), or its claimed impact. A file elsewhere that does the same is not a precedent."
   When the plan or diff sets up or changes a runtime, development, test, or CI environment, or touches secret-like settings, also: "Check that it says how the stack gets each secret. Treat a gap in that, or a breach of any of the following, as a `blocker`: environment files are tracked only as examples; secrets come from a cryptographically secure random generator, in development once into an ignored owner-only file that is never overwritten, and in test and CI for each run; credentials for external services come from a secret store; the stack refuses to start when a secret is missing or equals a placeholder; a value that was ever committed is public and is never reused, even after it moves to an ignored file, and the user is told it must be replaced wherever it is still in use."

## Severity

Every finding has one severity.

| Severity | Meaning |
|---|---|
| `blocker` | The case the change exists for is still wrong, or the change breaks something that worked. |
| `should` | A real defect within the goal that users, callers, or real data will hit. |
| `nit` | Everything else: style, unrelated code paths, defects with no concrete route, small performance costs, extra compatibility. |

`blocker` and `should` are material.

The main agent checks each label against the code and may lower it with one line of evidence. The ledger keeps both labels.

Sensitive changes are security, permissions, migrations, data deletion, and irreversible actions. In a sensitive change, a rare defect is `should` or `blocker` when it has a concrete route through normal use, a realistic mistake, or hostile input. A case without such a route is a `nit` in any change. The main agent judges the route.

## Findings ledger

Keep one ledger per review (plan or result). Give each finding a stable id, such as `P1` in a plan review and `R1` in a result review. A finding raised again keeps its first id. Record for each id the severity, the round that raised it, a one-line summary with its location and failure condition, the fix or response with its evidence, and one status:

- `open`: not handled yet.
- `fixed`: changed, waiting for the partner to confirm in the next round.
- `resolved`: the partner confirmed the fix or accepted the main agent's evidence.
- `disputed`: the main agent disagrees, with evidence such as file and line, a test, or command output.
- `declined`: not done, with a one-line reason. Only for a `nit`, an out-of-scope suggestion, or a fix that the fix ladder rejects. The main agent decides, and partner consent is not needed.

Later rounds focus on `fixed` and `disputed` ids and the change since the previous round. They still report new material defects within the original review scope, including interactions with the change. They do not repeat a `resolved` or `declined` finding without new evidence.

## Fix ladder

For every material finding, take the first step that resolves it:

1. **Redesign so the case cannot happen.** Change the flow, the data model,
   or the default so the failing state no longer exists.
2. **Narrow or delete.** Remove the code path, option, or state that
   produces the failure.
3. **Accept the risk.** When no real user, caller, or stored data can
   reach the case, write one line in the report and delete the code
   that handles that case.
4. **Add a mechanism.** A lock, retry, guard, cache, or new dependency,
   only for security or data integrity, and only when the case has a
   concrete route through normal use or a realistic mistake.

Record the step in the ledger. A fix at step 4 names why steps 1 and 2
do not work. A fix that adds a mechanism outside security or data
integrity is declined in one line; the main agent decides this and does
not escalate it to the user.

- In a result review, run `git diff --shortstat <base>` before the first round and after each round. When the change grew by more than a quarter since the first round, remove additions the goal does not need before the next round.
- Do not accept a finding only to end the loop.

## Delegation mechanics

- Use a new `delegate_task` call for each round, with `role: "review"`, `mode: "async"`, and `target` set to the partner `providerInstanceId`, `model`, and `options`. End the turn after the call. The completion notification wakes this thread, so do not poll.
- Give each round its own `clientRequestId`, such as `<task-slug>-plan-r1` or `<task-slug>-result-r2`. Reuse it only to resend the same call when its response was lost.
- Never continue a review by sending to the returned `childThreadId`. A new round is a new `delegate_task` call.
- Review in the shared checkout. `isolation: "worktree"` does not copy uncommitted edits. Do not edit files while a review runs.
- Leave `runtimeMode` unset. It is not a read-only switch, and the read-only rules belong in the task text.

## Rounds and disagreement

- Round budget per review (plan or result): up to 2 at the Review-only tier, up to 3 at the Full tier.
- The review ends when every material finding is `resolved`, `declined`, or decided by the main agent, no behavior-changing fix waits for review, and, in a result review, the simplicity pass has run. Otherwise start another round while budget remains.
- The simplicity pass runs exactly once per result review, in its last round: the last round of the budget, or an earlier round that the main agent expects to end the review. It uses the existing budget and never adds a round. The main agent answers each of its findings in one line, applied or why not, and acts only inside the area the change touches. Findings elsewhere, even in a touched file, and simplicity findings raised after the pass go on a list for the user, not into code. Removals from the pass need no new round. The aim is a merge simpler than before, not a perfect one.
- A fix changes behavior when it changes code paths or data, or, in instructions and skills, what an agent does, may do, or decides. Purely editorial fixes need no new round.
- A dispute exchange is the main agent's reply with evidence, plus the partner's verdict on it in the next round. A disagreement the partner keeps after one exchange is decided by the main agent, which records both positions in one line. Only a disagreement about a product decision, as the user's instructions define it, goes to the user.
- When the round budget runs out, stop delegating. The main agent decides every open finding by the fix ladder and lists the remaining ones, one line each, in the report. Running out of budget is never a reason to ask the user, and never an automatic approval of an unreviewed security fix: say plainly which security fix the partner did not see.
- The main agent decides what to fix.

## Partner failure

- Whenever this thread wakes while a review is still running (a user message, another notification), call `task_status` for it. The task is stuck when it has run for more than 30 minutes without a result, or when it waits on a pending question that the reviewer prompt should have answered.
- Cancel a stuck task with `task_cancel` and retry the round once with a new `clientRequestId`, such as `<task-slug>-plan-r1-retry`.
- If the retry also fails, tell the user and let them decide whether to continue solo.
- Never silently drop to a lower tier, and never start a second review task while one is still running.

## Report

The final message is the only one the user is sure to read. It must stand alone: a user who skipped every earlier message, including the plan, the partner's reviews, and the round updates, must understand the whole outcome from it. Restate each point instead of referring back ("as above", "see round 2").

Write it in plain language, as one person explaining to another: short sentences, no jargon, and a technical term only where no plain word does the job. Explain what a finding means for the user.

Order:

1. Outcome: what changed and what it does now, in a few lines.
2. Verification: what was checked and how, and what was not checked.
3. Decisions for the user: only product decisions, each with one recommendation.
4. Leftovers: uncommitted files, skipped checks, manual steps, and the list of simplicity findings left out of this change.
5. Review summary, kept short: tier, partner instance and model, gate result, number of rounds, and change size before and after a result review. Do not show finding ids to the user; describe at most the few findings that changed the result, one line each.
