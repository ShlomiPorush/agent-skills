# The client skill's command

The contract that the bundled templates (`templates/scripts/`) implement in three versions: `myapp.mjs` (Node 20+), `myapp.ps1` (Windows PowerShell 5.1 and PowerShell 7) and `myapp.sh` (POSIX sh, curl and awk), with the `myapp` entry point picking one. The three keep the same commands, answers, error codes, files and lock, so they can run side by side for one user. The contract suite in `templates/test/` holds them to it.

## Why three versions

An agent runs the command on the person's computer, with whatever is installed there. Node covers most developer machines. Windows always has PowerShell. Every other system has sh and curl. Nothing has to be installed.

## Commands

| Command | Does |
|---|---|
| `connect [--url "<address>"]` | Asks to connect. Answers `pending` with `link`, `code` and `next`, or `already_connected`. |
| `connect --replace` | Asks for a new code even while one is open, for when the link did not work. A working connection is replaced only once the new one is stored. |
| `connect --wait` | Polls until the person approves, up to about 90 seconds. Answers `connected`, `still_waiting`, `denied` or `expired`. |
| `status` | Whether this computer user is connected. No secret in the answer. |
| `access` | `GET` the `access` route. |
| `endpoints [area]` | `GET` the endpoints listing, and keeps it with its revision. |
| `get`, `post`, `put`, `patch`, `delete '<path>'` | One API call. `--json '<body>'` or `--json-file <file>` for a body. Keep only the methods the product's table opens. |
| `disconnect` | Revokes the connection on the server, then forgets it. For every agent of this user. |

Every answer is one line of JSON on stdout. A call answers `{"status": <http>, "data": <answer>}`. On failure the exit code is 1 and the answer is `{"error": "<code>", "message": "<text>"}`. The agent tells the person the message as it is.

## Error codes

| Code | Meaning | What the agent does |
|---|---|---|
| `no_url` | No address given, served or kept | Ask the person for the address, then `connect --url "<address>"`. |
| `insecure_url` | Not `https`, or `http` that is not loopback, or not a plain origin | Ask for the right address. |
| `insecure_credentials` | The credentials folder or a file in it is a link, belongs to another user, or others can open it | Tell the person the fix the message gives. |
| `cannot_save` | Cannot write the credentials folder (often a sandbox) | Tell the person. Never keep the secrets anywhere else. |
| `unreachable` | Cannot reach the product, or the answer broke off | Tell the person. |
| `busy` | Another command holds the connection, or the connection runs too many calls. Nothing was sent. | Run it again. |
| `not_connected`, `connection_ended` | No connection, or the server ended it | Connect again. |
| `denied`, `expired` | The person denied, or the code ran out | Start again only if the person wants to. |
| `bad_path` | A path that is malformed or not in the endpoints list. Nothing was sent. | Take the path from `endpoints`. |
| `endpoints_unavailable` | The endpoints list could not be read. Nothing was sent. | Try again later. |
| `policy_changed` | The server refused the call twice before running it: its calls changed, or the path names another call than the list says. Nothing ran. | Run `endpoints`, take the path from it, then decide again. |
| `outcome_unknown` | An `act` call may have run, and its answer was lost or was a server error | Read the state, tell the person. Never send it again blindly. |
| `bad_body` | The body is not JSON or the file cannot be read | Fix the body. |
| `unexpected_answer` | The server answered in a shape the command does not accept | Tell the person. |
| `failed` | A 2xx answer that says it failed | Tell the person. |
| `http_<status>` and the server's own codes | The server refused | Tell the person. |
| `node_too_old`, `missing_curl` | The runtime is missing (`missing_curl` comes from the sh version only) | Tell the person what to install, or use another version. |
| `unknown_command` | A command the script does not have | Run `help`. |
| `disconnect_failed` | The server did not confirm. The token is kept to revoke later. | Run it again, or disconnect on the product's page. |

## Connecting

1. `connect` checks first that it can write the credentials folder and that the address answers as the product (its authorization server metadata names the same issuer). Then it asks for a device code with the scopes, the REST resource and its label (`Agents on <computer>`, or the value of `MYAPP_AGENT_NAME`).
2. It answers `pending` with the link, the code, and `next`: "End your turn with a reply that shows the person the link and the code and asks them to reply once they approve. When they reply, run: myapp connect --wait --url "<address>"". The address in `next` is quoted, so a shell never reads an IPv6 address's brackets as a pattern.
3. The agent shows the link and the code in the reply that ends its turn, with the code on its own line. Agent apps fold text written between commands, so a link printed mid-turn is often never seen.
4. When the person replies, the agent runs `next`. Only when its tools can keep a command running after the turn and wake it, it may start `next` in the background before that reply.
5. On `connected`, the command keeps the address in the credentials folder for later commands.

## Credentials

- **Where:** `~/.myapp` (`%USERPROFILE%\.myapp`), or `MYAPP_CREDENTIALS`. On Windows the folder must be inside the user profile. Never the skill's folder: it may be read-only, come from Git, or be shared by several installs.
- **One connection per user and address.** The file name is a hash of the issuer, so every agent install of the user (each tool, account and session) shares one connection, and a second product address gets its own.
- **Owner-only, checked, never loosened.** On POSIX the folder is 0700 and files 0600, and the command refuses a folder or file of another user or open to others, with the `chmod` that fixes it. On Windows it limits the folder to the user, SYSTEM and Administrators with System32 `icacls`, makes the user the owner, then saves the ACLs (`icacls /save`) and refuses any other allow entry, or any entry that is not a plain allow or deny. It never changes permissions back silently.
- **Plain files only.** A link in place of the folder, the record, the lock or the kept address is refused.
- **Never printed.** No answer, message or log line holds a token or a device code.
- **Written in one step:** a private temp file, flushed, renamed over the old one. Every value written is checked to hold no quote, backslash or control character, so the sh version reads the same file.

## The lock

Every change to the connection's file and every request that spends a one-time secret (a device code poll, a refresh, a revoke) runs under one lock file per connection.

- The lock is a file created exclusively, holding the holder's process id, host, a random token and the start time.
- Never take it from a live holder, however old. After about 20 seconds the waiter answers `busy`, and says when a holder has held it for over 10 minutes.
- A holder that died (same host, process gone), or an empty lock older than a minute, is taken over by moving the lock aside atomically, so of two takers only one wins. If what was moved is not the dead lock, it goes back unless a newer one is there.
- Before spending a one-time secret, check the lock is still this command's. If not, send nothing and answer `busy`.
- On Windows, a just-deleted lock name can refuse creation for a moment: wait instead of failing.

## Refresh

- Reuse the access token until a minute before it expires.
- Refresh under the lock. Write `refreshStartedAt` before sending, so a refresh in flight is visible to other commands.
- A refresh that started less than about 30 seconds ago may still be on its way: never send it again. Answer `busy`.
- When the last refresh got no answer, try once more: that either continues the connection or ends it on the server, which also ends the token nobody received. Two refreshes without an answer end it locally with `connection_ended`.
- A refresh that never left the computer (name, connection or TLS failed first) keeps the token as it was.
- `invalid_grant` means the connection ended: forget it (keep old tokens still to be revoked) and answer `connection_ended`.
- New tokens that arrive after the lock was lost are still stored, under a fresh lock.

## Sending calls

- **Sent or not sent.** A failure before the request left (name resolution, connection refused, TLS) is "not sent". An answer that started and broke off counts as sent.
- **No automatic resends by the HTTP stack.** The PowerShell version speaks HTTP over a raw socket, one connection per request. .NET `HttpClient` re-sent a dropped request by itself.
- **No redirects.** A token never follows one to another address.
- **Paths.** Only characters valid in a path and query, no `://`, no leading `//`, no `.` or `..` segments, under the product's API prefixes, and the resulting URL must stay on the issuer's origin. In the path part (before `?`): no `;`, no `%` that does not start a valid escape, and no escape of `/`, `\`, `%` or of any character a template holds as it is (letters, digits and `. _ ~ : -`), since a server that decodes it could route the path elsewhere. Query values keep them.
- **Kind from the server.** Before a call, find its kind in the stored endpoints list (method and path template). `access` and the listing are reads. When the list is missing or stale, fetch it. When fetching fails or the answer is not a valid list, send nothing: `endpoints_unavailable`. When the fresh list does not hold the path: `bad_path`, nothing sent. When the path matches templates of both kinds (a static `/items/export` and a dynamic `/items/{id}`), declare `act` first. After a `policy_changed` refusal, when the fresh list still gives both kinds, send once more declaring `read`. Each of these resends follows a refusal made before any route code ran, so the action still runs at most once.
- **The policy and kind headers** carry the stored list's revision and the kind found for this call, on every call except `access` and the listing. The server refuses a call whose declared kind differs from the route it picked, before that route runs.
- **The reserved refusals are exact.** "JSON `{"error": "busy"}`" means a body that is one JSON object, with the lowercase key `error` whose value is the string `busy`. The last of duplicate keys wins, as `JSON.parse` does. A key in other letter case, a value that is not a string, or a top-level array is not the marker. The same holds for the failure markers of a 2xx answer (`"success": false`, `"status": "error"`). Read them from the document's structure, never through a parser that ignores case or loses keys (PowerShell's `ConvertFrom-Json` does both).
- **Resends, all at most once per call:**
  - 401 with `error="invalid_token"`: refresh and send again;
  - 429 with `{"error": "busy"}`: wait briefly and send again;
  - 409 with `{"error": "policy_changed"}`: fetch the list, find the kind again, send again. A second one fails with `policy_changed`;
  - a read whose answer was lost: send again.
- **An act is never sent twice otherwise.** If an `act` call may have reached the server and its answer was lost, or the server answered 5xx, answer `outcome_unknown`. Any other 401, 409 or 429 is passed back as it is.
- **The version header** (`X-Myapp-Skill`) carries the skill's version on every call: the version the server filled in, or `r<SKILL_REVISION>` for a copy that was not served.

## Addresses

- `--url`, then `MYAPP_URL`, then the address the server filled in, then the kept address.
- Accept only a plain origin after parsing: `https` (or `http` on `localhost`, `127.0.0.1` or `[::1]`), a host of letters, digits, dots and hyphens or a bracketed IPv6 address, a port from 1 to 65535, nothing else. URL parsers keep characters such as `$(` in a host. The address goes into printed commands, so nothing a shell would run may reach it.
- A kept address is one line. Anything else in the file makes it invalid, not a different address.
- Windows PowerShell 5.1 writes `[::1]` out in full: compare origins after one normalization.

## Platform notes

- **Windows tools by full path.** Run `whoami` and `icacls` from `%SystemRoot%\System32`. Under Git Bash, another `whoami` comes first on the `PATH`.
- **Windows file reads.** Open the lock, the record, the kinds file and the kept address with `FileShare` `ReadWrite` and `Delete`. A read that shares only for reading makes a concurrent replace or delete fail.
- **Windows renames.** An antivirus scan can hold a file for a moment. Retry a refused rename for a few seconds.
- **Git Bash.** The entry point sets `MSYS_NO_PATHCONV=1` and `MSYS2_ARG_CONV_EXCL='*'`, or Git Bash turns an argument such as `/api/notes` into a Windows path.
- **sh.** Temp files in a private folder per command, removed whole. No `local`, no arrays. JSON is read with awk, so the server's answers that the command parses keep a simple shape.
- **PowerShell.** Run with `-NoProfile -ExecutionPolicy Bypass -File`, which bypasses the policy for that one process only. Avoid cmdlets whose modules may fail to load under PowerShell 7 when Windows PowerShell runs the script (use `icacls`, not `Get-Acl`).
