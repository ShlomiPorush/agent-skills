# Architecture

How agent access is put together, the two shapes it took, and the choices this skill makes where the two products differ.

## The pieces

| Piece | What it does |
|---|---|
| Authorization server | Publishes its metadata, registers agents, runs the authorization code flow with PKCE and the device flow, issues, rotates and revokes tokens. |
| Consent | A signed-in person sees the request and approves or denies it. Approval makes a grant. |
| Connection record | The product's own row for each grant: whose it is, its name, what it may do, how it was made, when it was approved, when it was last used, when and why it ended. |
| Policy core | One check before any route code runs: who the agent acts for, and whether the route is open to agents in an area the connection was granted. |
| REST API | The calls the client skill makes, with a bearer token bound to the REST resource. |
| MCP server | `/mcp`, with tools that go through the same policy core, and a bearer token bound to the MCP resource. |
| Client skill | Served by the product. Its command connects with the device flow and calls the REST API. |
| Management | The person's own connections, the admin's list, the settings, the audit trail. |

## Two shapes: acts as the person, or has its own identity

The products took different shapes. Choose one at step 1 and write the reason in the plan for Shlomi.

**Acts as the person (Comply).** The agent calls the product's own routes as the person who approved it. A dependency that every route carries checks agent requests against the closed route table, then hands the route the person, so the route's own permission checks apply unchanged. MCP tools do not touch data. Each tool names a route, and a dispatcher runs that route in-process through the whole app, under the same check. Choose this shape when:

- the product's routes already enforce per-person permissions, and agents should see and change only what the person could;
- the product has many people with different rights;
- you want one implementation of each operation for people and agents.

**Its own identity (n8n-ops).** Each connection is its own actor in the audit log, with dedicated routes (`/api/v1`, `/mcp`) backed by services written for agents. Choose this shape when:

- the product has one owner or a few admins, and agents act for the installation, not for one person among many;
- the agent's operations differ from the UI's (summaries, cross-instance search);
- the UI's routes are shaped for the browser and would leak too much.

The closed route table and the exposure test apply to both shapes. In the second shape the table is short, but it still classifies every route of the app, so that a new UI route never becomes reachable with an agent token by accident.

## Data model

- **Client.** A registered agent (RFC 7591) or a cached client metadata document. Public clients only. Unapproved registrations have a cap and are cleared after a day.
- **Grant and connection record.** One per approval: two agents, even of the same program, never share one. The record keeps the approving person, the name shown (the agent's own word, cleaned), the areas granted, how it connected (browser or code), the redirect host, the issuer, the approval time, the last use (written at most once a minute), and when and why it ended.
- **Tokens and codes.** Access tokens, refresh tokens, authorization codes and device codes, each stored only as a hash with its kind, its grant, its expiry and, for refresh tokens, when it was used. A used refresh token stays marked, so a second use is seen as reuse.
- **Device requests.** The device code (hashed), the short user code, the label, what was asked, the state (pending, approved, denied, expired), and the approver's choice.
- **Pending consent.** A request waiting on the consent page, bound to the person and the browser session that opened it, for 10 minutes. In memory only when the product runs as one process. Otherwise in the database.
- **Settings.** The enable switch and the maximum period, as admin settings. The fingerprint of the issuer and the identity provider (below).
- **Audit events.** See `consent-and-management.md`.

## How a connection ends

Every end is final. A new approval makes a new connection. An end and all its side effects (the record, the library's grant and tokens, pending requests and codes, temporary access) happen in one transaction, all or nothing.

| End | When |
|---|---|
| Disconnected | The person or an admin disconnects it, or the agent revokes one of its tokens. |
| All disconnected | An admin ends every connection. Waiting codes, device requests and pending consent end too. |
| Turned off | An admin turns agents off. |
| Expired | The connection passes its end under the lifetime rule. A check or a refresh that finds it past its end ends it, so a later, longer maximum never brings it back. |
| Unused | Under an idle rule, no real API or MCP call for the idle period. A refresh does not count as use. |
| Refresh reused | A used refresh token came back. It may have leaked, so the whole grant ends. |
| Code reused | An authorization code or device code was used twice. |
| Person changed | The person's account was deactivated or deleted, or the identity the grant was approved with changed (for example the identity provider's subject). |
| Issuer changed | The product's public address, the identity provider, or the sign-in client changed. Store a fingerprint of these. When it changes, end every connection, and store the new fingerprint, so changing a value back brings nothing back. |

## Where the products differ, and what this skill takes

Where the two products made different choices, this skill takes the stronger one. The table names where each choice comes from.

| Topic | This skill | Taken from | Why |
|---|---|---|---|
| OAuth server | A maintained library, through what it documents | n8n-ops (`oidc-provider`) | Less code to own, and the library tracks the RFCs. Comply's hand-written server states the behavior to match. |
| Which routes agents reach | A closed table of every route, with an exposure test, in both shapes | Comply | A new route cannot become reachable, or silently unreachable, without a decision. |
| Read or act | Kind per route by effect, sent to the client in the endpoints list | Comply | A `POST` search is a read. A `GET` that sends mail is an act. |
| Unknown paths in the client | Refused. Nothing is sent when the list cannot be read. | Comply, made stricter | The client never guesses a path. |
| Contract tests for the three scripts | A Node suite against a strict fake server, in CI on Windows and macOS | n8n-ops | The PowerShell and sh versions break in ways only their own platform shows. |
| Telling an agent its skill is old | An `update_skill` notice that never forces a change | Comply | A copy installed from Git belongs to whoever installed it. |
| Consent CSRF | `Origin` check, JSON content type, `SameSite` cookie, a request id bound to the session | Both | Each covers a gap in the others. |
| Tokens at rest | Hashes only, or a decision for Shlomi when the library cannot | Comply | A database read must not hand out working tokens. |
| `Origin` on `/mcp` | Validated, as the MCP transport specification requires | The specification | A request without `Origin` still passes, so non-browser clients work. A browser-based MCP client on another origin gets 403. |
| Lifetime | A decision for Shlomi | Neither | It depends on the product. |
| Retries in the client | Resend only after the three refusals the server makes before route code runs | Neither, stricter than both | Any other refusal may come after the action ran. |
| PowerShell HTTP | A raw socket, never .NET `HttpClient` | Comply | In Comply's tests, `HttpClient` re-sent a dropped request four times in PowerShell 7, which spends a one-time refresh token twice. n8n-ops did not reproduce it in nine plain-HTTP cases. The raw socket stays as a precaution. |
| PowerShell file reads | Open shared for read, write and delete | n8n-ops | `ReadAllText` blocks another command from replacing or deleting the file, which then fails. |
