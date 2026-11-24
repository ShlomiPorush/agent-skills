# Project run

One request, one approval, and one report. The main agent splits the project into areas, and the user does not pick or follow them. [The skill](../SKILL.md) applies to each area, with the changes below. Read and run from the commit of the default branch, and leave uncommitted work alone.

## Survey and plan

1. Split the project into areas, such as a feature or a subsystem. Look first where the history shows repeated fixes. Write the "must not weaken" list for the whole project.
2. Have subagents scan the areas in parallel, read-only, with the definition and the test of the skill and the leads below. Each one returns the excessive mechanisms with their locations, the answers to the test, and the existing tests, and a short Keep list.
3. Confirm in the code every claim that the plan rests on.
4. Write one plan (step 2 of the skill) for all areas, ranked by the harm that the excess does (bugs and repeated fixes in the mechanism, states that leave a user stuck, code that is hard to change) against the risk of the change. Put verdicts that depend on each other in one area, so that they succeed or drop out together. Mark the security areas, and the areas that change the same files, the schema, or the migrations. Each security area is a row in the question to the user.

A request for a survey alone ends with the plan and its rows, without the partner.

Leads, not verdicts. Read the code and the commit that added it, because some of these mechanisms fixed a real bug:

- Handling of two people who act in the same second, or of a lost answer after a successful write.
- A copy, journal, or backup of data that the database or another source already protects.
- An internal mechanism that leaves the user stuck.
- Custom code for what a library in use already does.
- The same logic in two places that must match.
- One-time migration or repair code that still runs.
- Checks for data that only a hand edit can produce.
- Review ids in comments. The id of a requirement or a design rule is a reason, not a leftover.
- Squashed commits whose body records review rounds.

## Run the areas

1. Create a worktree for the combined result, and take the baseline there (step 1 of the skill).
2. Give each approved area to its own subagent in its own worktree, for steps 1 and 3. A clean agent does step 4, and the area's subagent does step 5. The main agent requests the partner reviews on the area's worktree, at the tier that `cross-review` gives each area. A new product decision waits for the report, and its verdict is left out.
3. Areas that change the same files, the schema, or the migrations do not run in parallel. Each one starts from the combined result so far. Security areas run after the others, and the README last.
4. Combine the areas one by one, and run all the project's checks after each one. Keep one commit for each area if the user approved commits, and otherwise one local ref.
5. Take out an area whose checks stay red, go back to the result before it, and report it. The other areas go on.
6. Write one report (step 6 of the skill), with the checks on the combined result. List the worktrees that remain.
