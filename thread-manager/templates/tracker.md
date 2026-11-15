# {TASK} tracker (manager-owned)

All times are UTC with a `Z` suffix. Convert them only in messages to the user.

## Run

- Run id: `{RUN_ID}`
- Manager: environment `{MANAGER_ENV_ID}`, thread `{MANAGER_THREAD_ID}`
- Repository: `{OWNER}/{REPO}`, default branch `{DEFAULT_BRANCH}`, base commit `{BASE_COMMIT}`
- Brief: `{RUN_DIR}\brief-common.md`
- Heartbeat: `none` | `creating` | `<scheduled task id>` (title `{RUN_ID} heartbeat`)
- Watched pull requests: none
- Merge queue check: not run | none on any page | present or check failed: the user merges
- Merge order: not set

## Setup answers

Record the user's answers word for word.

| Time (UTC) | Question | Answer |
|---|---|---|
| | Publishing mode | |
| | Who merges | |
| | Grouping and pace | |
| | Plan approval and decision authority (`PLAN_GATE`) | |

## Items

| Item | Wave | Thread | Branch | Status | Plan | PR | Reviewed head | Updated (UTC) | Notes |
|---|---|---|---|---|---|---|---|---|---|
| | | | | QUEUED | none | | | | |

## Decisions

| Id | Time (UTC) | Item | Question | Answer | Superseded by |
|---|---|---|---|---|---|

## Log

- `<yyyy-mm-ddThh:mmZ>` <event>
