# Independent check of a simplification

Someone simplified this code from the ref BEFORE to the ref AFTER. Find what the simplification broke. Answer only the questions below that you were given. This is not a general review, so leave out style, further simplification, and problems that BEFORE already had.

Work read-only. Do not change files, the index, refs, or branches. Use the history before BEFORE (`git log -S`, `git blame`) to learn why removed code existed. Do not read commits, notes, or reviews that came later than AFTER. Read whole functions in both refs, because a diff hides the code around it.

List the changed product files first, and go through all of them. Follow a change to its callers and clients, also when their own files did not change.

## 1. Deleted code

For every deleted function, route, branch, guard, and cleanup, name the reachable case that it handled, if there is one, and find where AFTER handles that case. Start with the error paths. For each `catch`, `finally`, early return, and timeout, list what was already acquired or registered at that point, and say who releases it now. Report every feature, setting, or screen that is gone or works worse.

## 2. Replaced mechanisms

This is where simplifications usually break. For every simpler piece of code that took over from a mechanism, write down what the old code told apart and the new code does not. Check at least these pairs:

- Still loading, or deleted.
- Changed, or unchanged.
- Failed, or empty.
- Not sent, or sent without an answer.
- Absent, or set to an empty value.

For each lost distinction, find the input or sequence that reaches it and follow it to its result for the user or the data.

## 3. Comments

Judge the comments by the comment rule that you were given. Extract them with a command, file by file, and judge each one:

1. Every deleted or shortened comment in the diff, also on code that the branch itself added. Report each reason or required text that the rule allows and that is gone while its code is still there, and each comment whose new text is wrong. Quote the old text.
2. Every comment in AFTER, in the code that the comment step must cover, also in files that did not change. Report each one that the rule forbids, also when BEFORE already had it.

Treat a warning, limit, requirement, or command that the documentation lost as a finding too, and report documentation that is no longer true.

## 4. Client side

For every view, form, and client request that the change touches or that uses a changed server answer, check:

- The data is refreshed after each change that affects it.
- The loading, failed, and empty states behave correctly, also when the user acts in them.
- Every field, code, and message that the client uses is one that the server still sends or accepts.

## What to return

Rank the findings by their result for security, data, and the user, with the worst first. List the comment findings separately at the end.

For each finding: the location in BEFORE and in AFTER, the concrete route that reaches it, the result, and whether you ran it or traced it. Drop a finding that has no route. A comment finding needs no route. Then say, for each question, which files you covered and which you did not.
