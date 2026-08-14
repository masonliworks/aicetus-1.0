#!/usr/bin/env node
// server.js — dsh-remote-bridge: token-authenticated HTTP bridge between the
// iOS remote app and a local DeepSeek Harness web instance.
//
//   GET  /healthz            -> unauthenticated liveness probe
//   POST /api/<method>       -> Bearer-token required; forwarded to DSH unary RPC
//   POST /api/respond        -> Bearer-token required; forwarded to DSH interaction answer
//   GET  /api/events         -> Bearer-token required (header or ?token=); SSE stream
//                               carrying "mux" and "host" frames from the DSH WebSockets
//
// Config (env vars, CLI flags win):
//   DSH_URL          base URL of dsh web (default http://127.0.0.1:3080)
//   DSH_REMOTE_HOST  listen host (default 0.0.0.0)
//   DSH_REMOTE_PORT  listen port (default 3878)
//   DSH_REMOTE_TOKEN static token; if unset a token is generated once and
//                    stored at ~/.dsh-remote-bridge/token (printed on startup)
import http from "node:http";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DshClient } from "./dsh-client.js";
import { DashboardCollector } from "./dashboard.js";

const BRIDGE_VERSION = "2.0.0";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------- config ----
function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--dsh-url") out.dshUrl = argv[++i];
    else if (a === "--host") out.host = argv[++i];
    else if (a === "--port") out.port = Number(argv[++i]);
    else if (a === "--token") out.token = argv[++i];
    else if (a === "--help" || a === "-h") out.help = true;
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  console.log(`dsh-remote-bridge — token-authenticated bridge to a local dsh web instance

Usage: node server.js [options]

Options:
  --dsh-url <url>    DeepSeek Harness base URL (default: http://127.0.0.1:3080)
  --host <host>      listen host (default: 0.0.0.0)
  --port <port>      listen port (default: 3878)
  --token <token>    static auth token (default: generated + stored under ~/.dsh-remote-bridge/)

Env: DSH_URL, DSH_REMOTE_HOST, DSH_REMOTE_PORT, DSH_REMOTE_TOKEN`);
  process.exit(0);
}

const DSH_URL = args.dshUrl ?? process.env.DSH_URL ?? "http://127.0.0.1:3080";
const HOST = args.host ?? process.env.DSH_REMOTE_HOST ?? "0.0.0.0";
const PORT = args.port ?? Number(process.env.DSH_REMOTE_PORT ?? 3878);

const stateDir = path.join(os.homedir(), ".dsh-remote-bridge");
let token = args.token ?? process.env.DSH_REMOTE_TOKEN ?? "";
if (!token) {
  try {
    fs.mkdirSync(stateDir, { recursive: true, mode: 0o700 });
    const tokenFile = path.join(stateDir, "token");
    if (fs.existsSync(tokenFile)) {
      token = fs.readFileSync(tokenFile, "utf8").trim();
    } else {
      token = crypto.randomBytes(24).toString("base64url");
      fs.writeFileSync(tokenFile, token, { mode: 0o600 });
    }
  } catch {
    token = crypto.randomBytes(24).toString("base64url");
  }
}

// Method whitelist: control-plane + read-only methods only. Settings and
// credentials stay loopback-only, mirroring the host's own trust posture.
const WHITELIST = new Set([
  "host.describe",
  "host.listDirectory",
  "session.list",
  "session.create",
  "session.prompt",
  "session.cancel",
  "session.rename",
  "session.fork",
  "session.history",
  "session.search",
  "session.models",
  "session.selectModel",
  "session.updateQueue",
  "agentPreset.list",
  "events-poll",
  "subagent.list",
  "subagent.prompt",
  "subagent.interrupt",
  "subagent.history",
  "goal.create",
  "goal.edit",
  "goal.pause",
  "goal.resume",
  "goal.complete",
  "goal.clear",
  "workspace.list",
  "workspace.create",
  "workspace.delete",
  "workspace.rename",
  "workspace.archiveSession",
  "workspace.insertSessionBefore",
  "llm.providers",
  "llm.models",
  "llm.discoverModels",
  "dashboard.summary",
]);

const dsh = new DshClient(DSH_URL);

// 仪表数据收集器（今日 token 增量累计 / 余额缓存 / 汇总）
const dashboard = new DashboardCollector({
  stateDir,
  pricingPath: path.join(__dirname, "pricing.json"),
  dsh,
  bridgeVersion: BRIDGE_VERSION,
});

// Lightweight client telemetry for the Mac companion's overview dashboard.
const telemetry = {
  sseClients: 0,
  lastRequestAt: 0,
  totalRequests: 0,
};

// Frame buffer for POST polling clients (SSE doesn't survive every network).
const frameLog = [];
let frameIdx = 0;
const FRAME_LOG_MAX = 1000;
function rememberFrame(which, frame) {
  frameIdx += 1;
  frameLog.push({ idx: frameIdx, which, frame });
  if (frameLog.length > FRAME_LOG_MAX) {
    frameLog.splice(0, frameLog.length - FRAME_LOG_MAX);
  }
}

// Active SSE connections (broadcast-only; frame recording is stream-level).
const sseClients = new Set();
function broadcast(which, frame) {
  const payload = JSON.stringify(frame);
  for (const res of sseClients) {
    try {
      res.write(`event: ${which}\ndata: ${payload}\n\n`);
    } catch {
      sseClients.delete(res);
    }
  }
}

// ------------------------------------------------------------- auth/help ----
function timingSafeEqualStr(a, b) {
  const ba = Buffer.from(String(a));
  const bb = Buffer.from(String(b));
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

function checkAuth(req) {
  const header = req.headers.authorization ?? "";
  const m = /^Bearer\s+(.+)$/i.exec(header);
  if (m && timingSafeEqualStr(m[1], token)) return true;
  const q = new URL(req.url, "http://x").searchParams.get("token");
  return q !== null && timingSafeEqualStr(q, token);
}

function deny(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function logLine(req, status, extra = "") {
  const ts = new Date().toISOString();
  const ip = req.socket.remoteAddress ?? "-";
  console.log(`[${ts}] ${req.method} ${req.url} ${status} ${extra} (${ip})`);
}

// -------------------------------------------------------------- HTTP app ----
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host ?? "localhost"}`);

  if (url.pathname === "/healthz" && req.method === "GET") {
    const h = await dsh.health();
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({
      ok: true,
      bridge: "dsh-remote-bridge",
      dsh: h,
      telemetry: {
        sseClients: telemetry.sseClients,
        lastRequestAt: telemetry.lastRequestAt,
        totalRequests: telemetry.totalRequests,
      },
    }));
    return;
  }

  if (!checkAuth(req)) {
    logLine(req, 401);
    deny(res, 401, { error: "unauthorized" });
    return;
  }

  telemetry.totalRequests += 1;
  telemetry.lastRequestAt = Date.now();

  // SSE event stream --------------------------------------------------------
  if (url.pathname === "/api/events" && req.method === "GET") {
    res.writeHead(200, {
      "content-type": "text/event-stream",
      "cache-control": "no-cache, no-transform",
      connection: "keep-alive",
      "x-accel-buffering": "no",
    });
    res.write(`: dsh-remote-bridge events\n\n`);
    logLine(req, 200, "(sse)");
    telemetry.sseClients += 1;
    sseClients.add(res);
    const heartbeat = setInterval(() => {
      try {
        res.write(`: ping ${Date.now()}\n\n`);
      } catch {
        /* connection gone */
      }
    }, 5_000);
    req.on("close", () => {
      clearInterval(heartbeat);
      sseClients.delete(res);
      telemetry.sseClients -= 1;
    });
    return;
  }

  // Unary RPC + respond ------------------------------------------------------
  if (req.method !== "POST") {
    logLine(req, 405);
    deny(res, 405, { error: "method not allowed" });
    return;
  }

  let raw = "";
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > 8 * 1024 * 1024) {
      logLine(req, 413);
      deny(res, 413, { error: "payload too large" });
      return;
    }
  }
  let message;
  try {
    message = JSON.parse(raw);
  } catch {
    logLine(req, 400);
    deny(res, 400, { error: "invalid json" });
    return;
  }

  if (url.pathname === "/api/events-poll") {
    const after = Number(message?.payload?.after ?? 0);
    const frames = frameLog.filter((f) => f.idx > after).slice(-200);
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({
      type: "server-response",
      rpcId: message?.rpcId ?? "poll",
      result: { ok: true, value: { frames, latestIdx: frameIdx } },
    }));
    return;
  }

  if (url.pathname === "/api/respond") {
    if (message?.type !== "client-response" || typeof message.rpcId !== "string") {
      logLine(req, 400);
      deny(res, 400, { error: "bad-response" });
      return;
    }
    try {
      const receipt = await dsh.respond(message.rpcId, message.result?.value);
      logLine(req, 200, `(respond ${message.rpcId})`);
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify(receipt));
    } catch (err) {
      logLine(req, 502, `(respond ${message.rpcId})`);
      deny(res, 502, { error: String(err?.message ?? err) });
    }
    return;
  }

  const method = url.pathname.replace(/^\/api\//, "");
  if (message?.type !== "client-request" || typeof message.rpcId !== "string" || typeof message.method !== "string") {
    logLine(req, 400);
    deny(res, 400, { error: "invalid client-request" });
    return;
  }
  if (!WHITELIST.has(method)) {
    logLine(req, 403, `(method ${method})`);
    deny(res, 403, { error: "method not whitelisted", method });
    return;
  }
  // 仪表汇总：桥接自实现（本地聚合 + 余额代理），不透传给 DSH。
  if (method === "dashboard.summary") {
    try {
      const value = await dashboard.summary();
      logLine(req, 200, "(dashboard.summary)");
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({
        type: "server-response",
        rpcId: message.rpcId,
        result: { ok: true, value },
      }));
    } catch (err) {
      logLine(req, 502, "(dashboard.summary)");
      deny(res, 502, { error: String(err?.message ?? err) });
    }
    return;
  }
  try {
    const envelope = await dsh.call(method, message.payload, {
      timeoutMs: method === "session.prompt" ? 300_000 : 120_000,
    });
    logLine(req, 200, `(${method})`);
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify(envelope));
  } catch (err) {
    logLine(req, 502, `(${method})`);
    deny(res, 502, { error: String(err?.message ?? err) });
  }
});

// DSH 事件流在服务级启动：无论客户端用 SSE 还是轮询，帧都会进入缓冲。
{
  const ac = new AbortController();
  const log = (msg) => console.log(`[dsh-stream] ${msg}`);
  dsh.stream("mux", (frame) => {
    rememberFrame("mux", frame);
    broadcast("mux", frame);
  }, { signal: ac.signal, log });
  dsh.stream("host", (frame) => {
    rememberFrame("host", frame);
    broadcast("host", frame);
  }, { signal: ac.signal, log });
}

server.listen(PORT, HOST, async () => {
  const h = await dsh.health();
  console.log(`dsh-remote-bridge listening on http://${HOST}:${PORT}`);
  console.log(`  dsh target : ${DSH_URL}`);
  console.log(`  dsh health : ${h.reachable ? `OK (version ${h.version ?? "?"})` : `UNREACHABLE (${h.error ?? h.http ?? "?"})`}`);
  console.log(`  auth token : ${token}`);
  console.log(`              (configure the iOS app with this token and the Mac's LAN address)`);
});
