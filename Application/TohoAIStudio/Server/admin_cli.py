#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TohoAIStudio 管理者CLIツール（「何でも屋」オーナー用）
- NanndemoyaAPI ライセンスキーの発行・停止・利用明細出力（利用者との直接精算用）
- 定額プランの割当・プロンプト付与・利用制限解除
"""

import argparse
import sqlite3
import secrets
from datetime import datetime, timedelta, timezone
from gateway_server import DB_PATH, get_db, init_db, ensure_and_refresh_user, iso_utc, utc_now
from pricing_plans import FLAT_RATE_PLANS


def cmd_issue_key(args):
    init_db()
    key = args.key or ("NDM-" + secrets.token_hex(3).upper() + "-" + secrets.token_hex(4).upper())
    now_str = iso_utc(utc_now())
    with get_db() as conn:
        conn.execute(
            """
            INSERT OR REPLACE INTO nanndemoya_licenses
            (license_key, owner_user_id, label, preferred_provider, status, note, created_at)
            VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?)
            """,
            (key, args.user, args.label, args.provider, args.note or "", now_str),
        )
    print(f"[OK] NanndemoyaAPI ライセンスキーを発行しました:")
    print(f"  License Key : {key}")
    print(f"  User ID     : {args.user}")
    print(f"  Label       : {args.label}")
    print(f"  Provider    : {args.provider}")


def cmd_usage_report(_args):
    init_db()
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM nanndemoya_licenses ORDER BY created_at DESC").fetchall()
        print("=== NanndemoyaAPI ライセンス別利用明細（精算確認用） ===")
        for r in rows:
            total_tok = r["total_prompt_tokens"] + r["total_completion_tokens"]
            print(
                f"- {r['license_key']} | user={r['owner_user_id']} | status={r['status']} | "
                f"requests={r['total_requests']} | tokens={total_tok} "
                f"(in:{r['total_prompt_tokens']} / out:{r['total_completion_tokens']}) | last={r['last_used_at'] or '-'}"
            )


def cmd_set_plan(args):
    init_db()
    if args.plan not in FLAT_RATE_PLANS:
        raise SystemExit(f"無効なプランIDです: {args.plan} (有効値: {', '.join(FLAT_RATE_PLANS.keys())})")
    plan_cfg = FLAT_RATE_PLANS[args.plan]
    now = utc_now()
    now_str = iso_utc(now)
    next_ren = iso_utc(now + timedelta(days=30))
    with get_db() as conn:
        ensure_and_refresh_user(conn, args.user)
        conn.execute(
            """
            UPDATE users SET
                plan_id = ?,
                plan_enabled = 1,
                base_remaining = ?,
                is_banned = 0,
                ban_reason = NULL,
                cycle_started_at = ?,
                next_renewal_at = ?,
                updated_at = ?
            WHERE user_id = ?
            """,
            (args.plan, plan_cfg["base_monthly_prompts"], now_str, next_ren, now_str, args.user),
        )
    print(f"[OK] ユーザー '{args.user}' を '{plan_cfg['name']}' (基本枠 {plan_cfg['base_monthly_prompts']}回) に設定しました。")


def main():
    parser = argparse.ArgumentParser(description="TohoAIStudio Gateway 管理者CLI")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_issue = sub.add_parser("issue-key", help="NanndemoyaAPI ライセンスキーを発行")
    p_issue.add_argument("--user", required=True, help="利用者ID")
    p_issue.add_argument("--label", default="NanndemoyaAPI 標準ライセンス", help="表示ラベル")
    p_issue.add_argument("--provider", default="auto", choices=["auto", "gemini", "openai", "claude", "deepseek", "grok", "mistral"])
    p_issue.add_argument("--key", default=None, help="任意のキー文字列を指定する場合")
    p_issue.add_argument("--note", default="", help="管理メモ")
    p_issue.set_defaults(func=cmd_issue_key)

    p_rep = sub.add_parser("usage-report", help="NanndemoyaAPI 利用明細を表示")
    p_rep.set_defaults(func=cmd_usage_report)

    p_plan = sub.add_parser("set-plan", help="利用者の定額プランを設定・制限解除")
    p_plan.add_argument("--user", required=True, help="利用者ID")
    p_plan.add_argument("--plan", required=True, help="プランID (free, lite_980, standard_1980, creator_2980, pro_4980, ultra_9800)")
    p_plan.set_defaults(func=cmd_set_plan)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
