# Temporary access (optional module)

Build this only when Shlomi decided the product needs it. It lets a connected agent ask a person for short-lived, elevated access to something the connection itself cannot reach, and lets the person approve it as asked, change it first, or deny it. n8n-ops uses it to give agents temporary access to the API of an n8n instance it manages. The module below is that design, with the product names taken out.

## The shape

1. The agent asks: what it needs (one or more targets, each with scopes and optional narrower items), a reason, and how many minutes.
2. People who may approve hear about it (in the product, and on channels the product offers).
3. A person approves as asked, approves after changing it, or denies.
4. The agent polls the request. Once approved, it collects a key, once.
5. The agent calls the target through a proxy in the product, with that key. The proxy checks every call against what was granted, forwards it with the target's own credential, and records it.
6. The access ends when the time is up, when the agent releases it, or when a person revokes it.

The agent never receives the target's own credential.

## Who may ask

- Only a connection the person allowed to ask, on the consent page (n8n-ops: a separate scope the person may untick). A connection without it gets 403 `not_allowed` with `WWW-Authenticate: Bearer error="insufficient_scope"`, so the agent knows to ask the person to connect again with it.
- At most a few requests waiting per connection (n8n-ops: three), so a looping agent cannot flood the approvers. One request being made at a time per connection (`request_in_progress`).

## The request

- Targets by name, each with scopes and optional item ids (at most a bounded number). A single-target form may stay for older clients.
- A reason, 10 to 500 characters, shown to the approver.
- Minutes, at least 1. The approver sees it.
- Optional notify channels, only when the person asked the agent for one. A channel that is off or not set up is replaced by the default ones. The answer says where the request will go.
- Validate everything against the settings: which targets are open to agents, which scopes each allows (never beyond what the target's own credential holds), the longest duration.

## Approving

- The request has a `revision`. Every edit of the draft (from the request page or a chat button) moves it to the next revision, and an edit sets a value, never flips it, so a press sent twice does not undo itself.
- Approval names the revision the approver saw. If the request changed since, nothing is approved, and the approver sees it again (`request_changed`).
- Approval runs in one transaction that locks the request and every target involved, so a policy saved at the same time is applied or waits. A target closed or deleted by then is left out, and so are scopes no longer allowed. With nothing left, nothing is approved.
- Denial asks the approver to confirm first, since it is final.
- A request nobody decided expires after a set time.
- The audit log and the request page say who decided and where.

## The key

- Made with a CSPRNG at approval, with a short visible prefix.
- Stored as a hash for lookup, plus an encrypted copy (with the product's key for stored secrets) until the agent collects it.
- Collected once: the first look after approval returns the key and clears the encrypted copy in the same conditional update. Later looks return only the prefix and "already collected".
- Accepted only by the proxy, only for the granted targets, only until the access ends.

## The proxy

- Takes the key in the same header the target's API uses, so the target's own clients work by changing their base URL.
- Checks every call against the grant: the target, the scopes (n8n-ops reads which scope each operation needs from the target's own API description), and the granted items. An operation on an item the grant does not name is refused. When the item must be checked on the target first (n8n-ops: an execution's workflow), check it.
- Refuses when temporary access to the target was turned off meanwhile.
- Forwards with the target's credential, with a deadline, and records every call (refused ones with the reason).

## Ending

- **Expired:** a background job ends approved access whose time is up, and pending requests nobody decided.
- **Released:** the agent releases it with an optional summary (n8n-ops: up to 1000 characters, clipped, never refused, so a long summary cannot keep a key alive). The same update that ends the access keeps the summary.
- **Revoked:** a person revokes it. Disconnecting the agent's connection revokes all its access.
- On every end, the key stops working at once and the encrypted copy is cleared. The request page and the message show how long the access was used, the summary, and how many calls were made and refused.

## What the client skill tells the agent

- Ask only when the task needs it, for the fewest targets, scopes, items and minutes. Count the time to check the result and to fix a failure.
- Poll while pending. Work only within what was granted, which may differ from what was asked (`changed: true`).
- Keep the access until the task is finished and checked. Check the result the task is about, not only that a change was saved. Holding the key does not widen the approved reason.
- Release it once the task no longer needs it, also when it was cancelled or given up, with a summary of what was done and the result.
- A secret only the person knows is never asked for in the conversation. Use a private way to enter it if the agent's tool has one, or ask the person to enter it in the target. Keep any secret out of the conversation, commands, output, logs, repository files and the summary.

## Tests

- Approve with a stale revision: nothing approved.
- Approve while the target's policy is saved: the policy applies or waits.
- Collect the key twice at once: one gets it.
- Release, revoke, expire: the key stops working at once.
- The proxy refuses a scope, an item and a target not granted, and records it.
- Disconnecting the connection revokes its access.
