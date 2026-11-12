// A stand-in for MyApp's authorization server and REST API, strict like the real one: a refresh token or device code
// used twice ends the whole grant. Tests drive it through its state and a few switches.
//
// Every token, code and id is made at run time with randomBytes: no fixed secret value lives in this file.
import { createHash, randomBytes } from "node:crypto"
import http from "node:http"

/* ---- Product constants: the same values as in the scripts' constant block. ---- */
const CLIENT_ID = "myapp-cli"
const API_PREFIX = "/api/"
const ACCESS_PATH = "/api/agent/access"
const ENDPOINTS_PATH = "/api/agent/endpoints"
const SKILL_HEADER = "x-myapp-skill"
const POLICY_HEADER = "x-myapp-policy"
/* ---- End of product constants. ---- */

/** A sample policy table: every route an agent may call, with its area and kind (read or act, by effect). */
export const SAMPLE_POLICY = [
  { method: "GET", path: "/api/items", kind: "read", area: "items", description: "List items." },
  { method: "GET", path: "/api/items/{id}", kind: "read", area: "items", description: "Read one item." },
  { method: "POST", path: "/api/items", kind: "act", area: "items", description: "Create an item." },
  { method: "PUT", path: "/api/items/{id}", kind: "act", area: "items", description: "Replace an item." },
  { method: "PATCH", path: "/api/items/{id}", kind: "act", area: "items", description: "Change an item." },
  { method: "DELETE", path: "/api/items/{id}", kind: "act", area: "items", description: "Delete an item." },
  { method: "POST", path: "/api/items/{id}/archive", kind: "act", area: "items", description: "Archive an item." },
  // A search that changes nothing, sent as POST: its kind is read, whatever its method.
  { method: "POST", path: "/api/items/search", kind: "read", area: "items", description: "Search items." },
  { method: "GET", path: "/api/files/{name:path}", kind: "read", area: "files", description: "Read a file." },
]

const id = () => randomBytes(18).toString("base64url")

function templateMatches(template, p) {
  const t = template.split("/")
  const s = p.split("/")
  for (let i = 0; i < t.length; i++) {
    if (/^\{[^}]*:path\}$/.test(t[i])) return i === t.length - 1 && s.length > i && s.slice(i).join("") !== ""
    if (i >= s.length) return false
    if (/^\{[^}]*\}$/.test(t[i])) {
      if (s[i] === "") return false
    } else if (t[i] !== s[i]) return false
  }
  return t.length === s.length
}

/** On this computer, at 127.0.0.1 unless `host` names another address (such as ::1). */
export async function startFakeServer(port = 0, host = "127.0.0.1") {
  const s = {
    issuer: "",
    devices: new Map(), // device_code -> { userCode, label, state: pending|approved|denied|used, scope }
    refresh: new Map(), // token -> { grant, consumed }
    access: new Map(), // token -> { grant, exp }
    grants: new Map(), // id -> { alive, scope }
    counts: {},
    arrivalCounts: new Map(), // "METHOD /path" -> requests that reached the API, refused or not
    runCounts: new Map(), // "METHOD template" -> times the route's code ran
    last: {},
  }

  /** Switches back to their defaults, counters to zero, and the sample policy table. */
  s.reset = () => {
    Object.assign(s, {
      counts: { device: 0, deviceToken: 0, refresh: 0, revoke: 0, reuse: 0, listing: 0 },
      accessTtl: 900,
      refreshAccessTtl: null,
      deviceInterval: undefined,
      dropNextRefresh: false,
      truncateNextRefresh: false,
      refreshDelayMs: 0,
      revokeStatus: 200,
      slowDownOnce: false,
      // The endpoints listing: an error status to answer with, or a body to answer 200 with instead of the list.
      listingStatus: 0,
      listingBody: null,
      // Applied once to the policy table right after the next listing is served: { method, path, kind }.
      reclassifyAfterListing: null,
      // Refusals before any route code runs, one per call to a route of the table (not access or the listing), in
      // order: "invalid_token" (401 with the challenge), "busy" (429), "policy_changed" (409, even with the
      // right revision).
      beforeRun: [],
      // What happens after the route's code ran, one per run, in order: "drop" (no answer), "truncate" (the answer
      // starts and breaks off), or { status, body, headers } to answer with.
      afterRun: [],
      policy: SAMPLE_POLICY.map((e) => ({ ...e })),
      last: {},
    })
    s.arrivalCounts.clear()
    s.runCounts.clear()
  }
  s.reset()

  /** The server's hash of its policy table, as the listing gives it and the policy header must carry it. */
  s.revision = () =>
    createHash("sha256")
      .update(JSON.stringify(s.policy.map((e) => [e.method, e.path, e.area, e.kind])))
      .digest("hex")
      .slice(0, 32)
  s.arrivals = (method, p) => s.arrivalCounts.get(`${method} ${p}`) ?? 0
  s.runs = (method, template) => s.runCounts.get(`${method} ${template}`) ?? 0
  s.setKind = (method, template, kind) => {
    const e = s.policy.find((x) => x.method === method && x.path === template)
    e.kind = kind
  }

  const issue = (grant, ttl) => {
    const refresh = id()
    const access = id()
    s.refresh.set(refresh, { grant, consumed: false })
    s.access.set(access, { grant, exp: Date.now() + ttl * 1000 })
    return {
      access_token: access,
      refresh_token: refresh,
      token_type: "Bearer",
      expires_in: ttl,
      scope: s.grants.get(grant).scope,
    }
  }
  const endGrant = (grant) => {
    const g = s.grants.get(grant)
    if (g) g.alive = false
  }

  const server = http.createServer(async (req, res) => {
    const chunks = []
    for await (const c of req) chunks.push(c)
    const raw = Buffer.concat(chunks).toString("utf8")
    const url = new URL(req.url, s.issuer)
    const form = Object.fromEntries(new URLSearchParams(raw))
    const send = (status, body, headers = {}) => {
      res.writeHead(status, { "content-type": "application/json", ...headers })
      res.end(typeof body === "string" ? body : JSON.stringify(body))
    }

    if (req.method === "GET" && url.pathname === "/.well-known/oauth-authorization-server")
      return send(200, { issuer: s.issuer, token_endpoint: `${s.issuer}/oauth/token` })

    if (req.method === "POST" && url.pathname === "/oauth/device") {
      s.counts.device++
      if (form.client_id !== CLIENT_ID) return send(400, { error: "invalid_client" })
      s.last.label = form.client_label ?? null
      s.last.deviceScope = form.scope ?? null
      s.last.resource = form.resource ?? null
      const deviceCode = id()
      const userCode = `${randomBytes(2).toString("hex").toUpperCase()}-${randomBytes(2).toString("hex").toUpperCase()}`
      s.devices.set(deviceCode, { userCode, label: form.client_label, state: "pending", scope: form.scope })
      return send(200, {
        device_code: deviceCode,
        user_code: userCode,
        verification_uri: `${s.issuer}/connect/device`,
        verification_uri_complete: `${s.issuer}/connect/device?user_code=${userCode}`,
        expires_in: 600,
        ...(s.deviceInterval ? { interval: s.deviceInterval } : {}),
      })
    }

    if (req.method === "POST" && url.pathname === "/oauth/token") {
      if (form.client_id !== CLIENT_ID) return send(400, { error: "invalid_client" })
      if (form.grant_type === "urn:ietf:params:oauth:grant-type:device_code") {
        s.counts.deviceToken++
        const d = s.devices.get(form.device_code)
        if (!d) return send(400, { error: "invalid_grant" })
        if (s.slowDownOnce) {
          s.slowDownOnce = false
          return send(400, { error: "slow_down" })
        }
        if (d.state === "pending") return send(400, { error: "authorization_pending" })
        if (d.state === "denied") return send(400, { error: "access_denied" })
        if (d.state === "used") {
          s.counts.reuse++
          if (d.grant) endGrant(d.grant)
          return send(400, { error: "invalid_grant" })
        }
        d.state = "used"
        const grant = id()
        d.grant = grant
        s.grants.set(grant, { alive: true, scope: d.grantScope ?? d.scope })
        return send(200, issue(grant, s.accessTtl))
      }
      if (form.grant_type === "refresh_token") {
        s.counts.refresh++
        const t = s.refresh.get(form.refresh_token)
        if (!t) return send(400, { error: "invalid_grant" })
        if (t.consumed) {
          s.counts.reuse++
          endGrant(t.grant)
          return send(400, { error: "invalid_grant" })
        }
        if (!s.grants.get(t.grant)?.alive) return send(400, { error: "invalid_grant" })
        t.consumed = true
        if (s.refreshDelayMs) await new Promise((r) => setTimeout(r, s.refreshDelayMs))
        const tokens = issue(t.grant, s.refreshAccessTtl ?? s.accessTtl)
        if (s.dropNextRefresh) {
          s.dropNextRefresh = false
          s.orphan = tokens.refresh_token
          req.socket.destroy()
          return
        }
        if (s.truncateNextRefresh) {
          // The answer starts, then the connection breaks.
          s.truncateNextRefresh = false
          s.orphan = tokens.refresh_token
          res.writeHead(200, { "content-type": "application/json", "content-length": "400" })
          res.write('{"access_token":"')
          setTimeout(() => req.socket.destroy(), 50)
          return
        }
        return send(200, tokens)
      }
      return send(400, { error: "unsupported_grant_type" })
    }

    if (req.method === "POST" && url.pathname === "/oauth/revoke") {
      s.counts.revoke++
      if (s.revokeStatus !== 200) return send(s.revokeStatus, { error: "server_error" })
      const t = s.refresh.get(form.token)
      if (t) endGrant(t.grant)
      return send(200, {})
    }

    if (url.pathname.startsWith(API_PREFIX)) {
      const key = `${req.method} ${url.pathname}`
      s.arrivalCounts.set(key, (s.arrivalCounts.get(key) ?? 0) + 1)
      s.last.skill = req.headers[SKILL_HEADER]
      s.last.policy = req.headers[POLICY_HEADER]
      // 1. The token check, before anything else.
      const bearer = (req.headers.authorization ?? "").replace(/^Bearer /, "")
      const a = s.access.get(bearer)
      if (!a || a.exp < Date.now() || !s.grants.get(a.grant)?.alive)
        return send(401, { error: "invalid_token" }, { "www-authenticate": 'Bearer error="invalid_token"' })
      const scope = s.grants.get(a.grant).scope

      // 2. The calls that are exempt from the policy header: access and the listing.
      if (req.method === "GET" && url.pathname === ACCESS_PATH)
        return send(200, { label: "Agents", scope, areas: [...new Set(s.policy.map((e) => e.area))] })
      if (req.method === "GET" && url.pathname === ENDPOINTS_PATH) {
        s.counts.listing++
        if (s.listingStatus) return send(s.listingStatus, { error: "server_error" })
        if (s.listingBody !== null) return send(200, s.listingBody)
        const area = url.searchParams.get("area")
        const endpoints = s.policy.filter((e) => area === null || e.area === area)
        const revision = s.revision()
        if (s.reclassifyAfterListing) {
          const { method, path, kind } = s.reclassifyAfterListing
          s.reclassifyAfterListing = null
          s.setKind(method, path, kind)
        }
        return send(200, { endpoints, count: endpoints.length, revision })
      }

      // 3. The limits layer and the policy check: refusals before any route code runs.
      const before = s.beforeRun.shift()
      if (before === "invalid_token")
        return send(401, { error: "invalid_token" }, { "www-authenticate": 'Bearer error="invalid_token"' })
      if (before === "busy")
        return send(429, { error: "busy", message: "MyApp is busy with this connection's other calls. Try again." })
      if (before === "policy_changed" || req.headers[POLICY_HEADER] !== s.revision())
        return send(409, { error: "policy_changed", message: "The list of calls changed. Read it again." })
      const rule = s.policy.find((e) => e.method === req.method && templateMatches(e.path, url.pathname))
      if (!rule) return send(404, { error: "not_found", message: "No such call." })

      // 4. The route's code runs.
      const ran = `${rule.method} ${rule.path}`
      s.runCounts.set(ran, (s.runCounts.get(ran) ?? 0) + 1)
      s.last.body = raw
      const after = s.afterRun.shift()
      if (after === "drop") {
        req.socket.destroy()
        return
      }
      if (after === "truncate") {
        res.writeHead(200, { "content-type": "application/json", "content-length": "400" })
        res.write('{"data":{"')
        setTimeout(() => req.socket.destroy(), 50)
        return
      }
      if (after) return send(after.status, after.body ?? "", after.headers ?? {})
      let body = null
      try {
        body = raw ? JSON.parse(raw) : null
      } catch {
        body = raw
      }
      return send(200, { method: req.method, path: url.pathname, query: url.search, kind: rule.kind, body })
    }
    send(404, { error: "not_found" })
  })

  await new Promise((r, reject) => {
    server.once("error", reject)
    server.listen(port, host, () => {
      server.off("error", reject)
      r()
    })
  })
  s.port = server.address().port
  s.issuer = `http://${host.includes(":") ? `[${host}]` : host}:${s.port}`
  s.close = () =>
    new Promise((r) => {
      server.closeAllConnections?.()
      server.close(r)
    })
  /** Goes away and comes back on the same address, with the same state. */
  s.stop = s.close
  s.start = () => new Promise((r) => server.listen(s.port, host, r))
  /** The person approves the latest code, optionally with a narrower scope. */
  s.approve = ({ scope } = {}) => {
    const d = [...s.devices.values()].at(-1)
    d.state = "approved"
    if (scope) d.grantScope = scope
  }
  s.deny = () => {
    ;[...s.devices.values()].at(-1).state = "denied"
  }
  s.aliveGrants = () => [...s.grants.values()].filter((g) => g.alive).length
  s.expireAccessTokens = () => {
    for (const a of s.access.values()) a.exp = 0
  }
  s.endAllGrants = () => {
    for (const g of s.grants.values()) g.alive = false
  }
  /** Every secret it ever handed out, to check that none shows up in the command's output. */
  s.secrets = () => [...s.refresh.keys(), ...s.access.keys(), ...s.devices.keys()]
  return s
}
