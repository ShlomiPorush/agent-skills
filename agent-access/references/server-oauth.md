# The authorization server

What the authorization server must do, how to pick the library that does it, and how to handle what the library cannot do. The requirement ids (`S1` to `S20`) are for the library mapping in the plan for Shlomi.

## Choose the library first

1. Find what the target already uses for sign-in, sessions and OAuth. A library that is already there and can act as an authorization server comes first.
2. Otherwise pick an established, maintained OAuth 2.1 authorization server library for the stack: recent releases, a published security policy, documentation for every feature you map. Examples: `oidc-provider` for Node, Authlib's authorization server for Python, Spring Authorization Server for Java. Check the current state of each before you name it.
3. Map every requirement below to a feature, an option or an official extension the library documents. Name the option. A requirement met only by undocumented internals is a gap.
4. List the gaps. For each, give Shlomi the options: another library, a documented extension point that may meet it, or accepting the gap. Do not write code around the library to close a gap.

The library owns the protocol: the endpoints, the grant types, the token formats, the storage interface. The product owns the consent page, the connection record, the policy core and the settings. Glue between them goes through the library's documented hooks (its interaction or consent callbacks, its storage adapter, its events).

## Requirements

### Discovery

- **S1. Authorization server metadata (RFC 8414)** at `/.well-known/oauth-authorization-server`. `issuer` is exactly the product's public origin, the same string tokens and redirects carry. List `S256` as the only PKCE method, `none` as the only client authentication method, and the device authorization endpoint.
- **S2. Protected resource metadata (RFC 9728)** for each resource: `/.well-known/oauth-protected-resource/mcp` and `/.well-known/oauth-protected-resource/<rest prefix>`. Also serve the bare `/.well-known/oauth-protected-resource` for the MCP resource, since clients try it without a hint. Each names its `resource`, `authorization_servers`, `scopes_supported` and `bearer_methods_supported: ["header"]`. Public, `Cache-Control: no-store`.
- **S3. The issuer comes from the product's public URL setting**, never from request headers. With no valid public URL, every OAuth route answers 404 and the admin page says why. Plain `http` only on exactly `localhost`, `127.0.0.1` or `::1` (not all of `127.0.0.0/8`), for local tries. The issuer must be the origin exactly as a browser serializes it (the WHATWG URL rules), because the consent page and `/mcp` compare it with the `Origin` a browser sends. Refuse a public URL that a browser would spell differently, and say why on the admin page: a host with non-ASCII letters (a browser sends the `xn--` form, and some IDNA codecs map letters differently), a short or hex IPv4 form, an IPv4-mapped IPv6 address. Do not rebuild the browser's normalization in the product.
- **S4. Every answer sent back through the browser carries `iss` (RFC 9207)** and returns `state` unchanged.

### Clients

- **S5. Registration (RFC 7591), if offered.** Public clients only (`token_endpoint_auth_method: none`). Redirect URIs: `https` anywhere, `http` only on the three loopback names, or a private-use scheme in reverse-domain form (RFC 8252). No fragment, no user info, at most a few per client. No registration access token. Drop any scopes the client asks for at registration: the person decides what it may do. Cap the stored registrations. When full, evict the oldest that no person approved. Clear unapproved registrations after a day.
- **S6. Client metadata documents (CIMD), if offered.** A `client_id` that is an `https` URL names a document. Fetch it only on the authorize page, for a signed-in person. Accept `https` on port 443 with a host name, never an IP address. Resolve the host, refuse any address that is not public, and connect to the address you checked, with no second resolution. No proxy from the environment, no redirects, a deadline, a size cap, no compressed answer. Hosts an admin trusts for other integrations never widen this. The document's `client_id` must equal the URL. Accept a client that lists `none` among its supported methods even if it prefers another. Cache good documents for a bounded time. Do not cache failures. Show the person a fixed text for each failure, never the remote server's words.
- **S7. A built-in public client for the client skill**, with only the device grant and refresh. It may send a `client_label`: keep it only when it is plain text (letters, marks, digits, spaces and `. _ - ( ) @ : /`, 1 to 60 characters after NFC normalization). Otherwise call it "Script".

### Authorization

- **S8. Authorization code with PKCE.** `S256` only, a challenge of 43 to 128 characters, `response_type=code` only. A redirect URI must match a registered one exactly, except that a loopback `http` redirect may use any port (RFC 8252 7.3). Show every problem in the browser. Never redirect it to the client, because anyone can register a redirect URI.
- **S9. Device flow (RFC 8628).** A secret device code for the agent, a short user code for the person (base-20 consonants, shown as `XXXX-XXXX`), 10 minutes, a 5-second interval, `slow_down` when polled too fast. `verification_uri_complete` opens the code page with the code filled in. An approved code can still be collected for a few minutes after it expires. Cap the open device requests.
- **S10. Resource indicators (RFC 8707).** Two resources: `<issuer>/mcp` and `<issuer>/<rest prefix>`. A token is issued for one of them and is valid only there. A refresh keeps the resource.
- **S11. Consent is the product's page.** The library hands the request to the product's consent page through its documented interaction hook. See `consent-and-management.md`. Each approval makes a grant of its own. Never reuse an existing grant for a new approval.

### Tokens

- **S12. Lifetimes.** Access tokens 15 minutes, opaque. Authorization codes 60 seconds. The refresh token's lifetime and the connection's end follow the lifetime decision. An access token never outlives its connection's end. The product enforces the lifetime by its own clock, on every call and when the setting is saved. An idle rule counts real API and MCP calls, never a refresh. Set the library's refresh token lifetime to at least the longest lifetime an admin may choose, plus a margin, so the library never ends a connection by itself. A token issued earlier keeps the expiry it was issued with until its next refresh.
- **S13. Rotation.** Every refresh returns a new refresh token and spends the old one. Consuming is atomic: of two requests with the same refresh token or code, one wins, and the other is treated as reuse.
- **S14. Reuse ends the grant.** A spent refresh token or code presented again ends the whole grant, with its connection record, and leaves an audit entry.
- **S15. Revocation (RFC 7009).** Revoking any token of a grant, including an access token, ends the whole grant. Answer 200 for every well-formed request, known token or not.
- **S16. Hashes at rest.** Store every access token, refresh token, authorization code and device code only as a hash (SHA-256 of a CSPRNG value of at least 256 bits). Look tokens up by hash. Never log a token. If the library stores token values as they are, and documents no way to store hashes, that is a gap for Shlomi (see the `oidc-provider` notes below).
- **S17. Check on every call.** Before any route code runs: agents are turned on, the token is valid for this resource, its grant has not ended and is not past its end, the person exists, is active and has the identity the grant was approved with. "Not ended" means both the product's connection record and the library's own grant, found through the library's documented lookup: a library may delete its grant (on refresh reuse, for example) before the event that ends the record arrives, and a token just issued would pass for that moment. A failure that is about the connection ends the connection for good.
- **Identity changes.** A hook that ends connections because the person changed (a password or two-factor reset, a new subject) ends them before the change or in the same transaction, and only for a caller who is signed in and allowed to make the change: an unauthenticated request ends nothing. Ending them when the change then fails is acceptable. When the session cannot be read, fail closed. While a change is in progress, block approvals for that person only, tracked per change and cleared on every path, including errors. Never use one shared flag or the flag's age.

### Ending, races and limits

- **S18. Issuer and identity provider fingerprint.** Store a hash of the public URL, the identity provider's issuer or discovery URL, and the sign-in client id. When it changes, end every connection and store the new value. Check it at start-up, on every token check, and before making a grant.
- **S19. Making and ending are atomic against each other.** Making a connection (answering consent, issuing a code, collecting a device code, exchanging a code) and ending connections (disconnect one or all, turning agents off, a shorter maximum, a person deactivated or changed, a new fingerprint) never interleave: the new connection is made first and then ended, or it is refused. Use the library's documented transaction or storage hooks. If it offers none, that is a gap for Shlomi. Comply's worked example is one lock order used everywhere: a gate row (exclusive for "end everything" and for saving agent settings, shared for making a grant), then the person's row, then the pending request or code, then grants by id, then their tokens. Ending a connection and all its side effects (its record, the library's grant and tokens, pending requests, temporary access) is one transaction: all of it or nothing.

  When the library runs its own actions with no transaction the product can join, n8n-ops's worked example on PostgreSQL is a gate and a counter:

  - an advisory lock gate, taken exclusive by every "end everything" and shared by consent;
  - a generation counter that each "end everything" raises after it takes the gate;
  - the library's documented middleware reads the generation when a flow starts and records it per interaction or device code. Consent requires the current generation, so a flow that began before an end is refused.

  Pitfalls it found: PostgreSQL `now()` is the transaction's start time, and the library sets a token's `iat` when it saves it, so no timestamp proves that a request began before an end (hence the counter). The storage adapter needs its own connection pool while consent holds a transaction on the main pool, or the two pools deadlock under load. A limit of any design where the library's issuance cannot join the product's transaction: issuance inside the library (refresh, code exchange, device collection) at the same moment as an end can store records for an ended grant. They are harmless only because the check of S17 refuses them and the sweep removes them. Name this to Shlomi as part of the gap.

  Rate limits and pending consent kept in memory need one process. With several, move them to the database. `testing.md` has the race matrix.
- **S20. Rate limits and clean-up.** Per address: registrations, device requests, authorize, token and revoke, code lookups on the code page (also per session), polls with a device code that cannot succeed. Count a request before the first `await`, so requests sent at once cannot all pass. Give a counted poll back once its code turns out to be waiting or approved. Behind a proxy, take the client address from `X-Forwarded-For` only when the socket is a trusted proxy, and then take the last entry. Key a per-session limit by the verified, signed session cookie, never by text the caller controls. Keep the quota for `/token` and `/revoke` apart from device polls, or give polls back through the library's documented post-request middleware: with one shared quota, agents waiting on device codes behind one address starve refresh and revocation for everyone there. A lock or slot taken around a library request is released when the library finishes the request, never on a timer, and on every path, including a failed database read in middleware. Test that path with an injected fault. A periodic job removes expired records, long-ended grants and unapproved registrations. Requests check expiry themselves and never wait for the job.

## Secrets

No tracked file holds a working value for any of these, in any environment. Example files list names with empty values.

| Secret | Production | Development | Test and CI |
|---|---|---|---|
| The library's cookie or signing keys | From the installation's secret store or generated once at install into its data volume, never regenerated on start | Generated once with a CSPRNG into an ignored owner-only file (0600, or the owner-only Windows ACL), never overwritten | Generated for each run |
| The key that encrypts stored secrets (for example the temporary-access key copy) | Generated once per installation and kept. Regenerating it loses the data it protects. | As above | Generated for each run |
| Database credentials | The deployment's secret store | As above | Generated for each run |
| Credentials for external services (mail, chat) | The product's settings, encrypted with the key above | The local secret store | The CI secret store |

Every stack refuses to start when a secret it needs is missing or equals an example placeholder, and says which one. A value that was ever committed is public: never reuse it, and tell Shlomi it must be replaced wherever it is still in use. Tokens, codes and device codes are not configuration. The server makes them with a CSPRNG at run time. The bundled fake server does the same.

## `oidc-provider` notes (n8n-ops)

n8n-ops built its server on `oidc-provider` 9. Most requirements map to documented options. The table names the option to use, which is not always what n8n-ops wrote:

| Requirement | `oidc-provider` option |
|---|---|
| S1 | `clientAuthMethods: ["none"]`. The default lists five methods. |
| S5 | `features.registration: { enabled: true, issueRegistrationAccessToken: false }`. For the product's own rules (redirect URI shapes, dropping a requested `scope`), list one property in `extraClientMetadata.properties`: its documented `validator` then runs on every registration and update, whether or not the client sent that property, and may check and change the client's `metadata`. Do not rewrite the request body before the provider reads it. `features.pushedAuthorizationRequests.enabled: false`, so every request passes the authorize checks. |
| S6 | `features.clientIdMetadataDocument` (experimental in 9.x, enabled with an `ack`), with `allowFetch` to refuse a URL before the fetch and `allowClient` to refuse a resolved client. Whether the library's fetch connects to the checked address, ignores the environment's proxy and refuses redirects (S6) must be checked in its documentation for the installed version, including its documented hooks for outgoing HTTP requests. What it does not cover is a gap for Shlomi. |
| S7 | A static client in `clients` with `token_endpoint_auth_method: "none"`, the device grant and `refresh_token`, no redirect URIs. `extraParams: ["client_label"]` for the label. |
| S8 | `pkce: { required: () => true }`. `features.devInteractions.enabled: false`. |
| S9 | `features.deviceFlow` with `charset: "base-20"`, `mask: "****-****"`, and the page hooks `userCodeInputSource`, `userCodeConfirmSource`, `successSource`. |
| S10 | `features.resourceIndicators` with `defaultResource`, `useGrantedResource: () => true`, and `getResourceServerInfo` that throws `InvalidTarget` for any other resource and sets `audience`, `accessTokenFormat: "opaque"` and `accessTokenTTL`. |
| S11 | `interactions.url` to the product's consent page. `loadExistingGrant` returns only the grant this approval made. `features.dPoP.enabled: false`, since the resources do not check sender-constrained tokens. |
| S12, S13 | `ttl`, `rotateRefreshToken: () => true`, `issueRefreshToken`, `expiresWithSession: () => false`. `ttl.RefreshToken` is the longest lifetime an admin may choose plus a margin. The library never changes an existing token's expiry. |
| S14 | The storage adapter's `consume` is atomic (an update guarded by "not consumed yet"). The loser ends the grant. |
| S15 | `features.revocation.enabled: true` and `revokeGrantPolicy: () => true`, so revoking an access token ends the grant too. |
| S17 | The bearer check also finds the grant with `provider.Grant.find` and ends the connection when it is gone. On refresh reuse the library deletes the grant first and fires its event later. |
| S3 | The provider is built for the issuer from the public URL setting. When the setting changes, a new provider is built and connections under the old issuer end. `provider.proxy = true` behind a TLS proxy. |

The product's code around it: the consent page and its API, the connection record (written when the person approves, ended on `grant.revoked`), the sweep that ends connections past their lifetime by the product's own clock, and the bearer check on `/mcp` and the REST API, which finds the token through the provider, checks its `aud`, and checks that the connection record has not ended.

**S16 is a partial gap.** These facts hold for `oidc-provider` 9.13.3. Check them again for the version you install.

- An opaque token's value is its `jti` (`lib/models/formats/opaque.js` returns `{ value: token.jti, payload }`). The storage adapter receives that value as the record id, and the stored payload carries `jti` as well (`IN_PAYLOAD` in `lib/models/base_model.js`). No documented option stores values hashed.
- Access tokens, refresh tokens and authorization codes are found only by the value the client presents. An adapter can therefore store them under `sha256(id)`, drop `jti` from the stored payload, and put it back from the presented id on `find`. Lookups by user code or by uid return nothing for these kinds. Existing rows can be converted in place by a migration, so no connection ends.
- Device codes cannot be hashed this way. The library finds the record again by its stored id (`DeviceCode.findByUserCode`, then the device action in `lib/actions/authorization/device.js`) and saves it under its `jti`.
- The hashing rests on behavior the library does not document (the value equals `jti`, and these kinds are looked up only by the presented value). Pin it with tests that fail when `upsert` receives an id that is not its payload's `jti`, and that issue, find, consume and revoke each kind through the adapter. Run them on every library update.

Bring S16 to Shlomi with the options: hash the three kinds and convert in place, accepting the short-lived device codes as a gap; the same, but end every connection once (when old database backups exist outside his control, since they keep the values that were current then); accept the whole gap with the database encrypted at rest; or another library.

**Other known gaps in 9.13.3.** No per-code `slow_down`: `SlowDown` is defined in `lib/helpers/errors.js` but never thrown (S9). An approved device code cannot be collected after it expires, since the grant checks expiry before approval (S9). Reported but not verified here: some authorization errors are redirected to the registered redirect URI rather than shown in the browser (S8). Each is a gap for Shlomi.

## Comply's behavior statement

Comply wrote its server by hand (FastAPI, `app/agent_access/oauth.py`, `store.py`, `cimd.py`). Use it to see what a requirement means in practice, not as code to port. Neither source met every requirement until it was tested against this list, so test each requirement in the adopting product rather than trusting either source:

- tokens and codes are `secrets.token_urlsafe(32)` with a prefix naming the kind, stored as SHA-256 under a unique index;
- every form parameter must appear at most once, and form bodies have a size cap;
- the lock order of S19 and the fingerprint of S18;
- a grant's end is never stored. It is computed on every check from the approval time, the account type and the maximum period read from the settings at that moment, so a shorter maximum applies at once;
- a check that finds a grant past its end ends it for good, and saving a new maximum first ends every grant past its end under the old one, in the same transaction.
