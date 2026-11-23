# README format

The README is the project's front page. A visitor learns from it what the project is, why to use it, and how to start. It is not the manual, and it is not a record of the work.

Use these parts, in this order. Leave out a part that has no content.

1. The title, with a tagline of one line or a designed header.
2. A screenshot of the product, or a short video.
3. A longer description: what it does, and for whom. A notice that a reader needs before installing, such as "unofficial" or "beta", goes here in one line.
4. The main features, as a short list. Do not list every feature.
5. Installation: the requirements, and the shortest path that works. Updating and uninstalling are one line each.
6. Common questions and problems.
7. Links to the documents, such as configuration, security, development, and the changelog. This is the only part that links to them, so the other parts stand on their own.
8. The stack, in a collapsed `<details>` block.
9. The license and credits, in a line each.

Do not add other sections. A section that the user asked for, or an existing one that thanks an outside person for a real contribution, stays above the license and credits.

## Clean an existing README

Give every section one verdict in the plan:

- **Keep or shorten** what fits a part above.
- **Move to `docs/`** what a user or a maintainer still needs: how a feature behaves, a setting, a command, a limit, a warning, a security guarantee, a procedure. Condense the text, but keep each such fact, and correct it when it is wrong. Use an existing document when one covers the subject.
- **Delete** repetition, history of changes, and internal mechanics that the code shows.

Before you move or delete a section, search the code, tests, error messages, configuration comments, and other documents for references to it. Update each one in the same change.

Do not invent features, questions, or images. Report a missing screenshot.

If the project's agent instructions or saved memory tell agents to record every change in the README, propose new wording that points to `docs/`, and change saved memory only after the user approves. Otherwise the README fills up again.
