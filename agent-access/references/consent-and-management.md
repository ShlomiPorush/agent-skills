# Consent and management

The pages people use: approving an agent, seeing and ending connections, and the admin settings. Every string on them goes through the product's localization system.

## Who may approve

- Only a person signed in with the browser session approves. A request that is an agent's (a bearer token, the MCP dispatcher) or carries an API key gets 403 on every consent route.
- When the product has two-factor sign-in, require it here as the product does for its other sensitive pages.
- When the person's account cannot hold a connection (for example it did not sign in through the identity provider the fingerprint names), say so and stop.
- A signed-out browser goes through the normal sign-in and comes back to the same request.

## The pending request

- Opening the authorize URL or the code page validates the request first (`server-oauth.md`, S8 and S9), then stores a pending request and sends the browser to the consent page with the request's id.
- The id is random (at least 128 bits). The request is bound to the person and to the sign-in session it was opened under: the person's id, the time of that sign-in, and a random value kept in the session. Another browser, another person, or the same person after signing in again cannot see or answer it.
- It lives 10 minutes, is answered once, and there is a cap on how many wait at a time (drop the oldest). The person's pending requests are dropped when their connections end. All of them are dropped when every connection ends.
- In memory only when the product runs as one process. With several, keep pending requests in the database.

## The consent page

It shows:

- **Who asks:** the agent's name, marked as the name the agent gives itself, which the product cannot prove. For a client metadata document, the host that published it. For the client skill, its label.
- **Where the browser returns:** the redirect host, and whether it is this computer (loopback).
- **Which resource:** the MCP server or the REST API.
- **What it may do:** the areas or scopes the person may grant, each with one sentence, ticked as the agent asked (or a default set), and the person may untick any. Offer only areas the person could use themselves (Comply offers form design only to people allowed to create forms).
- **How long it lasts:** the lifetime rule, in words, with the end date when the end is computed.
- **A warning:** "Approve only an agent you started yourself." For a code: "Check that your agent shows the same code." For a loopback redirect: "Any program on this computer can give itself this name."
- **Approve** and **Deny**.

The product decisions here (areas, defaults, account types such as Comply's personal or shared) come from Shlomi.

## The answer

`POST <consent path>/<request id>` with a JSON body, for example `{"approve": true, "areas": [...]}`.

- **CSRF:** check that `Origin` equals the product's own origin (refuse a missing one), require `Content-Type: application/json`, keep the session cookie `SameSite` (`Lax` at least), and look the request up by its id bound to the session. Each of these covers a gap in the others.
- **Validate before taking.** Refuse an empty selection or an area that was not offered with 400, and leave the request open so the page can fix it.
- **Grant only what was asked and ticked.** An area the agent did not ask for is never granted. A required base area may be always on.
- **Make the grant atomically against ending** (S19 in `server-oauth.md`): take the request only after the locks, so "disconnect all" either dropped it already or waits and then ends what the answer made.
- Answer where the browser goes next: back to the agent with `code`, `state` and `iss`, or `access_denied`. For a device code, a page that says the agent is connected and the person can return to it.
- `Cache-Control: no-store` on every consent and code answer. `X-Frame-Options: DENY` and `frame-ancestors 'none'` on every page of the flow, and `Referrer-Policy: no-referrer`.

## The code page

- The link the agent shows opens it with the code filled in. A person can also type a code.
- The person compares the code with the one the agent shows, then continues to the consent page.
- Count every code tried, per address and per session, and stop for a while after too many. A typed value goes back into the field only when it has the shape of a code, never as markup.
- A code that is wrong, expired or already used says so, and tells the person to start again in the agent.

## The person's connections

A page or area in the person's profile ("My agents"):

- every connection that works now: its name, how it connected (MCP or the skill), the areas, when it was approved, when it was last used, when it ends;
- **Disconnect** for each, effective at once: the agent's next call fails;
- how to connect an agent: the MCP address and the command for a coding agent's MCP setup, and the one sentence that installs the client skill (`distribution-and-versioning.md`);
- it refreshes by itself, and hides while agents are turned off.

A person lists and disconnects only their own connections. Another person's connection answers 404, as one that does not exist. Enforce this on the server, inside the same lock that ends the connection.

## The admin's page and settings

- **Settings** (admin-editable, with defaults, never only environment variables):
  - agents on or off (off by default). Turning it off ends every connection;
  - the maximum connection period, when the lifetime decision has one. Saving a shorter one applies at once. Saving a longer one never revives an ended connection;
  - the reason the switch is locked, when it is (no valid public URL, `http` that is not loopback, the public URL on another origin than the sign-in redirect).
- **Every connection:** grouped by person, with the counts (connections, people, by account type). It stays available while the switch is locked, so connections can still be ended.
- **Disconnect** one, and **Disconnect all**. Disconnect all also cancels unexchanged codes, open device requests and pending approvals, so it stays available when no connection is active.
- An environment variable may also set a setting. Then the environment wins, and the page shows the field as locked and says that the environment sets it.

## Audit events

Each with who acted (the person, an admin, the agent's connection, or the system) and never a secret:

| Event | Details |
|---|---|
| Agent approved | Agent name, how it connected, the areas, account type or lifetime |
| Agent denied | Agent name |
| Connection ended | Connection, reason (from the table in `architecture.md`), who ended it |
| All connections ended | Count, reason, who |
| Refresh token or code reused | Connection |
| Blocked after too many attempts | What was limited, the address, once per window |
| Agent settings changed | Old and new values |
| Tool call | Connection, tool, routes run, outcome |
| API call | Connection, method, route template, outcome |
| Temporary access events | See `temporary-access.md` |

Let admins filter the audit log by agent events.

## Localization

Put every string of these pages, the error pages of the OAuth flow, the code page and the consent warnings in the localization system from the start, with stable error codes across the server boundary. Texts written for agents (tool descriptions, the endpoints listing, the client skill) are English and are not part of the product's UI localization. Keep them in one module.
