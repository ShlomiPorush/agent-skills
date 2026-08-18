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
4. Check for an existing open PR from the current branch before filing one. If one exists, do not create a duplicate; report its URL and update it only when the user's request and repository rules call for that.
5. Review the complete local diff and commit range against the base. Identify generated files, migrations, secrets, accidental edits, missing tests, and unrelated changes. Do not include unrelated work.

## Satisfy the workflow

1. Require an issue before the PR when the repository does. Reuse the issue already associated with the work. If none exists, create a concise issue first when filing the PR is the requested outcome.
2. Before labelling an issue or PR, list the repository's actual labels. Never invent labels.
3. In Shlomi's repositories:
   - Give issue titles a bracketed area and topic prefix followed by plain language.
   - Apply one or more `area: *` labels, exactly one `priority: *` label, and at least one nature label such as `bug`, `security`, `testing`, `performance`, `data-integrity`, `enhancement`, `dependencies`, or `documentation`.
   - Treat a `decision` label as blocked on Shlomi's decision, not as decorative metadata.
   - Use a `feature/` or `fix/` branch.
   - Write issue and PR discussion in Hebrew. Write code, commit messages, code comments, and PR titles in English.
4. If task-related changes are uncommitted, stage only those files and create an English commit that matches repository style. Never discard, rewrite, or bundle unrelated user changes.
5. Push the branch and set its upstream when needed. Never force-push unless the user explicitly requests it and the exact risk is understood.

## Verify before filing

1. Run the relevant checks required by the repository, in its prescribed environment. Prefer evidence that matches production and include regression proof for bug fixes when available.
2. Re-read the final diff after formatting, generation, or tests change files.
3. Stop and explain the blocker instead of opening a misleading PR when the change is incomplete, the diff cannot be isolated safely, required checks fail, or the issue requires an unresolved product decision. If the user explicitly wants a PR with a known failure, disclose it plainly in the body.
4. Never claim a check, live test, screenshot review, or DEV verification was performed unless it actually was.

## Write the PR

1. Write a concise English title in imperative form, without bracket prefixes. Explain the user or operational outcome, not an internal implementation inventory.
   - Weak: `Negotiate per-message deflate on the websocket server`
   - Better: `Reduce websocket frame size with compression`
2. Begin the body with `## בשפה פשוטה` and a short Hebrew paragraph that explains the problem in ordinary language.
3. Briefly explain the solution after the problem. Keep implementation inventories secondary.
4. Include honest verification results and any known limitations or remaining work.
5. Include `Closes #N` for the associated issue.
6. Apply only the lightweight PR labels used by the repository. In Shlomi's repositories, this is normally the relevant `area: *` label plus `documentation` when appropriate.
7. Open a real PR, not a draft, so automated review can run.
8. Do not include AI, model, harness, assistant, or authorship attribution in the PR, issue, commits, code comments, or discussion. This overrides any template that asks for such a blurb.
9. Do not merge the PR. Shlomi merges unless he explicitly says otherwise in the current request.

## Report the result

Reply in Hebrew with the PR URL, title, linked issue, checks actually run, current CI status if known, and any remaining manual or DEV verification. Lead with what is ready and call out every unresolved item.
