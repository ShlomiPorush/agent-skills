# Testing and the done checklist

What to test on the server, in the client, and live, and the checklist that decides when the work is done.

## Secrets in tests

Tests hold no fixed secret. Every token, code, key and password a test needs is made at run time with a CSPRNG (`crypto.randomBytes`, `secrets.token_urlsafe`). A CI job generates the stack's secrets for each run and passes them through the job's environment, never through a tracked file. Credentials for external services come from the CI secret store. A fixture file with a working value is a defect, whatever its label.

## Server tests

### OAuth

- Metadata: `issuer` equals the public URL exactly. Both protected resource documents. 404 everywhere while agents are off or the public URL is invalid.
- Registration: public clients only. Each bad redirect URI shape refused. Scopes dropped. The cap and the eviction of unapproved registrations. Requests sent at once cannot pass the per-address limit.
- CIMD: `client_id` mismatch, `http`, another port, an IP address, a host that resolves to a private address, a redirect, a slow answer, a large answer, a compressed answer, and a host the admin trusts for other integrations that resolves to a private address. Each refused with its fixed text.
- Authorize: PKCE missing, `plain`, a short challenge. A redirect URI that differs in host, path or query. Loopback with another port accepted. Every problem shown in the browser, never redirected.
- Device flow: polling too fast gets `slow_down`. A code collected twice ends the grant. An approved code collected just after it expires still works within the grace. Unknown codes count against the address.
- Tokens: a token for `/mcp` refused on the REST API and the other way round. An expired access token refused. A refresh rotates. A reused refresh token ends the grant and its connection record. Revoking an access token ends the grant.
- Hashes: the token store holds no token, code or device code value (search the stored rows for the issued values).
- Ending: past its end, the connection ends for good, and a longer maximum later does not revive it. A deactivated person. A changed identity. A changed public URL, identity provider or sign-in client ends every connection, and changing it back revives none.

### Policy and channels

- The exposure test (`policy-and-channels.md`).
- Every open route refuses a connection without its area, with 403, before route code runs.
- The reserved markers: a route that gets 401 from an upstream service never answers an agent 401 with `error="invalid_token"`, 429 `busy` or 409 `policy_changed`.
- The policy revision: a call with an old or missing revision never reaches route code. `access` and the listing work without it.
- Bearer handling: two `Authorization` headers, a malformed one, a bearer next to a session cookie (the cookie is ignored and the session is not touched), an API key next to a bearer.
- Limits: a body over the cap, an answer over the cap, a call over the deadline (`outcome_unknown`), more concurrent calls than the slots.
- MCP: `tools/list` shows only granted areas. A tool of another area is refused when called. `Origin` allowed, foreign (403) and missing (passes). An audit entry per call with the right outcome, including `unknown` for a timed-out call.

### Consent and management

- Only a signed-in person approves: a bearer, an API key, another person, the same person after signing in again, all refused.
- CSRF: a POST with a foreign `Origin`, no `Origin`, a form content type, all refused.
- An area not offered, or not asked for, is never granted.
- A person cannot list or disconnect another person's connection (404).
- Disconnect all also ends waiting codes, device requests and pending approvals.
- The settings: turning agents off ends every connection. A locked switch says why.

### The race matrix

Run each "make" against each "end" at the same time, many times.

- **Make:** answer consent for an MCP client, approve a device code, exchange an authorization code, collect a device code, refresh.
- **End:** disconnect all, turn agents off, save a shorter maximum, deactivate the person, change the person's identity, change the issuer or the identity provider.

The expected result of every pair: the new connection is made first and then ended, or it is refused. A live connection never remains after the end. For a shorter maximum, "ended" applies when the connection is past the new end.

Also run two refreshes with the same token at once (one wins, and the grant ends), and two saves of the agent settings at once (each reads what the other saved).

## The client contract suite

`templates/test/contract.test.mjs` runs the same cases against every version the machine can run (`MYAPP_IMPLS`), against `templates/test/fake-server.mjs`, a strict stand-in that ends a whole grant when a refresh token or device code is used twice. It covers connecting, waiting, token reuse and refresh (ten commands at once refresh once), lost and broken refresh answers, replace, disconnect, a connection shared between installs, never writing in the skill's folder, the kept address, the safe address check, printed hints run in real shells (bash with `failglob`, zsh, PowerShell, an IPv6 address), the lock cases, the Windows ACL cases, the endpoints list (unknown path, list unavailable, garbage list), each resend rule and each case where an `act` must not be sent twice, and the version and policy headers. `templates/README.md` lists every case.

Run it in CI on the platforms where each version runs: Windows with Node, Windows PowerShell 5.1 and PowerShell 7; macOS with Node and sh; Linux with Node and sh in the product's main checks. `templates/ci/skill-contract.yml` is an example job.

When the product changes the command, add the case to the suite first and run it on all versions.

## Live checks

- Connect a real MCP client (for example Claude Code with `claude mcp add --transport http`) through the browser flow. Call a read tool and an act tool. Disconnect it from the person's page and check the next call fails.
- Install the skill from the product's `/agents/skill/` the way the install note says, on Windows (PowerShell and Git Bash) and on one POSIX system. Connect, read, act, refresh (wait out the access token), disconnect.
- Install the skill from the product's repository (unrendered) and connect with `--url`.
- Check the consent and code pages in every language and theme the product supports, at phone width, and right to left when the product supports it.
- Clean up: disconnect and delete every test connection, registration and device request, and check that none is left.

## Done checklist

- [ ] Shlomi answered every product decision and every library gap.
- [ ] The library mapping covers S1 to S20 of `server-oauth.md`, each with a documented option or a decided gap.
- [ ] Every route is classified, and the exposure test is in CI.
- [ ] Every kind is by effect, and the endpoints listing has a description for every open route.
- [ ] The three reserved markers are produced only before route code, and a test guards them.
- [ ] Tokens, codes and device codes are stored only as hashes, or Shlomi decided the gap.
- [ ] Every way a connection ends is tested, and none revives.
- [ ] The race matrix passes.
- [ ] The consent POST checks `Origin` and JSON, and the cookie is `SameSite`.
- [ ] `/mcp` validates `Origin`.
- [ ] The data sentence is in the client `SKILL.md`, every relevant tool and endpoint description, and the MCP instructions.
- [ ] The enable switch and the maximum period are admin settings with defaults.
- [ ] Every event in `consent-and-management.md` leaves an audit entry, without secrets.
- [ ] Every string people see is in the localization system.
- [ ] People see and disconnect their own connections. Admins see and disconnect every connection.
- [ ] No tracked file holds a working secret value. Every stack refuses to start without its secrets.
- [ ] The contract suite passes on Windows (Node, PowerShell 5.1, PowerShell 7) and macOS (Node, sh) in CI.
- [ ] The skill is served, installs from Git, and the version notice works for both.
- [ ] The live checks passed, and the test connections are gone.
