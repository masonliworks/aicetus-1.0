#!/usr/bin/env python3
"""DeepSeek Harness 会话消耗统计

从 ~/.dsh/sessions 下的 session.jsonl.zstd 提取每次模型调用的 token 用量,
按 DeepSeek 官方单价计算每次会话 (session) 和每轮 (turn) 的花费。

用法:
  python3 scripts/session-cost-report.py                 # 汇总所有会话
  python3 scripts/session-cost-report.py --session <id>  # 查看某个会话的逐轮明细
  python3 scripts/session-cost-report.py --pricing new   # 用 8/17 生效的新价 (峰谷) 估算
  python3 scripts/session-cost-report.py --rate 6.76     # 自定义 USD->CNY 汇率
"""
import argparse
import glob
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

DEFAULT_HOME = os.path.expanduser("~/.dsh/sessions")

# 每 1M tokens 单价 (USD)。当前价生效至 2026-08-16 16:00 UTC。
PRICING = {
    "current": {"input_miss": 0.14, "input_hit": 0.0028, "output": 0.28},
    "new_offpeak": {"input_miss": 0.22, "input_hit": 0.007, "output": 0.66},
    "new_peak": {"input_miss": 0.44, "input_hit": 0.014, "output": 1.32},
}


def decompress(path):
    out = subprocess.run(
        ["zstd", "-dc", path], capture_output=True, check=False
    ).stdout
    return out


def iter_sessions(root):
    """yield (project_dir, session_id, jsonl_path, mtime)"""
    for j in sorted(glob.glob(os.path.join(root, "*", "*", "session.jsonl.zstd"))):
        parts = j.split(os.sep)
        session_id = parts[-2]
        project = parts[-3]
        yield project, session_id, j, os.path.getmtime(j)


def parse_usage(jsonl_path):
    """返回 [(turn, time, input_tok, hit_tok, output_tok)]"""
    rows = []
    raw = decompress(jsonl_path)
    if not raw:
        return rows
    for line in raw.splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = rec.get("type")
        if t == "assistant/message":
            u = (rec.get("data") or {}).get("usage") or {}
            rows.append(
                (
                    (rec.get("data") or {}).get("turn"),
                    rec.get("time"),
                    u.get("inputTokens", 0),
                    u.get("cacheReadTokens", 0),
                    u.get("outputTokens", 0),  # 已含 reasoningTokens, 勿重复计费
                )
            )
    return rows


def cost_usd(input_tok, hit_tok, output_tok, p):
    return (
        input_tok * p["input_miss"] + hit_tok * p["input_hit"] + output_tok * p["output"]
    ) / 1e6


def fmt_time(ms):
    try:
        return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).strftime("%Y-%m-%d %H:%M")
    except Exception:
        return "?"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default=DEFAULT_HOME)
    ap.add_argument("--session", help="只看某个会话的逐轮明细")
    ap.add_argument("--pricing", default="current", choices=list(PRICING) + ["new"])
    ap.add_argument("--rate", type=float, default=6.7569, help="USD->CNY 汇率")
    args = ap.parse_args()

    if args.pricing == "new":
        price_map = {"off-peak": PRICING["new_offpeak"], "peak": PRICING["new_peak"]}
    else:
        price_map = {args.pricing: PRICING[args.pricing]}
    rate = args.rate

    sessions = list(iter_sessions(args.dir))
    if not sessions:
        print("未找到任何会话日志:", args.dir)
        sys.exit(1)

    if args.session:
        target = [s for s in sessions if s[1] == args.session]
        if not target:
            print("找不到会话:", args.session)
            sys.exit(1)
        proj, sid, jpath, mtime = target[0]
        rows = parse_usage(jpath)
        print(f"会话 {sid}  ({proj})  创建于 {fmt_time(mtime * 1000)}")
        print(f"{'轮':>4} {'时间(UTC)':<17} {'输入(未命中)':>12} {'输入(命中)':>11} {'输出':>10} {'费用 USD':>10}")
        print("-" * 72)
        for turn, tm, inp, hit, out in rows:
            c = cost_usd(inp, hit, out, PRICING[args.pricing])
            print(f"{turn:>4} {fmt_time(tm):<17} {inp:>12,} {hit:>11,} {out:>10,} {c:>10.4f}")
        ti = sum(r[2] for r in rows)
        th = sum(r[3] for r in rows)
        to = sum(r[4] for r in rows)
        tc = cost_usd(ti, th, to, PRICING[args.pricing])
        print("-" * 72)
        print(f"合计: {ti:,} 输入(未命中) + {th:,} 缓存命中 + {to:,} 输出 = {tc:.4f} USD = {tc * rate:.2f} CNY")
        return

    print(f"{'会话 ID':<38} {'项目':<26} {'轮数':>4} {'输入(未命中)':>12} {'输入(命中)':>11} {'输出':>10} {'费用 USD':>10} {'费用 CNY':>9}")
    print("-" * 128)
    g_inp = g_hit = g_out = 0
    for proj, sid, jpath, mtime in sessions:
        rows = parse_usage(jpath)
        if not rows:
            continue
        turns = len({r[0] for r in rows})
        ti = sum(r[2] for r in rows)
        th = sum(r[3] for r in rows)
        to = sum(r[4] for r in rows)
        tc = cost_usd(ti, th, to, PRICING[args.pricing])
        g_inp += ti
        g_hit += th
        g_out += to
        print(f"{sid:<38} {proj:<26} {turns:>4} {ti:>12,} {th:>11,} {to:>10,} {tc:>10.4f} {tc * rate:>9.2f}")
    gc = cost_usd(g_inp, g_hit, g_out, PRICING[args.pricing])
    print("-" * 128)
    print(f"{'合计':<38} {'':<26} {'':>4} {g_inp:>12,} {g_hit:>11,} {g_out:>10,} {gc:>10.4f} {gc * rate:>9.2f}")

    if args.pricing != "new":
        p = PRICING[args.pricing]
        print(f"\n单价 (每 1M tokens, {args.pricing}): 输入未命中 ${p['input_miss']}, "
              f"缓存命中 ${p['input_hit']}, 输出 ${p['output']}; 汇率 1 USD = {rate} CNY")


if __name__ == "__main__":
    main()
