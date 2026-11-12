# Serving the skill and keeping it current

How agents get the client skill, how a person starts the connection, and how an agent learns that its copy is old without anyone forcing a change on it.

## Two ways to connect, one sentence each

The person's connections page and the admin page show both:

- **An app that speaks MCP** (Claude, ChatGPT, Cursor, a coding agent's MCP setup): the address `<issuer>/mcp`, and for Claude Code the command `claude mcp add --transport http <name> <issuer>/mcp`. The app finds the rest through discovery.
- **A coding agent that runs commands:** one sentence to paste, for example "Install the myapp skill into your personal skills folder as described at `<issuer>/agents/skill/`, then connect to MyApp."

Keep these texts in one module of the server. They are for agents, so they are English.

## Serving the files

`GET /agents/skill/` (pick a path the product does not use) serves an install note. `GET /agents/skill/<file>` serves the skill's files:

- Read each file by the allowlist's own name, never by the name in the request. A path not in the list is 404.
- Fill in the values the scripts carry: the product's address (`__MYAPP_URL__`) and the skill's version (`__MYAPP_SKILL_VERSION__`). In `SKILL.md`, add the address to the sentences that name the product, so a served copy reads right for this installation.
- Serve only while agents are turned on, and only for an address of the safe shape (`client-contract.md`, "Addresses"): the scripts carry it in their code, and the skill prints it in commands. Otherwise answer 404 with a message for the admin.
- `https` only, or `http` on a loopback name for local tries.
- Public: the files hold no secret. `Cache-Control: no-cache`, `X-Content-Type-Options: nosniff`, a text content type for every script.
- Normalize line ends to LF when reading, so a Windows checkout with CRLF does not break the sh scripts.

The install note says:

- which files go into a folder named after the skill in the personal skills folder (Claude Code: `~/.claude/skills/`, or `$CLAUDE_CONFIG_DIR/skills/` when set; Codex: `~/.codex/skills/`), one line per file with its URL;
- to make `scripts/myapp` and `scripts/myapp.sh` executable on Linux and macOS;
- that an existing folder of that name is changed only when an agent installed it from this address (the agent knows it, or the person confirms it). A copy that names another address of the product goes into `myapp-<host>` instead, under the same rule. Any other copy (from Git, a tool, or a link) works as it is: connect with `myapp connect --url "<address>"`;
- that the connection lives in the user's profile, not in the skill's folder, so installing again needs no new approval;
- to read the new `SKILL.md` now, without waiting for skills to reload, and to show the person the link and the code in the reply that ends the turn.

## Installing from Git

The skill's folder works as it is in the product's repository, unrendered, so a tool that installs skills from Git can link it:

- The scripts start with placeholders. A placeholder that was not filled in counts as "no value".
- `SKILL.md` names no address as shipped.
- The command takes the address from `--url`, `MYAPP_URL`, or the address it kept after a working connection.
- The entry point and the sh version are executable in Git (`git update-index --chmod=+x`).
- The skill never writes in its own folder, so the copy stays clean.

## The version notice

The client sends its version on every API call in `X-Myapp-Skill`:

- **A served copy** sends the version the server filled in: a short hash of the skill's files as shipped (for example the first 12 hex characters of SHA-256 over each file's name and content, in a fixed order).
- **An unserved copy** (from Git) sends `r<SKILL_REVISION>`, a number in the scripts.

The `access` route compares it and, when the copy is old, adds `update_skill` to its answer:

- served version differs from the current hash: "A newer skill is available at `<issuer>/agents/skill/`. Go on with your task, and tell the person in one line. Install it again from there only if an agent installed this copy from there (you know it, or the person confirms it). Otherwise do not change its folder. The connection is kept either way."
- `r<n>` lower than the server's `SKILL_REVISION`: "This skill is older than this product. Go on with your task, and tell the person in one line that the skill needs an update where it was installed from. Do not change its folder. The connection is kept."
- `r<n>` equal to or higher than the server's: no notice. A Git copy newer than the server is not told anything.
- No header, or an unknown value: treat it as an old served copy.

It is a notice, never a block: the call still works. `SKILL.md` tells the agent the same rule.

Raise `SKILL_REVISION`, in the server and in all three scripts together, when copies already installed must change: a command, path, header, answer or instruction that an older copy would get wrong. Other changes keep it.

## The client `SKILL.md`

`templates/client-skill.md` is the template. Its sections, in this order:

1. Frontmatter: `name` (the product's command name) and a `description` that says what the agent can do in the product and when to use it.
2. What the product holds, in two sentences, and that the command keeps the connection by itself and its secrets stay inside it.
3. **Running the command**, for sh, PowerShell and cmd, and the JSON answer shape.
4. **Connecting (once)**, the three steps of `client-contract.md`, with the link and the code in the reply that ends the turn.
5. That the connection belongs to the computer user and is shared, and when to `disconnect`.
6. **What you may do**: run `access` and `endpoints` first. The `update_skill` rule. Take every path from the table or `endpoints`. Before every `act` call, tell the person what you will do and get their OK. Never retry `outcome_unknown`.
7. The table of calls, with area and kind.
8. What agents never do in this product, and the data sentence.
9. **When the command cannot run**: the error codes the agent must explain to the person.
