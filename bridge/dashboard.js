// dashboard.js — 仪表数据收集器（运行于桥接进程，即 Mac 本机）。
//
// 数据来源：
//   1. 今日 token：事件流 session/projection（tokenUsage）增量累计。
//      每会话维护"上次观测值"，收到投影帧时把增量计入今日总量；
//      跨天只清零统计、保留基线（当日首帧增量即当日已用量）。
//      桥接停机期间的用量无法回填（首观测建基线，不重复计入）。
//   2. 活跃会话数：session.list 的 running。
//   3. API 余额：DeepSeek GET /user/balance（key 读 ~/.dsh/.credentials.yaml，
//      仅本机调用，永不出 Mac），60s 缓存。
//   4. 今日金额：今日 token × pricing.json 单价（按主机当前模型计价，
//      单模型主机的近似；多模型主机后续按会话归属细化）。
//   5. 连接状态：dsh.health()。
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import https from "node:https";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const BALANCE_URL = "https://api.deepseek.com/user/balance";

function todayKey(now = new Date()) {
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function loadJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return fallback;
  }
}

function saveJson(file, obj) {
  try {
    fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
    fs.writeFileSync(file, JSON.stringify(obj));
  } catch {
    /* best effort */
  }
}

function fetchJson(url, headers, timeoutMs = 8000) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { headers, timeout: timeoutMs }, (res) => {
      let body = "";
      res.on("data", (c) => {
        body += c;
      });
      res.on("end", () => {
        try {
          resolve(JSON.parse(body));
        } catch {
          reject(new Error(`bad json from ${url}: ${String(body).slice(0, 80)}`));
        }
      });
    });
    req.on("timeout", () => req.destroy(new Error("balance request timeout")));
    req.on("error", reject);
  });
}

export class DashboardCollector {
  constructor({ stateDir, pricingPath, dsh, bridgeVersion = "0.0.0" }) {
    this.dsh = dsh;
    this.bridgeVersion = bridgeVersion;
    this.stateDir = stateDir;
    this.statsFile = path.join(stateDir, "daily-stats.json");
    this.baselineFile = path.join(stateDir, "usage-baseline.json");
    this.pricing = loadJson(pricingPath, { currency: "CNY", defaultModel: "", models: {} });

    const stats = loadJson(this.statsFile, null);
    this.dateKey = stats?.date ?? todayKey();
    if (stats?.date !== this.dateKey) {
      this.today = { input: 0, output: 0, cacheRead: 0 };
    } else {
      this.today = {
        input: stats?.input ?? 0,
        output: stats?.output ?? 0,
        cacheRead: stats?.cacheRead ?? 0,
      };
    }
    // 跨天保留基线：零点后的首帧增量就是当日已用量。
    this.baseline = loadJson(this.baselineFile, {});

    this.balanceCache = null;
    this.hostModelCache = null;
    this.saveTimer = null;
  }

  scheduleSave() {
    if (this.saveTimer) return;
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      saveJson(this.statsFile, { date: this.dateKey, ...this.today });
      saveJson(this.baselineFile, this.baseline);
    }, 5_000);
    this.saveTimer.unref?.();
  }

  rollover(now) {
    const key = todayKey(now);
    if (key === this.dateKey) return;
    this.dateKey = key;
    this.today = { input: 0, output: 0, cacheRead: 0 };
    saveJson(this.statsFile, { date: key, ...this.today });
  }

  /** 事件流 session/projection(tokenUsage) 帧 → 增量累计。 */
  noteProjection(sessionId, usage) {
    if (!sessionId) return;
    const cur = {
      input: Number(usage?.uncachedInputTokens ?? 0),
      output: Number(usage?.outputTokens ?? 0),
      cacheRead: Number(usage?.cacheReadTokens ?? 0),
    };
    const last = this.baseline[sessionId];
    if (!last) {
      this.baseline[sessionId] = cur;
      this.scheduleSave();
      return;
    }
    const dInput = Math.max(0, cur.input - last.input);
    const dOutput = Math.max(0, cur.output - last.output);
    const dCache = Math.max(0, cur.cacheRead - last.cacheRead);
    this.baseline[sessionId] = cur;
    if (dInput + dOutput + dCache === 0) return;
    this.today.input += dInput;
    this.today.output += dOutput;
    this.today.cacheRead += dCache;
    this.scheduleSave();
  }

  async hostModel() {
    const now = Date.now();
    if (this.hostModelCache && now - this.hostModelCache.at < 300_000) {
      return this.hostModelCache.value;
    }
    try {
      const h = await this.dsh.health();
      const model = h?.model ?? "";
      this.hostModelCache = { at: now, value: model };
      return model;
    } catch {
      return this.hostModelCache?.value ?? "";
    }
  }

  async balance() {
    const now = Date.now();
    if (this.balanceCache && now - this.balanceCache.at < this.balanceCache.ttl) {
      return this.balanceCache.value;
    }
    const key = readApiKey();
    if (!key) {
      const v = { error: "未找到 API key（~/.dsh/.credentials.yaml）", fetchedAt: new Date().toISOString() };
      this.balanceCache = { at: now, ttl: 60_000, value: v };
      return v;
    }
    try {
      const j = await fetchJson(BALANCE_URL, {
        Authorization: `Bearer ${key}`,
        Accept: "application/json",
      });
      const info = j?.balance_infos?.[0] ?? {};
      const v = {
        available: !!j?.is_available,
        currency: info.currency ?? "CNY",
        total: Number(info.total_balance ?? 0),
        granted: Number(info.granted_balance ?? 0),
        toppedUp: Number(info.topped_up_balance ?? 0),
        fetchedAt: new Date().toISOString(),
      };
      this.balanceCache = { at: now, ttl: 60_000, value: v };
      return v;
    } catch (err) {
      const v = { error: String(err?.message ?? err), fetchedAt: new Date().toISOString() };
      this.balanceCache = { at: now, ttl: 15_000, value: v };
      return v;
    }
  }

  async summary() {
    const now = new Date();
    this.rollover(now);

    let dshReachable = false;
    try {
      const h = await this.dsh.health();
      dshReachable = !!h?.reachable;
    } catch {
      /* keep false */
    }

    let activeSessions = 0;
    try {
      const env = await this.dsh.call("session.list", {});
      const items = env?.result?.value?.items ?? env?.value?.items ?? [];
      activeSessions = items.filter((i) => i?.running).length;
    } catch {
      /* keep 0 */
    }

    const model = await this.hostModel();
    const price =
      this.pricing.models?.[model] ??
      this.pricing.models?.[this.pricing.defaultModel] ??
      { input: 2, output: 8, cacheRead: 0.5 };
    const cost =
      (this.today.input * (price.input ?? 0) +
        this.today.output * (price.output ?? 0) +
        this.today.cacheRead * (price.cacheRead ?? 0)) /
      1_000_000;

    return {
      connection: {
        dshReachable,
        bridgeVersion: this.bridgeVersion,
      },
      activeSessions,
      today: {
        date: this.dateKey,
        inputTokens: this.today.input,
        outputTokens: this.today.output,
        cacheReadTokens: this.today.cacheRead,
        cost: Math.round(cost * 10000) / 10000,
        currency: this.pricing.currency ?? "CNY",
        model,
        unit: this.pricing.unit ?? "1M tokens",
      },
      balance: await this.balance(),
      capturedAt: now.toISOString(),
    };
  }
}

function readApiKey() {
  const file = path.join(os.homedir(), ".dsh", ".credentials.yaml");
  try {
    const s = fs.readFileSync(file, "utf8");
    const m = /^\s*DEEPSEEK_API_KEY\s*:\s*(\S+)\s*$/m.exec(s);
    return m?.[1] ?? "";
  } catch {
    return "";
  }
}
