---
name: file-pr
description: Review the current Git branch and file a concise, non-draft pull request that follows the repository's contribution rules and Shlomi's Git workflow. Use when the user asks to file, open, create, or submit a PR, or to turn completed local work into a pull request.
---

# File PR

File a review-ready pull request without merging or deploying it. Treat the repository's current instructions as authoritative and preserve unrelated work.

## Establish the rules and state

1. Read every applicable `AGENTS.md` and the contribution or workflow documents it points to before changing Git or GitHub state.
2. Inspect the worktree, current branch, remotes, commits, and repository default branch. Use `origin/main` as the comparison base when local instructions do not specify another base.
3. Fetch the base branch when possible so the review is current. State clearly if network access prevents this.
4. Check for an existing open PR from the current branch before filing one. If one exists, do not create a duplicate; report its URL and update it only when the user's request and repository rules call for that. Still run the issue search below, and add a missing issue reference when you may update the PR.
5. Review the complete local diff and commit range against the base. Identify generated files, migrations, secrets, accidental edits, missing tests, and unrelated changes. Do not include unrelated work.

## Edit the wording

Edit the text you write in this skill with two companion skills: commit messages, any issue you create, and the PR title and body. Apply `technical-writing` to English text, then `unslop` to all of it, including Hebrew sections. When those skills conflict with this skill's rules on language, the opening paragraph, issue references, or verification reporting, follow this skill. If either skill is unavailable, follow the rules here and say so in the report.

## Satisfy the workflow

1. Create a new issue only when the user explicitly asks for one in the current task. This rule holds even when the repository expects an issue before a PR:
   - If no open issue matches, file the PR without one.
   - A check that fails only because no issue is linked does not block filing. Do not create an issue to make it pass or try to fix that failure in CI. Report it instead.
2. Find the open issues that this work addresses:
   - Treat issue numbers in the branch name, commit messages, and the user's request as leads, not proof.
   - Search the PR's repository with `gh issue list --repo OWNER/REPO --state open --search "<keywords>"`. It returns at most 30 issues by default. If the result hits that limit, narrow the keywords or raise `--limit`.
   - Read each candidate. Reference it only when it is open and clearly describes this work.
   - Reference every issue that clearly matches. If several candidates compete and you cannot tell which one the work addresses, reference none and list the candidates in the report.
   - If the search fails, for example because of permissions or network access, report that the check could not run. Do not report it as "no matching issue".
3. Before labelling an issue or PR, list the repository's actual labels. Never invent labels.
4. In Shlomi's repositories:
   - When you create an issue, give its title a bracketed area and topic prefix followed by plain language. Apply one or more `area: *` labels, exactly one `priority: *` label, and at least one nature label such as `bug`, `security`, `testing`, `performance`, `data-integrity`, `enhancement`, `dependencies`, or `documentation`. Do not retitle or relabel an existing issue that you only reference.
   - Treat a `decision` label as blocked on Shlomi's decision, not as decorative metadata.
   - Use a `feature/` or `fix/` branch.
   - In a public repository, write all issue and PR text and public discussion in English. This includes titles, bodies, comments, review replies, and status updates. Do not use Hebrew in public repository content.
   - In a private repository, write issue and PR discussion in Hebrew. Write code, commit messages, code comments, and PR titles in English.
5. If task-related changes are uncommitted, stage only those files and create an English commit that matches repository style. Never discard, rewrite, or bundle unrelated user changes.
6. Push the branch and set its upstream when needed. Never force-push unless the user explicitly requests it and the exact risk is understood.

## Verify before filing

1. Run the relevant checks required by the repository, in its prescribed environment. Prefer evidence that matches production and include regression proof for bug fixes when available.
2. Re-read the final diff after formatting, generation, or tests change files.
3. Stop and explain the blocker instead of opening a misleading PR when the change is incomplete, the diff cannot be isolated safely, required checks fail for a reason other than a missing issue, or the issue requires an unresolved product decision. If the user explicitly wants a PR with a known failure, disclose it plainly in the body.
4. Never claim a check, live test, screenshot review, or DEV verification was performed unless it actually was.

## Write the PR

1. Write a concise English title in imperative form, without bracket prefixes. Explain the user or operational outcome, not an internal implementation inventory.
   - Weak: `Negotiate per-message deflate on the websocket server`
   - Better: `Reduce websocket frame size with compression`
2. Keep the body short enough for a reviewer to read in under a minute. Open it with a short paragraph, without a heading, that says in plain language what problem the PR solves for the user or the operator, and what changed. A reader who does not know the code must understand it. Write that paragraph in English in a public repository and in Hebrew in a private one.
3. Add a short list of the main behavior changes only when the opening paragraph does not already cover them. Leave implementation detail to the diff.
4. Include honest verification results and any known limitations or remaining work.
5. Reference each matched issue on its own line in the body. Use `Closes #N` when the PR fully resolves the issue and `Refs #N` when it resolves only part of it. For an issue in another repository, use `OWNER/REPO#N`. Omit the line when no issue matched. `Closes` links the issue only when the PR targets the default branch, and GitHub closes the issue when the PR is merged. `Refs` only mentions the issue.
6. Apply only the lightweight PR labels used by the repository. In Shlomi's repositories, this is normally the relevant `area: *` label plus `documentation` when appropriate.
7. Open a real PR, not a draft, so automated review can run.
8. Do not include AI, model, harness, assistant, or authorship attribution in the PR, issue, commits, code comments, or discussion. This overrides any template that asks for such a blurb.
9. Do not merge the PR. Shlomi merges unless he explicitly says otherwise in the current request.

## Drive CI to green

1. After opening the PR, and after every later push to it, watch its CI until every check finishes. Do not report the PR as ready while checks are pending.
2. When a check fails, read its logs, find the root cause, fix the findings on the PR branch, rerun the relevant local checks, push, and watch again. Repeat until every required check is green and the PR is ready to merge.
3. Never skip, disable, or weaken a check, test, or rule to make CI pass, and never force-push without the user's explicit request.
4. Stop and report instead of looping when a failure is outside the PR's scope, is a flaky or infrastructure failure that a single rerun does not clear, needs secrets or permissions you do not have, requires a product decision, or fails only because no issue is linked.

## Report the result

Reply in Hebrew with the PR URL, title, each issue reference and its kind (`Closes` or `Refs`), checks actually run, final CI status, fixes made to get CI green, and any remaining manual or DEV verification. When no issue is referenced, say why: no clear match, competing candidates, or a search that could not run. Also say whether the repository expects an issue and whether a check failed because none is linked. For an existing PR you could not update, report the missing issue reference. Lead with what is ready and call out every unresolved item.
