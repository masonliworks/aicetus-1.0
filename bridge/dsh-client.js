// dsh-client.js — minimal client for the DeepSeek Harness /api wire protocol.
//
// Protocol facts (verified against @deepseek-ai/dsh-client-connection 0.1.0-rc.6):
//   * unary calls:   POST /api/<method>  body {"type":"client-request","rpcId":<uuid>,"method":...,"payload":...}
//                    -> {"type":"server-response","rpcId":<same>,"result":{"ok":true,"value":...}|{"ok":false,"error":...}}
//   * interactions:  POST /api/respond  body {"type":"client-response","rpcId":<frame rpcId>,"result":{"ok":true,"value":...}}
//                    -> {"accepted":true} | {"accepted":false,"reason":"not-pending"|"bad-response"}
//   * event streams: two downlink-only WebSockets (/api/events.mux and /api/events.host)
//                    carrying ServerRequest frames; the frame rpcId is what a client
//                    must echo when answering approval/question frames.
import crypto from "node:crypto";

export class DshClient {
  /** @param {string} baseUrl - e.g. http://127.0.0.1:3080 */
  constructor(baseUrl) {
    this.baseUrl = baseUrl.replace(/\/+$/, "");
  }

  /** Unary call. Resolves to the full server-response envelope. */
  async call(method, payload, { timeoutMs = 120_000 } = {}) {
    const body = JSON.stringify({
      type: "client-request",
      rpcId: crypto.randomUUID(),
      method,
      payload: payload ?? {},
    });
    const res = await fetch(`${this.baseUrl}/api/${method}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body,
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!res.ok) {
      throw new Error(`dsh ${method}: HTTP ${res.status} ${res.statusText}`);
    }
    return res.json();
  }

  /** Answer an approval/question frame. `value` is the domain payload slot. */
  async respond(rpcId, value) {
    const res = await fetch(`${this.baseUrl}/api/respond`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        type: "client-response",
        rpcId,
        result: { ok: true, value },
      }),
    });
    if (!res.ok) {
      throw new Error(`dsh respond: HTTP ${res.status} ${res.statusText}`);
    }
    return res.json(); // {accepted:boolean, reason?}
  }

  async health() {
    try {
      const res = await fetch(`${this.baseUrl}/api/host.describe`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          type: "client-request",
          rpcId: crypto.randomUUID(),
          method: "host.describe",
          payload: {},
        }),
        signal: AbortSignal.timeout(5000),
      });
      if (!res.ok) return { reachable: false, http: res.status };
      const env = await res.json();
      return {
        reachable: true,
        version: env.result?.value?.version,
        cwd: env.result?.value?.cwd,
        model: env.result?.value?.model,
      };
    } catch (err) {
      return { reachable: false, error: String(err?.message ?? err) };
    }
  }

  /**
   * Open one of the DSH event streams and push decoded frames into `onFrame`.
   * Reconnects with exponential backoff until `stop` fires (or the promise is
   * not awaited). Resolves once the first connection is established.
   * @param {"mux"|"host"} which
   * @param {(frame: object) => void} onFrame
   * @param {{signal?: AbortSignal, log?: (msg: string) => void}} opts
   */
  async stream(which, onFrame, { signal, log = () => {} } = {}) {
    const wsUrl = this.baseUrl.replace(/^http/, "ws") + `/api/events.${which}`;
    let attempt = 0;
    const openPromise = new Promise((resolve) => {
      const tryConnect = () => {
        if (signal?.aborted) return resolve();
        attempt += 1;
        const ws = new WebSocket(wsUrl);
        let opened = false;
        const timer = setTimeout(() => {
          if (!opened) {
            log(`dsh events.${which}: open timeout, retrying`);
            try {
              ws.close();
            } catch {}
          }
        }, 10_000);
        ws.onopen = () => {
          opened = true;
          clearTimeout(timer);
          attempt = 0;
          log(`dsh events.${which}: connected`);
          resolve();
        };
        ws.onmessage = (ev) => {
          try {
            onFrame(JSON.parse(String(ev.data)));
          } catch (err) {
            log(`dsh events.${which}: bad frame: ${err.message}`);
          }
        };
        ws.onerror = () => {
          clearTimeout(timer);
          try {
            ws.close();
          } catch {}
        };
        ws.onclose = () => {
          clearTimeout(timer);
          if (signal?.aborted) return;
          const delay = Math.min(30_000, 500 * 2 ** Math.min(attempt - 1, 6));
          log(`dsh events.${which}: closed, retrying in ${delay}ms`);
          setTimeout(tryConnect, delay);
        };
      };
      tryConnect();
    });
    await openPromise;
  }
}
