---
name: debloat
description: Simplify over-engineered code that already exists, on a branch, in a pull request, or in one area of a project, by removing whole mechanisms while users keep the same product. Use only when the user explicitly asks to debloat or to remove over-engineering. Never start it on your own, and do not use it for ordinary cleanup, refactoring, or code review.
---

# Debloat

Remove the mechanisms that a project does not need, and keep its behavior, security, and data integrity. Judge whole concepts, not lines.

A **mechanism** is a concept such as a lock, a retry, a journal, an extra state or copy, a fallback chain, a setting, or a check. Its **route to failure** is the way a real user, a caller, or stored data reaches the case that it handles.

This skill uses `cross-review` for the partner, and the user's fix ladder and comment rule. `cross-review` decides the tier, the gate, and the rounds, so the partner steps below apply only when the tier includes them. Where one of these is missing, use its default:

- Partner: none.
- Ladder: design the case away, or delete code, or accept the risk. Add a mechanism only for security or data integrity with a real route to failure.
- Comments: a comment only explains why code exists when the code cannot show it. The reason in an existing comment stays while its code stays.

## Rules for the whole run

- Do not start while another agent or thread works in the same checkout.
- Act only inside the scope. Report bloat elsewhere, and do not touch it.
- Change what users see or get only after the user decides. Put each such question in the plan.
- Commit, push, and merge only with the user's approval.
- Report only numbers that you measured with Git or the test runner. Agent summaries of this work have been wrong.
- One run is one plan, one simplification, one independent check, and one fix round. Do not add passes. Every extra reviewer finds something more, so "no findings" is not the goal.

## Choose the scope

- **Branch or pull request.** The scope is the diff from the merge base with the target branch, with uncommitted and untracked work.
- **Existing project on its default branch.** Do the survey first. The user then picks one area, and that area is the scope. Never simplify a whole project in one run.
- **README.** In an existing project, the run also brings the README to [the README format](references/readme-format.md), as a separate change. The user can ask for the README alone. The steps are then the same, with a verdict for each section and question 3 of the check. On a branch, change only what the README says about the scope.

### Survey an existing project

The survey is read-only. Find candidate areas from size, churn, and the history of fixes. Look for these patterns:

- Handling of two people who act in the same second, or of a lost answer after a successful write.
- A copy, journal, or backup of data that the database or another source already protects.
- A state or refusal that leaves the user stuck.
- Custom code for what a library in use already does.
- The same logic in two places that must match.
- One-time migration or repair code that still runs.
- Checks for data that only a hand edit can produce.
- Result states that no user or caller acts on.
- Review ids in comments, or far more test lines than code lines.

A pattern is a lead, not a verdict. Read the code and the commit that added it, because some of these mechanisms fixed a real bug.

Lead with one recommended area and one table of areas, ranked by benefit (lines, concepts, user friction, how often the code changes) against risk. Detail only the top three areas: the mechanisms with their locations, the route to failure of each or the lack of one, the mechanisms that must stay, and the existing tests. Give every other lead one line. Then wait for the user's choice.

## 1. Take a baseline

1. Save the files on disk, with uncommitted and untracked ones, in a local ref. Before each snapshot, if an uncommitted change or an untracked file that Git does not ignore holds a secret, stop and tell the user first. Run this from the repository root in a POSIX shell. It works on a copy of the index, so the real index and the working tree do not change, and it refuses to overwrite an existing ref. Never push the ref.

   ```sh
   name="<scope>-before"   # later: "<scope>-after", "<scope>-final"
   copy="<temporary directory outside the repository>/debloat-index" &&
   cp "$(git rev-parse --git-path index)" "$copy" &&
   GIT_INDEX_FILE="$copy" git add -A &&
   tree="$(GIT_INDEX_FILE="$copy" git write-tree)" &&
   commit="$(git commit-tree "$tree" -p HEAD -m "$name")" &&
   git update-ref "refs/backup/$name" "$commit" ""
   ```

2. Measure product lines, comment lines, and test lines in the scope, and run the tests. Keep the commands, so that the same ones measure the result.
3. Write the "must not weaken" list from recorded product decisions, security, and data integrity. Ask the user only about a decision that you cannot find and that a verdict depends on.

## 2. Plan the mechanisms

Write the facts that the verdicts rest on, such as how many instances run or which risks the user already accepted. Then number every mechanism in the scope, and give each one its location, its route to failure, and one verdict:

| Verdict | When | What the run does |
|---|---|---|
| Keep | It has a real route that nothing simpler covers. | Nothing. |
| Redesign | A simpler flow or data model makes the case impossible. | Replaces the mechanism. The plan names what the old one told apart. |
| Delete | It has no route. | Removes the code, its states, settings, messages, tests, and documentation. |
| Accept the risk | It has a route, but the case is rare and its result is tolerable. | The same as delete. The plan names the result that a user can get. |

> 7. Stored copy of the labels. Route: the label query fails while the rest of the page loads. Accept the risk: the page shows ids until the next load. Delete the copy, its refresh, and their tests.

Never accept a risk to security or data integrity that has a real route. Also list the differences that users will see, and the open product decisions. Have the partner review the plan, then show the user the revised plan and wait for approval.

## 3. Simplify once

Carry out the approved verdicts. Keep the tests of kept behavior, and do not change what they assert. When the code proves a verdict wrong, correct the plan and go on. Stop only for a new product decision.

Run the project's checks and the partner's result review. Then save `refs/backup/<scope>-after` with the commands of step 1. The simplification ends here.

## 4. Check independently

Give the check to an agent with a clean context that took no part in the run. For a large diff use two agents, one for questions 1 and 2 and one for questions 3 and 4. Each one gets only:

- The path of [the check brief](references/independent-check.md), which it reads itself.
- The repository, the two refs, and the scope.
- The "must not weaken" list.

Do not pass the plan, your summary, or the review results. They tell the checker what to believe. If no such agent is available, report that the check is missing.

## 5. Fix once

1. Confirm each finding in the code. The checker does not know the accepted risks, so expect findings about them. Reject one as accepted only when an approved verdict names the same route and the same result.
2. Reproduce each regression with a test or a temporary script that fails before the fix.
3. Resolve each finding by the ladder, at exactly the confirmed locations and nothing else. Prefer a fix that adds nothing, or that restores the earlier behavior. Restore each lost reason in one short comment.
4. Run the project's checks. The fix is its own change under `cross-review`.
5. Save `refs/backup/<scope>-final` and take the final measurements on it.

A correct finding is not a reason to add code. When only a new mechanism or a larger change would resolve it, do not add it, and bring it to the user with its effect on the merge.

## 6. Report

- A table of the measurements before and after, with the number of mechanisms.
- What went, and why that is safe.
- What stayed, and against what.
- What users will see differently.
- The accepted risks, each with its result.
- What the independent check found, and what was fixed.
- Product decisions that wait for the user.
- What was not checked, what stayed open, and the bloat seen outside the scope.
- The backup refs. They stay until the user approves the result.
