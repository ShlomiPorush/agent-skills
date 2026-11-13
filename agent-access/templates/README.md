# Client skill templates

These files are code for the target product to ship. They are not helper scripts for this skill. An agent that
installs the product's skill runs one command. The command connects through the OAuth 2.0 device flow (RFC 8628)
after a person approves the code, and then calls the product's REST API within what the person allowed.

The placeholder product is `myapp`. Rename it and set the product constants before you ship anything.

## Files

| File | What it is |
| --- | --- |
| `scripts/myapp` | The entry point agents run (POSIX sh). It runs Node 20+ when present, PowerShell on Windows, and `myapp.sh` elsewhere. |
| `scripts/myapp.mjs` | The Node 20+ version. |
| `scripts/myapp.ps1` | The Windows PowerShell 5.1+ and PowerShell 7 version. It runs `myapp.mjs` when Node 20+ is installed. |
| `scripts/myapp.sh` | The POSIX sh version. It needs only `sh`, `curl` and `awk`. |
| `client-skill.md` | The product's `SKILL.md` template (named so that it is never loaded as a skill of this repository). |
| `test/fake-server.mjs` | A strict stand-in for the product's authorization server and REST API. Like many real servers, it decodes the path before it routes it. Switches make its router match in any case, drop `;` parameters, or pick the static or the dynamic one of two routes that match a path. |
| `test/contract.test.mjs` | The contract suite. It runs against every version the computer can run. |
| `test/package.json` | Runs the suite with `npm test`. |
| `ci/skill-contract.yml` | An example GitHub Actions workflow for the product: shellcheck and shfmt for the sh scripts, and the suite on Windows (node, ps, pwsh) and macOS (node, sh), run only when the skill changes. |

The three versions have one contract. They take the same commands, print the same JSON and error codes, and use the
same files and the same lock. They can run side by side on one computer.

## Adapt the templates

1. Copy `scripts/` and `client-skill.md` into the folder that the product serves its skill from. Copy `test/`
   outside that folder, for example into the product's tests. Installers copy the skill folder from Git as it is,
   and the suite does not belong in an agent's copy. Set `MYAPP_SCRIPTS_DIR` to the scripts folder when you run the
   suite (without it, the suite looks in `../scripts`).
2. Rename the four script files from `myapp` to the product's command name. Keep the extensions.
3. Set the product constants. Each script has one marked block at its top (`Product constants`). Set the same values
   in all three versions, in the entry point, and in the constant blocks of `test/fake-server.mjs` and
   `test/contract.test.mjs`:

   | Constant (mjs / ps1 / sh) | Sample | What it is |
   | --- | --- | --- |
   | `PRODUCT` / `$Product` / `PRODUCT` | `MyApp` | The product's name in messages. |
   | `CMD` / `$Cmd` / `CMD` | `myapp` | The command name in messages and hints. It must match the file names. |
   | `ENV_PREFIX` / `$EnvPrefix` / `ENV_PREFIX` | `MYAPP_` | The prefix of every environment variable (see below). The entry point names `MYAPP_NO_NODE` directly. |
   | `CREDENTIALS_FOLDER` / `$CredentialsFolder` / `CREDENTIALS_FOLDER` | `.myapp` | The credentials folder in the user's home folder. |
   | `CLIENT_ID` / `$ClientId` / `CLIENT_ID` | `myapp-cli` | The OAuth client id of the skill. |
   | `SCOPE` / `$Scope` / `SCOPE` | `read act` | The scope the device flow asks for. |
   | `RESOURCE` / `$Resource` / `RESOURCE` | `/api` | The REST API's resource indicator (RFC 8707), after the address. |
   | `PREFIXES` / `$Prefixes` / `PREFIXES` | `/api/` | Every API path starts with one of these. The token is never sent anywhere else. |
   | `TEMPLATE` / `$TemplatePattern` / `TEMPLATE_RE` | `^/api/...` | The shape of a path template in the endpoints list. Keep it in line with the prefixes. |
   | `ACCESS` / `$AccessPath` / `ACCESS_PATH` | `/api/agent/access` | What this connection may do, and until when. |
   | `ENDPOINTS` / `$EndpointsPath` / `ENDPOINTS_PATH` | `/api/agent/endpoints` | The list of allowed calls. |
   | `DEVICE_PATH` / `$DevicePath` / `DEVICE_PATH` | `/oauth/device` | The device authorization endpoint, after the address. Set it to what the OAuth library serves (some serve under a prefix such as `/api/auth/`). |
   | `TOKEN_PATH` / `$TokenPath` / `TOKEN_PATH` | `/oauth/token` | The token endpoint, after the address. |
   | `REVOKE_PATH` / `$RevokePath` / `REVOKE_PATH` | `/oauth/revoke` | The revocation endpoint, after the address. |
   | `SKILL_HEADER_NAME` / `$SkillHeaderName` / `SKILL_HEADER_NAME` | `x-myapp-skill` | The header that carries the skill's version. |
   | `POLICY_HEADER_NAME` / `$PolicyHeaderName` / `POLICY_HEADER_NAME` | `x-myapp-policy` | The header that carries the policy revision. |
   | `KIND_HEADER_NAME` / `$KindHeaderName` / `KIND_HEADER_NAME` | `x-myapp-kind` | The header that carries the kind (`read` or `act`) the client found for the call. |
   | `KINDS_MAGIC` / `$KindsMagic` / `KINDS_MAGIC` | `myapp-kinds` | The first word of the kept list file. |
   | `DEFAULT_URL` / `$DefaultUrl` / `DEFAULT_URL` | `__MYAPP_URL__` | A placeholder the server fills in (see below). |
   | `SKILL_VERSION` / `$SkillVersion` / `SKILL_VERSION` | `__MYAPP_SKILL_VERSION__` | A placeholder the server fills in (see below). |
   | `SKILL_REVISION` / `$SkillRevision` / `SKILL_REVISION` | `1` | The revision a copy installed from Git sends. Raise it with the server's copy when installed copies must be updated. |

4. Keep only the methods that the product's policy table opens. The scripts accept `get`, `post`, `put`, `patch` and
   `delete`. Remove the commands the product does not use from all three versions, from the help text, and from
   the contract tests.
5. Replace the sample policy table in `test/fake-server.mjs` (`SAMPLE_POLICY`) with routes in the product's shape,
   and adjust the paths in the tests.
6. Search the copied files for `myapp`, `MyApp` and `MYAPP` until none is left. Also replace the sample texts
   that name no product: the example path `/api/items?q=report` and the area `items` in the help and error
   messages, and the example address `https://myapp.example.com`.
7. Run the contract suite (see below) on Windows and on one POSIX system before the first release.

## What the server fills in when it serves the files

- `__MYAPP_URL__`: the product's own address, and only when it matches the safe origin shape
  `^https?://(\[[0-9a-f:.]+\]|[a-z0-9.-]+)(:[1-9][0-9]{0,4})?$`. Otherwise leave the placeholder; the agent then
  passes `--url`.
- `__MYAPP_SKILL_VERSION__`: the version of the served files (for example a hash of their content). A copy that was
  not served sends `r<SKILL_REVISION>` instead. The `access` answer can then tell the agent to update the skill;
  it never forces a change on a copy installed from Git.

Replace these strings textually in every served script. The scripts treat any value that still starts with `__` as
not filled in.

## What the scripts expect from the server

- RFC 8414 metadata at `/.well-known/oauth-authorization-server` whose `issuer` equals the address.
- The device flow at `DEVICE_PATH` and `TOKEN_PATH`, and revocation at `REVOKE_PATH`. The device request
  carries `client_id`, `scope`, `resource` and `client_label` (the connection's name, `Agents on <computer>`).
- Refresh tokens that rotate on every use, where a reused refresh token ends the whole grant.
- `GET <ACCESS>`: what the connection may do. It is exempt from the policy header.
- `GET <ENDPOINTS>` (optionally `?area=<name>`): `{"endpoints": [{"method", "path", "kind", "area", "description"}],
  "revision": "<hash of the policy table>"}`. The kind is `read` or `act` by effect, never by HTTP method. The
  revision matches `^[A-Za-z0-9._-]{1,128}$`. The listing is exempt from the policy header. A listing without a
  valid revision counts as no list.
- The policy header (`POLICY_HEADER_NAME`) and the kind header (`KIND_HEADER_NAME`, `read` or `act`) on every other
  call. The kind header says how the client classified the call from its copy of the list. The policy check runs
  after the router picked the route and before any route code runs. It refuses with the reserved 409
  `policy_changed` when the policy header is missing or differs from the current revision, or when the kind header
  is missing, is not exactly `read` or `act`, or differs from the kind of the route the router picked. Only the
  server knows which route it picked: a router that matches in any case (the ASP.NET Core default) runs
  `/api/items/export` for `/api/items/EXPORT`, and one that drops `;` parameters (Spring, Tomcat) runs it for
  `/api/items/export;x`, while the client matched the read `/api/items/{id}` for both. A refused call never ran, so
  the client may send it again.
- Overlapping routes are allowed. When the list holds a read and an act that both match one path (the static read
  `/api/items/export` and the act `/api/items/{id}`), only the server's router knows which one runs. The client
  sends the call as `act` first. If the server refuses it with `policy_changed` and the list read again still holds
  both kinds for the path, the client sends it once more as `read`. This is safe: if the router had picked the act,
  the `act` declaration would have matched and run, and the client never sends an act again after that. A
  `policy_changed` in answer to the `read` ends the command.
- Exactly three refusals before any route code runs, and no route answers an agent with any of them:
  - 401 with `WWW-Authenticate` that contains `error="invalid_token"`. The client refreshes the token and sends the
    call once more.
  - 429 with the JSON body `{"error": "busy"}`. The client waits and sends the call once more.
  - 409 with the JSON body `{"error": "policy_changed"}`. The client reads the list again and sends the call once
    more under its new kind (for a path that a read and an act both match, as `read`; see above). A second
    `policy_changed` in a row ends the command. When the path names another route on the server than in the list,
    the list read again says the same, so the second refusal ends the command and the route never runs.

  Any other 401, 429 or 409 is passed back to the agent as an error, and the call is not sent again. The client
  reads the `busy` and `policy_changed` markers only from a body that is one complete, strict JSON value (see
  below), so a body that broke off or is not strict JSON never counts as one of these refusals. The marker counts
  only when that value is an object whose own key `error`, exactly in lower case, holds the string `busy` or
  `policy_changed`, as `JSON.parse` reads it (escapes read, the last of two equal keys wins). `{"Error": "busy"}`,
  `{"error": ["busy"]}` and `[{"error": "busy"}]` are not refusals.
- Refusals for agents as JSON `{"error": "<code>", "message": "<text>"}` with a lowercase code. The client passes
  them on as they are.

## Behavior that must stay

Do not remove or weaken these when you adapt the scripts. Each one guards a failure that happened or that the tests
show:

- A call is sent only after its kind is known from the server's list. When the list cannot be read, or its answer is
  not a valid list, nothing is sent (`endpoints_unavailable`). A path that the list does not hold, after the list
  was read again, is not sent (`bad_path`).
- An `act` call is never sent twice once it may have reached the server. A lost answer, an answer that broke off, or
  a 5xx answer is `outcome_unknown`. A `read` is sent once more after a network failure.
- Paths: the kind comes from the path as it is sent, but a server may decode the path before it routes it. So the
  path part (before `?`) may not hold an escape of a character that a route template holds as it is
  (`A-Z a-z 0-9 . _ ~ : -`), nor of `/`, `\` or `%` (`%2F`, `%5C`, `%25` in any case), and every `%` in it must start
  an escape. Such a path is `bad_path`, and nothing is sent. Otherwise `/api/items/7%2Fsend` would match the read
  `/api/items/{id}` in the client while the server runs the act `/api/items/{id}/send`. The query keeps any escape.
  The path part may not hold `;` either (the query may), because some servers drop `;` parameters before they route.
  These rules only narrow the paths the client sends; the server's check of the kind header is what stops a path
  that the server routes differently (another case, an escaped `;`, or any other router rule).
- JSON: an answer counts as JSON, and a request body is sent, only when it is one complete, strict JSON value with
  nothing after it but whitespace, exactly as `JSON.parse` reads it (no single quotes, names without quotes,
  comments, trailing commas, `NaN`, leading zeros, byte order mark or raw control characters). A body that is not is
  `bad_body`, and nothing is sent. A key given twice counts as `JSON.parse` reads it: the last value wins. The sh
  version checks this in `json_scan`, and the PowerShell version in `Read-JsonText`, never in `ConvertFrom-Json`
  alone, which takes more.
- The markers in an answer (`busy`, `policy_changed`, and the failure markers `"success": false` and
  `"status": "error"`) come from the top object's own fields, by their exact keys and JSON types. The sh version
  reads them with `json_scan`, and the PowerShell version from the fields that `Read-JsonText` returns, never from
  `ConvertFrom-Json`, which matches keys in any case, turns other values into strings, unrolls a top array in
  PowerShell 7, and cannot hold some valid JSON (an empty key, two keys that differ only in case, or in Windows
  PowerShell a number beyond the double range). Such JSON is still JSON in every version: it is printed as data,
  and its markers count. Only the list of allowed calls is still read with `ConvertFrom-Json` in the PowerShell
  version, so a listing that `ConvertFrom-Json` cannot hold is no list there. That fails closed.
- The refresh protocol: the access token is reused until a minute before it runs out; a refresh runs under the lock
  with `refreshStartedAt` stored first; a refresh that may still be in flight is never sent again; a refresh whose
  answer was lost is retried once; two lost refresh answers end the connection.
- The lock: created exclusively, never taken from a live holder, taken over from a dead holder by an atomic move,
  and put back when the moved lock was not the dead one.
- The credentials folder belongs to the computer user (`~/.myapp`, or `%USERPROFILE%\.myapp`). Only that user may
  open it. On Windows the scripts set the ACL with `icacls` and `whoami` from System32 and read it back. They never
  loosen permissions silently. Every command that reads the connection's file first checks the folder again, once
  per command and without changing it (the ACL read back on Windows, owner and mode elsewhere), so a folder that a
  restore or a permission change opened to others stops the client with `insecure_credentials` even while its
  access token still works. Credentials never appear in the output, and the sh version never puts them on a
  command line.
- The PowerShell version uses a raw socket for HTTP, never .NET `HttpClient`, which sends a dropped request again
  by itself. It reads the lock, the connection record, the kept list and the kept address with
  `FileShare ReadWrite|Delete`, so that a concurrent command can replace or delete them meanwhile.
- Addresses: https only, except on this computer; only the safe origin shape; the address quoted in every printed
  hint. An IPv6 address in brackets is written as a browser writes it (the WHATWG URL standard: lower case, no
  leading zeros, the first longest run of two or more zero groups as `::`, a dotted IPv4 end in hex), the same in every version, so
  that every version finds the same connection. The PowerShell and sh versions parse it from the text themselves,
  because .NET reads some addresses differently.

## Environment variables

The prefix is `ENV_PREFIX` (`MYAPP_` in the templates).

| Variable | Use |
| --- | --- |
| `MYAPP_URL` | The product's address, when `--url` is not given. |
| `MYAPP_CREDENTIALS` | Another credentials folder. On Windows it must be inside the user profile. |
| `MYAPP_AGENT_NAME` | The connection's name on the approval page, instead of `Agents on <computer>`. |
| `MYAPP_NO_NODE` | Set to run the PowerShell or sh version even when Node 20+ is installed. |
| `MYAPP_WAIT_SECONDS` | How long `connect --wait` waits for the approval (default 90). |
| `MYAPP_LOCK_WAIT_MS` | How long a command waits for the lock (default 20000). |
| `MYAPP_TEST_*` | Test hooks and shorter waits for the contract suite only. |
| `MYAPP_SCRIPTS_DIR` | The contract suite only: the folder that holds the scripts it tests. |

## Run the contract tests

From the folder that holds the suite, with `MYAPP_SCRIPTS_DIR` set to the scripts folder:

```sh
MYAPP_SCRIPTS_DIR=../../skill/myapp/scripts npm test
```

`MYAPP_IMPLS` picks the versions (default `node,ps,pwsh` on Windows and `node,sh` elsewhere). `MYAPP_TEST_TMP`
picks the folder for temporary installs and credentials (default: the system's temporary folder). The suite also
runs the entry points and checks that two versions share one connection. It runs the printed hints in bash with
`failglob`, zsh and PowerShell, and reports the shells it did not find.

The fake server and the tests hold no fixed secret: every token, code and id is made with `randomBytes` at run time,
and the CI job uses no secret. Keep it that way. Never add a fixture with a working token, key or password.

## Replacing an existing client

When the product already ships a client and these scripts replace it, installed copies and the connections they keep
must survive the change:

- Keep the credential file format, the credentials folder and the lock, or migrate them in the new client. A person
  who connected with the old client must not have to approve again.
- Add contract cases that start from files the old client wrote: its connection record and its lock, read by the new
  client; its kept list of calls in an older format, ignored and fetched again; a device flow still waiting for
  approval; a refresh that was cut off.
- Raise `SKILL_REVISION` and the served version, so that installed copies are told to update.
- When the server starts to require the policy and kind headers, old copies get `policy_changed` on every call.
  That refusal must say how to install the skill again, because an old copy may not read `update_skill`.
- Release and deploy the server before installers pick up the new client. A new client against an old server sends
  nothing (`endpoints_unavailable`). Installers from Git should follow a release tag, not the default branch.

## Files in Git

Keep `scripts/myapp` and `scripts/myapp.sh` executable in Git (`git update-index --chmod=+x`). Keep LF line endings
for every script, for example with `* text=auto eol=lf` in `.gitattributes`.
