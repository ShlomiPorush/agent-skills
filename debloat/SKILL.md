---
name: debloat
description: Find over-engineering in existing code, in a whole project or in a change such as a branch or a pull request, and replace it with what the problem needs, while the product stays the same. Also cleans needless comments, and can bring a README to a fixed format when asked. Use only when the user explicitly asks to debloat or to remove over-engineering. Never start it on your own, and do not use it for ordinary cleanup, refactoring, or code review.
---

# Debloat

Find the mechanisms that are over-engineered, and bring each one down to what its problem needs. The product, its security, and its data integrity stay the same. Every run also cleans the comments.

**Over-engineering** is a mechanism that is more complex than the problem it solves, or that solves a problem with no real route to failure. A feature, a setting, a screen, or another capability of the product is not over-engineering, however large it is. The amount of code is neither the goal nor evidence. A small mechanism can be excessive, and a large one can be justified.

A **mechanism** is an internal concept such as a lock, a retry, a journal, an extra state or copy, a fallback chain, or a check. Its **route to failure** is the way a real user, a caller, or stored data reaches the case that it handles.

This skill uses `cross-review` for the partner, and the user's fix ladder and comment rule. `cross-review` decides the tier, the gate, and the rounds, so the partner steps below apply only when the tier includes them. Where one of these is missing, use its default:

- Partner: none.
- Ladder: design the case away, or delete the mechanism, or accept the risk. Add a mechanism only for security or data integrity with a real route to failure.
- Comments: the rule in step 3.

## Rules for the whole run

- Do not start while another agent or thread works in the same checkout.
- Act only inside the scope. Report over-engineering elsewhere, and do not touch it.
- Do not propose to remove a capability, or to make what users see worse, for simpler code.
- Commit, push, and merge only with the user's approval.
- Report only results that you verified. Agent summaries of this work have been wrong.
- A change, and each area of a project, gets one simplification, one independent check, and one fix round. Do not add passes. Every extra reviewer finds something more, so "no findings" is not the goal.

## Choose the scope

If the request does not state the scope, look at the branch, the open pull request, and the uncommitted changes. Then ask one question, with a recommendation. Do not ask what the request already answers.

- **Change.** For a branch or a pull request, the scope is the diff from the merge base with the target branch, with uncommitted and untracked work. For uncommitted work alone, it is the diff from `HEAD`. Change only what the README says about the scope.
- **Project.** Follow [the project run](references/project-run.md), which splits the project into areas. Ask in the same question whether to include the README.
- **README alone, or with a project.** Bring it to [the README format](references/readme-format.md), as a separate change. The steps are the same, with a verdict for each section and question 3 of the check.

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

2. Run the project's checks, and keep the commands and the results for the report.
3. Write the "must not weaken" list from recorded product decisions, security, and data integrity. When a verdict depends on a decision that you cannot find, the verdict is Keep, except for the rows of step 2.

## 2. Plan the mechanisms

Write the facts that the verdicts rest on, such as how many instances run or which risks the user already accepted.

Next, list every comment in the scope that excuses a weakness of our own code: an accepted risk, the safe side, rare, at most, can still, a moment later, must match, never happens, or an order that only the comment guards. Read for the meaning, not the words. A reason from outside the code, such as a platform, a library, a standard, a decision of the user, or a third-party bug, does not count. Each comment is a lead, not a verdict: ask which design would make it unnecessary. When a simpler one does, the mechanism goes through the test below, and the comment goes with it. Otherwise step 3 decides about the comment.

Then list the excessive mechanisms. Each one gets a number, its location, a verdict, and the answers to this test, in a sentence each:

1. Which problem does the mechanism solve, and what is its route to failure?
2. What is the simple or common solution to that problem?
3. What in the mechanism exceeds that solution?

If you cannot name the excess, or if its harm is low and the risk of the change is not, the verdict is Keep. "It can go" and "the code gets shorter" are not reasons, and a rule that appears twice is not over-engineering by itself.

| Verdict | When | What the run does |
|---|---|---|
| Redesign | A simpler solution covers the same problem. | Replaces the mechanism. The plan names what the old one told apart. |
| Delete | The problem has no route. | Deletes the mechanism and what serves only it, such as its states, tests, and documentation. |
| Accept the risk | The mechanism exists only for a rare case, and the outcome without it is tolerable. Not for giving up behavior that works. | The same as delete. The plan names the outcome. |

Add a short Keep list for what looks excessive and is not. Group tiny items into one item for each area, without those that have no real excess. Leave out the other mechanisms and the reports of the scan.

Never accept a risk to security or data integrity that has a real route. Check that no verdict rests on something that another verdict deletes, such as a gate that is safe only because of a flag.

Decide everything yourself, except in these cases. Each one is a row for the user, with a recommendation, and most runs have few or none:

- The excess cannot go without a deletion of data, or a change that users would notice.
- The mechanism is a written decision of the user, such as a standard or a skill that they adopted.
- The only route of one-time code is an upgrade or a restore from an old version. Ask which version is the oldest still in use.

Write the plan to a file outside the tracked files. List the bugs that you saw separately, and do not fix them. Have the partner review the plan. Then ask the user one question with the rows, whether to commit, and a link to the plan. The answer starts the run.

## 3. Simplify once

Carry out the approved verdicts. When a verdict rests on how a library, a browser, or a database behaves, prove that behavior first in an experiment, unless you did so for the plan. Keep the tests of kept behavior, and do not change what they assert. When the code or an experiment proves a verdict wrong, correct the plan and go on. Stop only for a new product decision.

Then clean the comments by the user's rule or by this one: no comments in code, which includes tests and doc comments. Two kinds stay. The first is text that a tool or a license requires in that place, such as a lint or type suppression, a shebang, a build flag, or text that a tool generates documentation from. The second is one line that says what would break, when the code looks like a mistake, changing it would break something, no test would fail, and no name can say it. Shorten a longer reason that meets these conditions to that line. Configuration files, environment files, and the settings section of a script are exempt: a comment there may explain a setting. Do not copy a comment into a document, or add code only to carry its reason.

Prove "no test would fail": make the change that the line warns against, run the tests that cover the code, and restore it. When a test turns red because of it, delete the comment. When the file has no tests, say so in the report.

In a change, clean only the code that its diff or the run changed. A comment that excuses a weakness of our own code gets no exception: keep it only when it meets the rule. Do not add one: an accepted risk is written in the plan and the report, not in the code. When you cannot tell whether the rule allows a comment, check the history of its line. If that does not settle it, delete the comment and report it.

Run the project's checks and the partner's result review. Then save `refs/backup/<scope>-after` with the commands of step 1.

## 4. Check independently

Give the check to an agent with a clean context that took no part in the run. For a large diff use two agents, one for questions 1 and 2 and one for questions 3 and 4. Each one gets only:

- The path of [the check brief](references/independent-check.md), which it reads itself.
- The repository, the two refs, and the scope.
- The "must not weaken" list.
- For question 3, the comment rule and the code that the comment step must cover.

Do not pass the plan, your summary, or the review results. They tell the checker what to believe. If no such agent is available, report that the check is missing.

## 5. Fix once

1. Go through every finding, because the checker's ranking is not reliable, and confirm it in the code. The checker does not know the accepted risks, so expect findings about them. Reject one as accepted only when an approved verdict names the same route and the same outcome.
2. Reproduce each regression with a test or a temporary script that fails before the fix.
3. Resolve each finding by the ladder, at exactly the confirmed locations and nothing else. Prefer a fix that adds nothing, or that restores the earlier behavior. For comments, restore only what the comment rule allows, and delete what it forbids.
4. Run the project's checks. The fix is its own change under `cross-review`.
5. Save `refs/backup/<scope>-final`.

A correct finding is not a reason to add code. When only a new mechanism or a larger change would resolve it, do not add it, and bring it to the user with its effect on the merge.

## 6. Report

- Each excess that was resolved, how, and why that is safe. Name the accepted risks and their outcomes.
- The number of mechanisms that changed, and the checks before and after. Give no line counts in any form, not even the change size that `cross-review` reports.
- Any approved change in what users see.
- What the independent check found, and what was fixed.
- Product decisions that wait for the user, and the bugs that were seen and not fixed.
- What was not checked, what stayed open, the comments in doubt, the weaknesses that comments excused and that remain, and the over-engineering seen outside the scope.
- The backup refs. They stay until the user approves the result.
