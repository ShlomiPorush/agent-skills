---
name: thread-manager
description: Manage a batch of work items that the user hands to separate top-level T3 Code threads. Ask the setup questions once, launch one worker thread per item or group, approve worker plans within the authority the user grants, relay product decisions, merge only when authorized, and close every thread, schedule and watch at the end. Use only when the user explicitly asks to move work into dedicated or separate threads and to have you manage those threads. Not for subagents, delegate_task, cross-review partners, or opening a single new thread.
---

# Thread manager

One agent, the manager, splits a body of work into items and launches each item, or each group of items, in its own top-level T3 Code thread. A worker agent in that thread does the item from start to a ready pull request. The manager answers the workers, tracks them, takes product decisions to the user, merges when the user allows it, and closes everything at the end. The user talks only to the manager and does not follow each thread.

## Check that this skill applies

- Use it only when the user explicitly asks to move work into dedicated or separate threads and to have you manage them. That request is what allows you to create new top-level threads.
- Ordinary delegation stays with the harness's subagent tool or `delegate_task`. A request for "a subagent", "a delegate", "parallel work", or one new thread is not a request for this skill.
- The skill needs an agent inside a T3 Code thread with the `t3-code` MCP tools. Outside T3, tell the user that the skill is unavailable.
- One run covers one repository. For items in another repository, start a separate run with its own brief and tracker.

## Roles

| Role | Does | Never does |
|---|---|---|
| Manager | Splits the work, launches workers, answers them, keeps the tracker, takes decisions to the user, merges when authorized, closes out. | Implements an item itself. Decides a product question. Merges, releases or deploys without explicit authorization. |
| Worker | One item, or one group, in its own worktree: plan, change, its own cross-review, verification, pull request, reports. | Asks the user questions. Works outside its worktree. Merges, releases or deploys. |
| User | Product decisions, plan approval unless granted to the manager, merge and release authority. | Follows worker threads. The manager makes that unnecessary. |

## 1. Ask the setup questions once

Before the first launch, ask one batch of questions: one question dialog, or one chat message where no dialog tool exists. Ask at most four questions. Drop a question that the request already answers, and pair two that fit together.

- **Publishing mode.** A normal pull request per item, and neutral public wording when the repository is public.
- **Who merges.** The user, or the manager, one pull request at a time, when each is green.
- **Grouping and pace.** One item per thread, or one thread for items that touch the same files. How many workers run at once, and in which waves.
- **Plan approval and decision authority.** The manager approves worker plans, or the user does, or each worker proceeds after its own plan review. Offer the last option only as an explicit choice. Product decisions always go to the user.

Record the answers word for word, with a UTC time, at the top of the tracker. The setup dialog is the only dialog the manager opens. After the first launch, the manager never opens a blocking dialog, because a dialog that waits for hours stalls every worker that needs an answer.

## 2. Prepare the run

1. Give the run a fixed run id, such as `<task>-<yyyymmdd>-<n>`, and a run directory in the temporary location the user's instructions name, such as `T:\<task>\<run id>\`.
2. If the run directory already holds a tracker, this is a resume. Do not overwrite the brief or the tracker. Follow "Resume after an interruption" first.
3. Look up your own ids: `environmentId` from `t3_environment_read`, and `currentThreadId` and the thread title from `t3_thread_list`. Never put a placeholder id in a brief or a send. A placeholder fails with `thread_not_found`, and the worker cannot report.
4. Write the shared brief from [templates/brief-common.md](templates/brief-common.md) to the run directory, and replace every `{PLACEHOLDER}`. Set `{PLAN_GATE}` to `wait` when the manager or the user approves plans, and to `none` only when the user chose that the workers proceed alone. Set `{MAIN_SINCE}` to what changed on main since the work was planned, or remove it. Set `{LOCK_SECTION}` from "Share a stack safely", or remove it when no verify step uses a shared resource. Set `{PUBLIC_WORDING_RULE}` from the publishing answer. For a public repository, it says that pull request titles and bodies, branch names, commit messages and changelog entries describe the change neutrally, without internal paths, tracking ids or attack details.
5. Write the tracker from [templates/tracker.md](templates/tracker.md).
6. Plan the waves. Put items that touch the same files in one thread or in different waves. Do not stack one worker's branch on another's.

The per-item part of each launch message is short:

```text
Brief: <run dir>\brief-common.md (read it first; it is part of this task).
Run: <run id>. Item: <item>. Branch: <branch>.
Task: <what to do, in a few lines>.
Known files: <paths>.
Decisions to surface, not to make: <list or none>.
Siblings that touch the same files: <items or none>.
```

## 3. Launch the workers

For each item in the current wave:

1. Write the tracker row with status `LAUNCHING` and the `clientRequestId`.
2. Call `t3_thread_launch`:
   - `title`: neutral, such as the change it makes.
   - `workspaceStrategy`: `{type: "worktree", baseRef: "origin/<default branch>", startFromOrigin: true, branch: "<neutral branch name>"}`.
   - `clientRequestId`: `<run id>-<item>-launch`. After an error or a lost reply, retry with the same id, never with a new one.
   - `delegatedFrom`: the manager's `environmentId`, `threadId` and `title`.
   - `projectId`: the repository's T3 project, when it is not the manager's project.
   - Omit the model, the runtime mode and the interaction mode, so the worker inherits the manager's. `t3_thread_send` cannot reach a thread that runs with broader modes than the sender.
   - `message`: the per-item part.
3. Record the returned thread id and link in the tracker and set the row to `RUNNING`.
4. Confirm the start with one small `t3_thread_read`.

Launch only up to the concurrency cap. Queue the other items for later waves. Mention each thread to the user by its `link`.

## 4. Exchange messages with the workers

### Worker status line

A worker sends every state change to the manager with `t3_thread_send`, `mode: "queue"`, to the manager's real thread id. The first line of the message is fixed English tokens:

```text
[<run id>:<item>] <STATUS> | plan <n|none> | rev <n> | pr <url|none> | head <sha|none> | checks <green|failing|pending|none> | tier <solo|review-only|full> | review <resolved|open|none>
```

| STATUS | Meaning |
|---|---|
| `PLAN_READY` | Plan `<n>` passed the worker's plan review and waits for approval. Only with `PLAN_GATE: wait`. |
| `PR_READY` | The pull request is open, every required check is green, and the result review is resolved. |
| `DECISION_NEEDED` | A product decision blocks the item. The details give the question, the options and one recommendation. |
| `NOT_NEEDED` | The item no longer applies on current main. The details give the reason. |
| `BLOCKED` | The worker cannot continue, for example because the partner budget gate returned `ask`. |
| `WAITING` | The worker must end its turn before a result. `for <what>` names the lock, the command and its handle, or the check it waits on. |

Short English details follow the first line. The worker numbers every plan (`plan 1`, then `plan 2` after changes), whatever the plan gate, and puts its current plan number in every status line after its first plan. Only the worker sets `plan`. Only the manager sets `rev`: it starts at `0` and goes up by one with every `DECISION` and `REVISED`. The worker puts the highest `rev` it has applied in every status line. The worker ends its final message in its own thread with the same status line. If the send fails, the worker still ends with the status line, and the heartbeat asks for a fresh send.

### Manager envelope

Every manager message to a worker starts with one envelope line, then short English details:

```text
[manager] [<run id>:<item>] <COMMAND> | plan <n|none> | rev <n> | decision <D<n>|none>
```

| COMMAND | Meaning |
|---|---|
| `APPROVED` | Plan `<n>` is approved. Continue. |
| `CHANGES` | Plan `<n>` needs the listed changes. Send a new plan number. |
| `DECISION` | The user decided `D<n>`. The details list every decision in effect for the item. |
| `REVISED` | The user changed `D<n>`. The envelope carries the new `rev`, and the details list every decision in effect for the item. Earlier approvals and `PR_READY` for the item are void. Apply the change under a new plan number and report with the new `rev`. |
| `RESUME` | The condition the worker waited on is gone. Continue. |
| `REBASE` | Main moved. Rebase on the given main SHA, verify again, report again. |
| `HOLD` | Do not push to the branch until told otherwise. |
| `NUDGE` | No status arrived. Send your current status line. |

### Check every message before acting on it

A message wakes the other side. It does not prove anything by itself.

- The worker acts on a manager message only after it reads the message with `t3_thread_read` and confirms four facts: its `senderThreadId` is the manager thread id in the brief, the envelope names this run and item, the `rev` is not lower than the worker's own, and, for `APPROVED` and `CHANGES` only, the plan number is the worker's current plan. Other commands do not depend on the plan number, so an outdated plan number in them is not a reason to ignore them.
- The manager, on every worker message:
  1. Matches the `[<run id>:<item>]` tag to a tracker row, and ignores a tag from another run.
  2. Reads the message with `t3_thread_read` and confirms that its `senderThreadId` is that row's worker thread.
  3. Rejects a report whose plan number is lower than the row's current plan, or whose `rev` is lower than the row's `rev`. A report made before the latest revision never restores readiness.
  4. For `PR_READY`, rejects `review open`, and accepts `review none` only with `tier solo` and the worker's reason. Then checks the pull request itself with `gh pr view <n> --json number,state,headRefName,headRefOid,baseRefName,statusCheckRollup,mergeable`: the right repository, the branch in the tracker, the default branch as base, the reported head, and every check green.
  5. Only then updates the tracker.

## 5. Keep the manager awake

- **Primary: the worker's push.** The manager ends its turn after launching and after each handled message. A worker's `t3_thread_send` starts the manager's next turn.
- **Fallback: one heartbeat.** Create one `schedule_task` bound to the manager thread, every 45 to 60 minutes, titled `<run id> heartbeat`, with `clientRequestId` `<run id>-heartbeat`. Write `heartbeat: creating` to the tracker before the call. After a lost reply, retry with the same `clientRequestId`. Record the returned id. The heartbeat prompt tells the manager to:
  1. Read the tracker.
  2. For each running worker, read its thread with a small `t3_thread_read` and list open dialogs with `t3_pending_request list`.
  3. Send `NUDGE` to a worker that is idle and whose latest status did not reach the manager as a checked send, including a status line left only in the worker's own thread. Act only on the checked send that follows.
     Send the latest `DECISION` or `REVISED` again to a worker whose latest report carries a lower `rev` than its row.
  4. For each `WAITING` worker, check its `for` condition, and send `RESUME` once the condition is gone: the lock is free, the command ended, or the check finished.
  5. Launch the next wave when a slot is free.
  The heartbeat acts on these fresh reads, not on the tracker alone.
- **During merges:** `watch_pull_request` on the pull request being merged.
- **Not a wake mechanism:** `t3_thread_wait`. A `completed` result only means that a run ended. A worker can end a turn while it waits for a lock. The item is done only when a checked status line says so.
- Do not use polling scripts, sleep loops, `Monitor`, or `gh --watch` to wait for a pull request.
- **Start every wake with the tracker.** Read the setup answers and the item states first, then act. Before every status report to the user, read the setup answers again instead of relying on memory. This also survives context compaction.
- **Answer a worker's dialog.** If a worker opened a question despite the brief, answer it with `t3_pending_request respond` within your authority, or with "Send DECISION_NEEDED to the manager and stop". Take a product question to the user in chat.

## 6. Share a stack safely

- When a verify step uses a fixed shared resource, such as a fixed Compose project name or a fixed port, the brief requires a machine-wide lock named after that resource. Every run uses the same path, such as `T:\locks\<resource>`, never a path under the run directory.
- Prefer `flock`, which releases the lock when the process exits. Otherwise use an atomic directory create with an owner file that holds the run id, the item, the thread id and a UTC time, and release it on success and on failure.
- A worker never removes another worker's lock. Only the manager clears a stale lock, and only after it confirms that the owner thread is not running (`t3_thread_list` status and `t3_thread_read`) and that no process of that run still uses the resource. The age of the lock alone is never enough.
- Run timing-sensitive test suites under the same lock. They fail under parallel load.
- Plan the waves so that two workers do not change the same files at the same time.

A lock section for the brief, with `flock`:

````markdown
## Shared lock (mandatory)

`<verify command>` uses the fixed resource `<resource>`, and other workers use it at the same time. Run every command that uses it under the machine-wide lock:

```sh
flock <lock path>/<resource>.lock <verify command>
```

The lock waits for its turn and releases when the command exits. Never delete the lock file. Commands that do not use `<resource>` need no lock.
````

## 7. Handle plans and decisions

- **Plan approval.** Approve plans only when the user granted that authority. Check each `PLAN_READY`: one item of scope, the smallest change, fitting verification, the library rule, and no hidden product decision. Reply `APPROVED` or `CHANGES`. Without the grant, take the plan to the user.
- **Product decisions.** A behavior users notice, a new setting, a security or usability trade-off, a gap in a library, or a changed meaning of an existing test is a product decision. When you are unsure, treat it as one. Never decide it silently and never approve it inside a plan.
- **Ask the user in chat.** Use the user's language. Ask one plain question. Give two or three options, each described by what the user will see. Give one recommendation with its reason. Do not open a dialog. The other workers keep running.
- **Explain without flip-flopping.** When the user asks for more detail, describe a concrete scenario, not theory. Check the facts before you answer, so that a second explanation does not contradict the first.
- **Record and relay.** Give each decision an id (`D1`, `D2`) and a UTC time in the tracker, raise the row's `rev` by one, and send it to the worker with `DECISION` and the new `rev`. When the user changes a decision, log both answers, raise the row's `rev` by one, set the row back to `RUNNING`, and send `REVISED` with the new `rev`. Every `DECISION` and `REVISED` lists, in its details, every decision in effect for the item with its current answer, so one delivered message replaces any that were lost. Any earlier approval or `PR_READY` for the item is void. The worker applies the change under a new plan number and reports again with the new `rev`. Merge only on a `PR_READY` that carries the row's current `rev`. If the affected item is already `MERGING` or `MERGED`, tell the user at once and wait for direction on that item.

## 8. Merge

Merge only with the user's explicit authorization, given at setup or later in the thread. Merge one pull request at a time, in an order recorded in the tracker. Releases and deploys happen only on an explicit request.

1. **Once per run, check for a merge queue.** Run `gh api --paginate repos/<owner>/<repo>/rules/branches/<default branch>`. If any page lists a `merge_queue` rule, or if the check fails or is incomplete, do not merge. Give the ready pull requests and their reviewed heads to the user.
2. **Check the pull request.** It is open, mergeable and every check is green. Its head SHA equals the head of the worker's latest checked `PR_READY` that carries the row's current `rev`, the reviewed head. Set the row to `MERGING` with the pull request number and that SHA. The row stays `MERGING` until steps 3 to 6 are all done.
3. **Merge.** Run `gh pr merge <n> --match-head-commit <sha>` with the repository's merge method. Never use `--auto`. Confirm with `gh pr view <n> --json state,mergeCommit` that the state is `MERGED`, and record the merge commit. If the state is not `MERGED`, keep the row at `MERGING`, stop merging, and tell the user. Do not merge the next pull request or delete the branch.
4. **Wait for main CI.**
   1. Find the expected workflows: those in the default branch's `.github/workflows` whose `push` trigger matches the default branch and whose `paths` or `paths-ignore` filters match the files the merge changed.
   2. If none apply, record "no main CI for this merge". If you cannot tell which apply, stop merging, and ask the user how to proceed.
   3. Find each run with `gh run list --commit <sha> --branch <default branch> --event push --workflow <file>`. Retry inside one command for about 10 minutes. If a run does not appear, stop merging, and tell the user.
   While merging is stopped, the row stays `MERGING` with the reason in its notes. Do not delete the branch, settle the thread, or merge the next pull request until the user decides.
   4. Watch each run with `gh run watch <run id> --exit-status`, in the foreground, or in the background with `t3_background_wait` on Claude. This waits for a branch run, not for a pull request.
   5. If main turns red, stop merging and follow the user's rules for a failing default branch.
5. **Delete the branch** per the user's rules, unless another open pull request uses it as its base.
6. **Settle the worker thread** with `t3_thread_organize` and `action: "settle"`, after the quiet check in "Close out". Then set the row to `MERGED`.

When a pull request falls behind main:

- **Only the changelog conflicts.** The manager may rebase the branch itself.
  1. Send `HOLD` to the worker.
  2. Rebase in the manager's own clone under the run directory, never in the main checkout. Keep both changelog entries.
  3. Before the push, run `git range-diff <old base>..<old head> origin/<default branch>..HEAD` and confirm that the only patch difference is in the changelog.
  4. Push with `--force-with-lease=<branch>:<old head>`.
  5. Record in the tracker the new head, the reviewed head it replaces, and "changelog-only rebase, range-diff checked".
  6. Wait for the pull request's CI with `watch_pull_request`, then merge at the new head.
- **Anything else.** A code conflict, a range-diff that shows more than the changelog, or a failing check after the rebase goes back to the worker. Abort the rebase and send `REBASE` with the main SHA. The worker rebases, verifies again, applies its cross-review rules, and reports `PR_READY` with the new head.

## 9. Resume after an interruption

Read the tracker, then reconcile before any new action:

- `heartbeat: creating`: look for the schedule with `list_scheduled_tasks` by its title. Record it, or retry the creation with the same `clientRequestId`.
- `LAUNCHING`: retry `t3_thread_launch` with the same `clientRequestId`. It returns the thread that was already made. Record it.
- `RUNNING`: read the worker thread and update the row.
- `MERGING`: first read the notes. If merging stopped for a user decision, wait for that decision and do nothing else on the row, whatever GitHub shows. Otherwise read the pull request. If GitHub shows it merged, record the merge commit and finish the remaining merge steps (main CI, branch, settle) before the next pull request. If not, check the pull request again from step 2 of "Merge".

Never start a second worker for an item before its first worker is reconciled.

## 10. Keep language and time consistent

- Say each thing once, in one language. Never repeat a message in a second language.
- Messages between agents, the brief, the status line and the envelope are English. Repository content is English.
- Chat text that a person reads, in the manager thread and in a worker thread, follows the user's language rules.
- The status line and the envelope are fixed tokens. Never translate them.
- Before you send a message to the user, check that it is in one language, and rewrite it if words in another language or script slipped in.
- The tracker stores times in UTC with a `Z` suffix. Convert them only in messages to the user, to the zone the user's rules name.

## 11. Close out

1. **Check that every worker is quiet.** Its `t3_thread_list` status is `idle`, `completed`, `interrupted`, `failed`, or `cancelled`, never `preparing`, `queued`, `starting`, `running`, or `waiting`. It has no open dialog. No manager message to it is still queued. Its last checked report is final for its item: `PR_READY` for an item that GitHub shows merged or that the manager handed to the user, `NOT_NEEDED`, or any report for an item the manager recorded as `CLOSED`. Run the same check before you settle a single worker or clean up its worktree.
2. **Check that every item is terminal** in the tracker. Give each item that is not terminal to the user explicitly in the final report, with its thread link and state. Leave its thread unsettled and keep its branch and worktree.
3. **Stop every wake.** Delete the heartbeat with `delete_scheduled_task`, including any schedule whose title carries the run id but whose id was never recorded. Confirm with `list_scheduled_tasks`. Stop every pull request watch with `unwatch_pull_request`.
4. **Settle** every worker thread whose item is terminal.
5. **Clean up** per the user's rules: worktrees, local and remote branches, temporary clones, and containers the run created. Find them with `t3_worktree_list` and `git worktree list`. Clean up only for items that are `MERGED`, `NOT_NEEDED`, or `CLOSED` without unmerged commits. Never delete an unmerged branch or a worktree with uncommitted changes.
6. **Report** to the user, in the user's language: the outcome, a table of items with thread links and states, the decisions taken, and every leftover.

## Tracker states

| State | Meaning | Terminal |
|---|---|---|
| `QUEUED` | Waits for a later wave. | No |
| `LAUNCHING` | Launch requested; thread id not recorded yet. | No |
| `RUNNING` | The worker works on the item. | No |
| `PLAN_READY` | Plan waits for approval. | No |
| `DECISION_NEEDED` | Waits for a user decision. | No |
| `WAITING` | The worker waits on a named condition. | No |
| `BLOCKED` | The worker or the manager cannot continue without help. | No |
| `PR_READY` | Pull request checked and ready. | Yes, when the user merges |
| `MERGING` | Merge checks passed. The merge, main CI, branch deletion, or settle is not finished, or merging stopped for a user decision. | No |
| `MERGED` | Merged, merge commit recorded, main CI finished green or none applied, branch handled, thread settled. | Yes |
| `NOT_NEEDED` | The item no longer applies; the manager accepted the reason. | Yes |
| `CLOSED` | Stopped on purpose; the reason is recorded. | Yes |
