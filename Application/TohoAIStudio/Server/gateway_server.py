#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TohoAIStudio V3.0 Public Distribution Gateway Server
- 新・定額プラン料金体系 (5時間バースト枠 / 週次枠 / 月次枠 / 有効期限付き繰越 / お試し広告ボーナス)
- NanndemoyaAPI ライセンスキー認証＆利用明細ロギング (決済処理不要・管理者発行キー方式)
- ハイブリッドLLM推論ルーター (Gemini / DeepSeek / OpenAI / Claude / Grok / Mistral / Colab GPU / Local Ollama)
- SQLite WAL モードによるスレッドセーフ永続化 & ボット・不正利用自動検知
"""

import os
import re
import json
import time
import uuid
import sqlite3
import secrets
import threading
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List, Tuple

import requests
from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn

from pricing_plans import (
    FLAT_RATE_PLANS,
    LEGACY_PLAN_MAPPING,
    ADDON_PROMPT_PACKS,
    AD_REWARD_PROMPTS_PER_VIEW,
    build_rag_system_prompt,
    build_ai_edit_prompts,
)

# ==============================================================================
# 環境設定
# ==============================================================================
BASE_DIR = os.environ.get("TOHO_GATEWAY_DIR", os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(DATA_DIR, exist_ok=True)
DB_PATH = os.path.join(DATA_DIR, "gateway.db")

PORT = int(os.environ.get("TOHO_GATEWAY_PORT", "8095"))
OLLAMA_BASE_URL = os.environ.get("OLLAMA_BASE_URL", "http://127.0.0.1:11434")
DEFAULT_LOCAL_MODEL = os.environ.get("DEFAULT_LOCAL_MODEL", "qwen2.5:3b")
ADMIN_TOKEN = os.environ.get("TOHO_ADMIN_TOKEN", "toho-nanndemoya-admin-2026")

# サーバー側マスターAPIキー（「何でも屋」側で契約・管理するプロバイダーキー）
MASTER_KEYS = {
    "gemini": os.environ.get("GEMINI_API_KEY", ""),
    "openai": os.environ.get("OPENAI_API_KEY", ""),
    "claude": os.environ.get("ANTHROPIC_API_KEY", ""),
    "deepseek": os.environ.get("DEEPSEEK_API_KEY", ""),
    "grok": os.environ.get("XAI_API_KEY", ""),
    "mistral": os.environ.get("MISTRAL_API_KEY", ""),
    "openrouter": os.environ.get("OPENROUTER_API_KEY", ""),
}

app = FastAPI(
    title="TohoAIStudio Public LLM & Quota Gateway",
    version="3.0.0",
    description="一般配布・外部公開対応 TohoAIStudio 定額プラン管理 & NanndemoyaAPI 中継サーバ",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==============================================================================
# SQLite (WAL) データベース初期化・ヘルパー
# ==============================================================================
def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s: Optional[str]) -> Optional[datetime]:
    if not s:
        return None
    try:
        if s.endswith("Z"):
            return datetime.fromisoformat(s[:-1]).replace(tzinfo=timezone.utc)
        dt = datetime.fromisoformat(s)
        return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
    except Exception:
        return None


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, timeout=15.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn


def init_db():
    with get_db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                user_id TEXT PRIMARY KEY,
                account_type TEXT NOT NULL DEFAULT 'NanndemoyaCloud',
                plan_id TEXT NOT NULL DEFAULT 'free',
                plan_enabled INTEGER NOT NULL DEFAULT 1,
                base_remaining INTEGER NOT NULL DEFAULT 30,
                rollover_remaining INTEGER NOT NULL DEFAULT 0,
                rollover_expires_at TEXT,
                addon_remaining INTEGER NOT NULL DEFAULT 0,
                addon_expires_at TEXT,
                ad_bonus_remaining INTEGER NOT NULL DEFAULT 0,
                ad_bonus_earned_month INTEGER NOT NULL DEFAULT 0,
                cycle_started_at TEXT NOT NULL,
                next_renewal_at TEXT NOT NULL,
                is_banned INTEGER NOT NULL DEFAULT 0,
                ban_reason TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS usage_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                billing_mode TEXT NOT NULL, -- 'flat_rate' or 'nanndemoya_api'
                license_key TEXT,
                provider_used TEXT NOT NULL,
                model_used TEXT NOT NULL,
                task_type TEXT NOT NULL DEFAULT 'chat',
                prompt_tokens INTEGER NOT NULL DEFAULT 0,
                completion_tokens INTEGER NOT NULL DEFAULT 0,
                latency_ms REAL NOT NULL DEFAULT 0.0,
                created_epoch INTEGER NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_usage_user_epoch ON usage_logs(user_id, billing_mode, created_epoch);
            CREATE INDEX IF NOT EXISTS idx_usage_license ON usage_logs(license_key, created_epoch);

            CREATE TABLE IF NOT EXISTS nanndemoya_licenses (
                license_key TEXT PRIMARY KEY,
                owner_user_id TEXT NOT NULL,
                label TEXT NOT NULL DEFAULT 'NanndemoyaAPI 標準ライセンス',
                preferred_provider TEXT NOT NULL DEFAULT 'auto',
                status TEXT NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE' or 'SUSPENDED'
                total_requests INTEGER NOT NULL DEFAULT 0,
                total_prompt_tokens INTEGER NOT NULL DEFAULT 0,
                total_completion_tokens INTEGER NOT NULL DEFAULT 0,
                note TEXT,
                created_at TEXT NOT NULL,
                last_used_at TEXT
            );

            CREATE TABLE IF NOT EXISTS runtime_state (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """
        )
        # 初期動作確認用 NanndemoyaAPI ライセンスキー（開発者・テスト確認用）を登録
        now_str = iso_utc(utc_now())
        conn.execute(
            """
            INSERT OR IGNORE INTO nanndemoya_licenses
            (license_key, owner_user_id, label, preferred_provider, status, note, created_at)
            VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?)
            """,
            (
                "NDM-OFFICIAL-DEV-2026",
                "zuyasi",
                "何でも屋 公式マスター検証ライセンス",
                "auto",
                "課金基盤不要・何でも屋直接精算モデル用ライセンスキー",
                now_str,
            ),
        )


init_db()


# ==============================================================================
# ユーザー取得・月次自動更新（繰越処理）・レート集計ロジック
# ==============================================================================
def ensure_and_refresh_user(conn: sqlite3.Connection, user_id: str, account_type: str = "NanndemoyaCloud") -> sqlite3.Row:
    now = utc_now()
    now_str = iso_utc(now)
    row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
    if row is None:
        default_plan = FLAT_RATE_PLANS["free"]
        next_ren = iso_utc(now + timedelta(days=30))
        conn.execute(
            """
            INSERT INTO users (
                user_id, account_type, plan_id, plan_enabled,
                base_remaining, rollover_remaining, addon_remaining,
                ad_bonus_remaining, ad_bonus_earned_month,
                cycle_started_at, next_renewal_at, created_at, updated_at
            ) VALUES (?, ?, 'free', 1, ?, 0, 0, 0, 0, ?, ?, ?, ?)
            """,
            (user_id, account_type, default_plan["base_monthly_prompts"], now_str, next_ren, now_str, now_str),
        )
        row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
        return row

    # 旧プランIDで保存されている場合は新・実費プランIDへ自動移行
    mapped_plan_id = LEGACY_PLAN_MAPPING.get(row["plan_id"], row["plan_id"])
    if mapped_plan_id not in FLAT_RATE_PLANS:
        mapped_plan_id = "free"
    if mapped_plan_id != row["plan_id"]:
        conn.execute(
            "UPDATE users SET plan_id = ?, updated_at = ? WHERE user_id = ?",
            (mapped_plan_id, now_str, user_id),
        )
        row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()

    # 繰越期限切れチェック
    rollover_rem = row["rollover_remaining"]
    rollover_exp = parse_iso(row["rollover_expires_at"])
    if rollover_exp and now >= rollover_exp:
        rollover_rem = 0

    addon_rem = row["addon_remaining"]
    addon_exp = parse_iso(row["addon_expires_at"])
    if addon_exp and now >= addon_exp:
        addon_rem = 0

    # 月次更新タイミング到達時は未使用の基本枠＋広告ボーナスを繰越枠へ移行して新サイクル開始
    next_ren_dt = parse_iso(row["next_renewal_at"])
    if next_ren_dt and now >= next_ren_dt:
        plan_cfg = FLAT_RATE_PLANS.get(row["plan_id"], FLAT_RATE_PLANS["free"])
        carry = max(0, row["base_remaining"] + row["ad_bonus_remaining"])
        new_rollover = rollover_rem + carry
        new_rollover_exp = iso_utc(now + timedelta(days=plan_cfg["rollover_days"]))
        new_next_ren = iso_utc(now + timedelta(days=30))
        conn.execute(
            """
            UPDATE users SET
                base_remaining = ?,
                rollover_remaining = ?,
                rollover_expires_at = ?,
                addon_remaining = ?,
                ad_bonus_remaining = 0,
                ad_bonus_earned_month = 0,
                cycle_started_at = ?,
                next_renewal_at = ?,
                updated_at = ?
            WHERE user_id = ?
            """,
            (
                plan_cfg["base_monthly_prompts"],
                new_rollover,
                new_rollover_exp,
                addon_rem,
                now_str,
                new_next_ren,
                now_str,
                user_id,
            ),
        )
        row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()
    elif rollover_rem != row["rollover_remaining"] or addon_rem != row["addon_remaining"]:
        conn.execute(
            "UPDATE users SET rollover_remaining = ?, addon_remaining = ?, updated_at = ? WHERE user_id = ?",
            (rollover_rem, addon_rem, now_str, user_id),
        )
        row = conn.execute("SELECT * FROM users WHERE user_id = ?", (user_id,)).fetchone()

    return row


def get_window_usage(conn: sqlite3.Connection, user_id: str) -> Dict[str, int]:
    now_ep = int(time.time())
    ep_1m = now_ep - 60
    ep_5h = now_ep - (5 * 3600)
    ep_7d = now_ep - (7 * 86400)
    ep_30d = now_ep - (30 * 86400)

    used_1m = conn.execute(
        "SELECT COUNT(*) FROM usage_logs WHERE user_id = ? AND created_epoch >= ?",
        (user_id, ep_1m),
    ).fetchone()[0]
    used_5h = conn.execute(
        "SELECT COUNT(*) FROM usage_logs WHERE user_id = ? AND billing_mode = 'flat_rate' AND created_epoch >= ?",
        (user_id, ep_5h),
    ).fetchone()[0]
    used_7d = conn.execute(
        "SELECT COUNT(*) FROM usage_logs WHERE user_id = ? AND billing_mode = 'flat_rate' AND created_epoch >= ?",
        (user_id, ep_7d),
    ).fetchone()[0]
    used_30d = conn.execute(
        "SELECT COUNT(*) FROM usage_logs WHERE user_id = ? AND billing_mode = 'flat_rate' AND created_epoch >= ?",
        (user_id, ep_30d),
    ).fetchone()[0]

    return {
        "used_1m": used_1m,
        "used_5h": used_5h,
        "used_weekly": used_7d,
        "used_monthly": used_30d,
    }


def serialize_user_quota(conn: sqlite3.Connection, row: sqlite3.Row) -> Dict[str, Any]:
    plan_cfg = FLAT_RATE_PLANS.get(row["plan_id"], FLAT_RATE_PLANS["free"])
    win = get_window_usage(conn, row["user_id"])
    total_remaining = (
        row["base_remaining"]
        + row["ad_bonus_remaining"]
        + row["rollover_remaining"]
        + row["addon_remaining"]
    )
    rem_5h = max(0, plan_cfg["limit_5hour"] - win["used_5h"])
    rem_weekly = max(0, plan_cfg["limit_weekly"] - win["used_weekly"])

    return {
        "user_id": row["user_id"],
        "account_type": row["account_type"],
        "plan_id": row["plan_id"],
        "plan_name": plan_cfg["name"],
        "price_jpy": plan_cfg["price_jpy"],
        "plan_enabled": bool(row["plan_enabled"]) and not bool(row["is_banned"]),
        "is_banned": bool(row["is_banned"]),
        "ban_reason": row["ban_reason"],
        "remaining_prompts": total_remaining,
        "total_monthly_cap": plan_cfg["max_monthly_total"],
        "breakdown": {
            "base_remaining": row["base_remaining"],
            "base_monthly_allocation": plan_cfg["base_monthly_prompts"],
            "ad_bonus_remaining": row["ad_bonus_remaining"],
            "ad_bonus_earned_month": row["ad_bonus_earned_month"],
            "ad_bonus_monthly_cap": plan_cfg["ad_bonus_monthly_cap"],
            "rollover_remaining": row["rollover_remaining"],
            "rollover_expires_at": row["rollover_expires_at"],
            "addon_remaining": row["addon_remaining"],
        },
        "windows": {
            "limit_5hour": plan_cfg["limit_5hour"],
            "used_5hour": win["used_5h"],
            "remaining_5hour": rem_5h,
            "limit_weekly": plan_cfg["limit_weekly"],
            "used_weekly": win["used_weekly"],
            "remaining_weekly": rem_weekly,
            "used_monthly": win["used_monthly"],
        },
        "cycle_started_at": row["cycle_started_at"],
        "next_renewal_at": row["next_renewal_at"],
        "requires_trial_ad": plan_cfg["requires_trial_ad"],
    }


# ==============================================================================
# ハイブリッド LLM 推論ルーター
# ==============================================================================
def split_think_tag(text: str) -> Tuple[str, Optional[str]]:
    """<think>...</think> タグが含まれる場合に思考ログと最終応答へ分離する"""
    m = re.search(r"<think>(.*?)</think>", text, flags=re.DOTALL)
    if m:
        thinking = m.group(1).strip()
        cleaned = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL).strip()
        return cleaned, thinking
    return text.strip(), None


def call_gemini_api(api_key: str, system_prompt: str, user_prompt: str, model_hint: str, temperature: float) -> Tuple[str, str, int, int]:
    low = (model_hint or "").lower()
    if "pro" in low:
        candidates = ["gemini-pro-latest", "gemini-2.5-pro", "gemini-flash-latest"]
    elif "lite" in low:
        candidates = ["gemini-2.5-flash-lite", "gemini-flash-latest"]
    elif "2.0" in low:
        candidates = ["gemini-2.0-flash", "gemini-flash-latest"]
    else:
        candidates = ["gemini-flash-latest", "gemini-2.5-flash", "gemini-2.5-flash-lite"]

    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": api_key.strip(),
    }
    payload = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
        "generationConfig": {"temperature": temperature, "maxOutputTokens": 8192},
    }

    last_err: Optional[Exception] = None
    for model_id in candidates:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_id}:generateContent"
        try:
            res = requests.post(url, headers=headers, json=payload, timeout=90)
            if res.status_code in (404, 400):
                last_err = RuntimeError(f"HTTP {res.status_code} on {model_id}: {res.text[:200]}")
                continue
            res.raise_for_status()
            data = res.json()
            parts = data["candidates"][0]["content"].get("parts", [])
            thought_texts = [p["text"] for p in parts if p.get("thought") and p.get("text")]
            answer_texts = [p["text"] for p in parts if not p.get("thought") and p.get("text")]
            text = "\n".join(answer_texts).strip() or "\n".join(thought_texts).strip()
            if thought_texts and answer_texts:
                text = f"<think>{chr(10).join(thought_texts)}</think>\n{text}"
            usage = data.get("usageMetadata", {})
            p_tok = usage.get("promptTokenCount", max(1, len(user_prompt) // 2))
            c_tok = usage.get("candidatesTokenCount", max(1, len(text) // 2))
            return text, f"Google Gemini ({model_id})", p_tok, c_tok
        except Exception as exc:
            last_err = exc
            continue

    raise last_err or RuntimeError("Gemini API call failed across all candidate models")


def call_openai_compatible(
    base_url: str,
    api_key: str,
    model_id: str,
    provider_label: str,
    system_prompt: str,
    user_prompt: str,
    temperature: float,
) -> Tuple[str, str, int, int]:
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
    }
    payload = {
        "model": model_id,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": temperature,
    }
    res = requests.post(base_url, headers=headers, json=payload, timeout=90)
    res.raise_for_status()
    data = res.json()
    msg = data["choices"][0]["message"]
    text = msg.get("content") or ""
    reasoning = msg.get("reasoning_content")
    if reasoning and "<think>" not in text:
        text = f"<think>{reasoning}</think>\n{text}"
    usage = data.get("usage", {})
    p_tok = usage.get("prompt_tokens", max(1, len(user_prompt) // 2))
    c_tok = usage.get("completion_tokens", max(1, len(text) // 2))
    return text, f"{provider_label} ({model_id})", p_tok, c_tok


def call_claude_api(api_key: str, system_prompt: str, user_prompt: str, model_hint: str, temperature: float) -> Tuple[str, str, int, int]:
    model_id = "claude-3-5-haiku-latest" if "haiku" in model_hint.lower() else "claude-3-7-sonnet-latest"
    headers = {
        "Content-Type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }
    payload = {
        "model": model_id,
        "system": system_prompt,
        "max_tokens": 3072,
        "temperature": temperature,
        "messages": [{"role": "user", "content": user_prompt}],
    }
    res = requests.post("https://api.anthropic.com/v1/messages", headers=headers, json=payload, timeout=90)
    res.raise_for_status()
    data = res.json()
    text = data["content"][0]["text"]
    usage = data.get("usage", {})
    return text, f"Anthropic Claude ({model_id})", usage.get("input_tokens", 100), usage.get("output_tokens", 150)


def get_installed_ollama_models() -> List[str]:
    try:
        r = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=3)
        if r.status_code == 200:
            return [m["name"] for m in r.json().get("models", [])]
    except Exception:
        pass
    return []


def call_local_ollama(system_prompt: str, user_prompt: str, requested_model: str, temperature: float) -> Tuple[str, str, int, int]:
    installed = get_installed_ollama_models()
    chosen = DEFAULT_LOCAL_MODEL
    req_low = requested_model.lower()

    if installed:
        # 要求に近いインストール済みモデルを優先選択
        if "deepseek" in req_low or "r1" in req_low:
            matches = [m for m in installed if "deepseek" in m.lower()]
            chosen = matches[0] if matches else installed[0]
        elif "qwen" in req_low:
            matches = [m for m in installed if "qwen" in m.lower()]
            chosen = matches[0] if matches else installed[0]
        elif DEFAULT_LOCAL_MODEL in installed:
            chosen = DEFAULT_LOCAL_MODEL
        else:
            chosen = installed[0]

    payload = {
        "model": chosen,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "keep_alive": "24h",
        "options": {
            "temperature": temperature,
            "num_ctx": 2048,
            "num_predict": 512,
            "num_thread": max(2, os.cpu_count() or 4),
        },
        "stream": False,
    }
    res = requests.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload, timeout=240)
    res.raise_for_status()
    data = res.json()
    text = data.get("message", {}).get("content", "")
    p_tok = data.get("prompt_eval_count") or max(1, len(user_prompt) // 2)
    c_tok = data.get("eval_count") or max(1, len(text) // 2)
    return text, f"Local Ollama ({chosen})", p_tok, c_tok


def _warmup_local_ollama_bg():
    """サービス起動時にデフォルトモデルをメモリへ事前ロードし、初回コールドスタート遅延を防ぐ"""
    try:
        installed = get_installed_ollama_models()
        if not installed:
            return
        chosen = DEFAULT_LOCAL_MODEL if DEFAULT_LOCAL_MODEL in installed else installed[0]
        requests.post(
            f"{OLLAMA_BASE_URL}/api/chat",
            json={
                "model": chosen,
                "messages": [],
                "keep_alive": "24h",
                "options": {"num_ctx": 2048, "num_thread": max(2, os.cpu_count() or 4)},
            },
            timeout=180,
        )
    except Exception as exc:
        print(f"[Gateway Warmup] Ollama preload skipped: {exc}")


threading.Thread(target=_warmup_local_ollama_bg, daemon=True).start()


def route_inference(
    system_prompt: str,
    user_prompt: str,
    requested_model: str,
    preferred_provider: str = "auto",
    temperature: float = 0.7,
) -> Tuple[str, Optional[str], str, int, int]:
    """
    優先順位に基づき最適な推論バックエンドを実行し、(本文, 思考ログ, 実行エンジン名, 入力トークン, 出力トークン) を返す
    """
    low_model = (requested_model or "").lower()
    prov = (preferred_provider or "auto").lower()

    # 1. 明示プロバイダまたはマスターAPIキーによる高速クラウド推論プロキシ
    try:
        if (prov == "gemini" or "gemini" in low_model) and MASTER_KEYS["gemini"]:
            raw, eng, pt, ct = call_gemini_api(MASTER_KEYS["gemini"], system_prompt, user_prompt, requested_model, temperature)
            ans, thk = split_think_tag(raw)
            return ans, thk, eng, pt, ct

        if (prov == "deepseek" or ("deepseek" in low_model and MASTER_KEYS["deepseek"])) and MASTER_KEYS["deepseek"]:
            m_id = "deepseek-reasoner" if "r1" in low_model or "reason" in low_model else "deepseek-chat"
            raw, eng, pt, ct = call_openai_compatible(
                "https://api.deepseek.com/chat/completions",
                MASTER_KEYS["deepseek"],
                m_id,
                "DeepSeek API",
                system_prompt,
                user_prompt,
                temperature,
            )
            ans, thk = split_think_tag(raw)
            return ans, thk, eng, pt, ct

        if (prov == "openai" or "gpt" in low_model) and MASTER_KEYS["openai"]:
            m_id = "gpt-4o-mini" if "mini" in low_model else "gpt-4o"
            raw, eng, pt, ct = call_openai_compatible(
                "https://api.openai.com/v1/chat/completions",
                MASTER_KEYS["openai"],
                m_id,
                "OpenAI API",
                system_prompt,
                user_prompt,
                temperature,
            )
            ans, thk = split_think_tag(raw)
            return ans, thk, eng, pt, ct

        if (prov == "claude" or "claude" in low_model) and MASTER_KEYS["claude"]:
            raw, eng, pt, ct = call_claude_api(MASTER_KEYS["claude"], system_prompt, user_prompt, requested_model, temperature)
            ans, thk = split_think_tag(raw)
            return ans, thk, eng, pt, ct

        if (prov == "grok" or "grok" in low_model) and MASTER_KEYS["grok"]:
            raw, eng, pt, ct = call_openai_compatible(
                "https://api.x.ai/v1/chat/completions",
                MASTER_KEYS["grok"],
                "grok-3-mini",
                "xAI Grok",
                system_prompt,
                user_prompt,
                temperature,
            )
            ans, thk = split_think_tag(raw)
            return ans, thk, eng, pt, ct

        if (prov == "mistral" or "mistral" in low_model) and MASTER_KEYS["mistral"]:
            raw, eng, pt, ct = call_openai_compatible(
                "https://api.mistral.ai/v1/chat/completions",
                MASTER_KEYS["mistral"],
                "mistral-large-latest",
                "Mistral AI",
                system_prompt,
                user_prompt,
                temperature,
            )
            ans, thk = split_think_tag(raw)
            return ans, thk, eng, pt, ct

        # auto モード時にマスターキーがある場合は最もコスパの高いキーを自動利用
        if prov == "auto" and "ollama" not in low_model and "local" not in low_model:
            if MASTER_KEYS["gemini"]:
                raw, eng, pt, ct = call_gemini_api(MASTER_KEYS["gemini"], system_prompt, user_prompt, "gemini-2.5-flash", temperature)
                ans, thk = split_think_tag(raw)
                return ans, thk, eng, pt, ct
            if MASTER_KEYS["deepseek"]:
                raw, eng, pt, ct = call_openai_compatible(
                    "https://api.deepseek.com/chat/completions",
                    MASTER_KEYS["deepseek"],
                    "deepseek-chat",
                    "DeepSeek API",
                    system_prompt,
                    user_prompt,
                    temperature,
                )
                ans, thk = split_think_tag(raw)
                return ans, thk, eng, pt, ct
            if MASTER_KEYS["openrouter"]:
                raw, eng, pt, ct = call_openai_compatible(
                    "https://openrouter.ai/api/v1/chat/completions",
                    MASTER_KEYS["openrouter"],
                    "qwen/qwen3-14b",
                    "OpenRouter",
                    system_prompt,
                    user_prompt,
                    temperature,
                )
                ans, thk = split_think_tag(raw)
                return ans, thk, eng, pt, ct
    except Exception as cloud_err:
        print(f"[Gateway Router] Cloud upstream fallback triggered: {cloud_err}")

    # 2. ローカル Ollama 推論エンジン (MacMini 常駐モデル)
    raw, eng, pt, ct = call_local_ollama(system_prompt, user_prompt, requested_model, temperature)
    ans, thk = split_think_tag(raw)
    return ans, thk, eng, pt, ct


# ==============================================================================
# リクエスト / レスポンス スキーマ
# ==============================================================================
class CompletionRequest(BaseModel):
    user_id: str = "local_user_default"
    account_type: str = "NanndemoyaCloud"
    system_prompt: Optional[str] = None
    user_prompt: str
    model: str = "qwen2.5:3b"
    persona: Optional[str] = None
    temperature: float = 0.7
    task_type: str = "chat"  # 'chat', 'edit', 'prompt_translate'
    edit_mode: Optional[str] = None
    tone_description: Optional[str] = None
    nanndemoya_license_key: Optional[str] = None


class PlanSelectRequest(BaseModel):
    user_id: str
    plan_id: str
    account_type: str = "NanndemoyaCloud"


class PlanRefreshRequest(BaseModel):
    user_id: str


class QuotaUpdateRequest(BaseModel):
    user_id: str
    add_prompts: Optional[int] = None
    pack_id: Optional[str] = None
    source: str = "trial_ad"  # 'trial_ad' or 'addon_pack'


class NanndemoyaVerifyRequest(BaseModel):
    license_key: str
    user_id: Optional[str] = None


class AdminIssueLicenseRequest(BaseModel):
    owner_user_id: str
    label: str = "NanndemoyaAPI 利用ライセンス"
    preferred_provider: str = "auto"
    note: Optional[str] = None


class ColabEndpointSyncRequest(BaseModel):
    colab_url: str


# ==============================================================================
# エンドポイント実装
# ==============================================================================
def get_system_metrics() -> Tuple[float, float]:
    cpu_pct = 14.0
    mem_pct = 48.0
    try:
        cores = max(1, os.cpu_count() or 1)
        load1 = os.getloadavg()[0]
        cpu_pct = round(min(100.0, max(1.0, (load1 / cores) * 100.0)), 1)
    except Exception:
        pass
    try:
        if os.path.exists("/proc/meminfo"):
            info: Dict[str, int] = {}
            with open("/proc/meminfo", "r", encoding="utf-8") as f:
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        val_parts = parts[1].strip().split()
                        if val_parts and val_parts[0].isdigit():
                            info[parts[0].strip()] = int(val_parts[0])
            total = info.get("MemTotal", 0)
            avail = info.get("MemAvailable", 0)
            if total > 0:
                mem_pct = round(min(100.0, max(1.0, ((total - avail) / total) * 100.0)), 1)
    except Exception:
        pass
    return cpu_pct, mem_pct


@app.get("/health")
def health():
    ollama_models = get_installed_ollama_models()
    configured_upstreams = [k for k, v in MASTER_KEYS.items() if v]
    cpu_pct, mem_pct = get_system_metrics()
    with get_db() as conn:
        user_count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
        colab_row = conn.execute("SELECT value FROM runtime_state WHERE key = 'colab_url'").fetchone()
        colab_url = colab_row["value"] if colab_row else ""

    return {
        "status": "OPERATIONAL",
        "version": "3.0.0",
        "server_time": iso_utc(utc_now()),
        "machine_type": "Debian 13 Gateway (MacMini + Hybrid LLM Router)",
        "zone": "nanndemoya-edge-jp",
        "engine": f"Hybrid Gateway (Ollama: {', '.join(ollama_models) if ollama_models else 'standby'})",
        "ollama_models": ollama_models,
        "configured_cloud_upstreams": configured_upstreams,
        "colab_endpoint": colab_url,
        "active_local_users": user_count,
        "cpu_percent": cpu_pct,
        "memory_percent": mem_pct,
        "pricing_version": "v3.0-public-flat-rate",
        "features": [
            "chat",
            "edit_structured",
            "prompt_quota_v3",
            "5h_weekly_monthly_windows",
            "rollover",
            "nanndemoya_license_relay",
        ],
    }


@app.get("/v1/plans")
def list_plans():
    return {
        "pricing_version": "3.0.0",
        "plans": list(FLAT_RATE_PLANS.values()),
        "addon_packs": list(ADDON_PROMPT_PACKS.values()),
        "ad_reward_prompts_per_view": AD_REWARD_PROMPTS_PER_VIEW,
    }


@app.get("/v1/user/status/{user_id}")
def get_user_status(user_id: str):
    with get_db() as conn:
        row = ensure_and_refresh_user(conn, user_id)
        return serialize_user_quota(conn, row)


@app.get("/v1/user/prompts/{user_id}")
def get_user_prompts_compat(user_id: str):
    with get_db() as conn:
        row = ensure_and_refresh_user(conn, user_id)
        status = serialize_user_quota(conn, row)
        return {
            "user_id": user_id,
            "remaining_prompts": status["remaining_prompts"],
            "plan_id": status["plan_id"],
            "plan_name": status["plan_name"],
            "status": status,
        }


@app.post("/v1/user/plan/select")
def select_plan(req: PlanSelectRequest):
    resolved_plan_id = LEGACY_PLAN_MAPPING.get(req.plan_id, req.plan_id)
    if resolved_plan_id not in FLAT_RATE_PLANS:
        raise HTTPException(status_code=400, detail=f"未定義のプランIDです: {req.plan_id}")

    plan_cfg = FLAT_RATE_PLANS[resolved_plan_id]
    now = utc_now()
    now_str = iso_utc(now)
    next_ren = iso_utc(now + timedelta(days=30))
    rollover_exp = iso_utc(now + timedelta(days=plan_cfg["rollover_days"]))

    with get_db() as conn:
        row = ensure_and_refresh_user(conn, req.user_id, req.account_type)
        if row["is_banned"]:
            raise HTTPException(status_code=403, detail=f"不正利用制限中のためプラン変更できません: {row['ban_reason']}")

        # 既存の未使用基本枠を繰越枠に保護した上で新プランの基本枠を付与
        carried = max(0, row["base_remaining"])
        new_rollover = row["rollover_remaining"] + (carried if row["plan_id"] != resolved_plan_id else 0)
        conn.execute(
            """
            UPDATE users SET
                account_type = ?,
                plan_id = ?,
                plan_enabled = 1,
                base_remaining = ?,
                rollover_remaining = ?,
                rollover_expires_at = ?,
                cycle_started_at = ?,
                next_renewal_at = ?,
                updated_at = ?
            WHERE user_id = ?
            """,
            (
                req.account_type,
                resolved_plan_id,
                plan_cfg["base_monthly_prompts"],
                new_rollover,
                rollover_exp,
                now_str,
                next_ren,
                now_str,
                req.user_id,
            ),
        )
        updated = conn.execute("SELECT * FROM users WHERE user_id = ?", (req.user_id,)).fetchone()
        return serialize_user_quota(conn, updated)


@app.post("/v1/user/plan/refresh")
def refresh_plan_cycle(req: PlanRefreshRequest):
    """仕様書『利用枠の再購入』: 次回更新日を1ヶ月後に再設定し、現在のプランの基本利用枠を即時リセット回復"""
    now = utc_now()
    now_str = iso_utc(now)
    next_ren = iso_utc(now + timedelta(days=30))
    with get_db() as conn:
        row = ensure_and_refresh_user(conn, req.user_id)
        if row["is_banned"]:
            raise HTTPException(status_code=403, detail="利用制限中のため再購入リセットはできません。")
        plan_cfg = FLAT_RATE_PLANS.get(row["plan_id"], FLAT_RATE_PLANS["free"])
        conn.execute(
            """
            UPDATE users SET
                base_remaining = ?,
                ad_bonus_earned_month = 0,
                cycle_started_at = ?,
                next_renewal_at = ?,
                updated_at = ?
            WHERE user_id = ?
            """,
            (plan_cfg["base_monthly_prompts"], now_str, next_ren, now_str, req.user_id),
        )
        updated = conn.execute("SELECT * FROM users WHERE user_id = ?", (req.user_id,)).fetchone()
        return serialize_user_quota(conn, updated)


@app.post("/v1/user/prompts")
def add_user_prompts(req: QuotaUpdateRequest):
    now = utc_now()
    now_str = iso_utc(now)
    with get_db() as conn:
        row = ensure_and_refresh_user(conn, req.user_id)
        if row["is_banned"]:
            raise HTTPException(status_code=403, detail="利用制限中のアカウントです。")

        plan_cfg = FLAT_RATE_PLANS.get(row["plan_id"], FLAT_RATE_PLANS["free"])

        if req.pack_id:
            if req.pack_id not in ADDON_PROMPT_PACKS:
                raise HTTPException(status_code=400, detail=f"無効な追加パックIDです: {req.pack_id}")
            pack = ADDON_PROMPT_PACKS[req.pack_id]
            add_n = pack["prompts"]
            addon_exp = iso_utc(now + timedelta(days=365))
            conn.execute(
                "UPDATE users SET addon_remaining = addon_remaining + ?, addon_expires_at = ?, updated_at = ? WHERE user_id = ?",
                (add_n, addon_exp, now_str, req.user_id),
            )
        elif req.source == "addon_pack" and req.add_prompts:
            addon_exp = iso_utc(now + timedelta(days=365))
            conn.execute(
                "UPDATE users SET addon_remaining = addon_remaining + ?, addon_expires_at = ?, updated_at = ? WHERE user_id = ?",
                (max(0, req.add_prompts), addon_exp, now_str, req.user_id),
            )
        else:
            # お試し広告視聴によるプロンプト獲得 (プランごとの月間広告ボーナス上限を厳守)
            requested_add = req.add_prompts if (req.add_prompts and req.add_prompts > 0) else AD_REWARD_PROMPTS_PER_VIEW
            cap = plan_cfg["ad_bonus_monthly_cap"]
            already_earned = row["ad_bonus_earned_month"]
            grantable = max(0, min(requested_add, cap - already_earned))
            if grantable <= 0:
                raise HTTPException(
                    status_code=429,
                    detail=f"今月のお試し広告ボーナス獲得上限（{cap}回）に達しています。上位プランへの変更または追加パックをご検討ください。",
                )
            conn.execute(
                """
                UPDATE users SET
                    ad_bonus_remaining = ad_bonus_remaining + ?,
                    ad_bonus_earned_month = ad_bonus_earned_month + ?,
                    updated_at = ?
                WHERE user_id = ?
                """,
                (grantable, grantable, now_str, req.user_id),
            )

        updated = conn.execute("SELECT * FROM users WHERE user_id = ?", (req.user_id,)).fetchone()
        status = serialize_user_quota(conn, updated)
        return {
            "user_id": req.user_id,
            "remaining_prompts": status["remaining_prompts"],
            "status": status,
        }


@app.post("/v1/nanndemoya/verify")
def verify_nanndemoya_license(req: NanndemoyaVerifyRequest):
    """NanndemoyaAPI ライセンスキーの有効性確認と利用明細返却（決済機能なし）"""
    key = req.license_key.strip()
    with get_db() as conn:
        lic = conn.execute(
            "SELECT * FROM nanndemoya_licenses WHERE license_key = ?",
            (key,),
        ).fetchone()
        if not lic:
            raise HTTPException(status_code=401, detail="無効な NanndemoyaAPI ライセンスキーです。「何でも屋」へ発行申請を行ってください。")
        if lic["status"] != "ACTIVE":
            raise HTTPException(status_code=403, detail=f"このライセンスキーは現在停止中です (status={lic['status']})。")

        return {
            "valid": True,
            "license_key": lic["license_key"],
            "owner_user_id": lic["owner_user_id"],
            "label": lic["label"],
            "preferred_provider": lic["preferred_provider"],
            "status": lic["status"],
            "usage": {
                "total_requests": lic["total_requests"],
                "total_prompt_tokens": lic["total_prompt_tokens"],
                "total_completion_tokens": lic["total_completion_tokens"],
                "last_used_at": lic["last_used_at"],
            },
        }


@app.post("/v1/chat/completions")
def chat_or_edit(req: CompletionRequest):
    start_ts = time.time()
    now = utc_now()
    now_str = iso_utc(now)
    now_ep = int(start_ts)

    # 1. ペイロードサイズ・不正ボット連投チェック (ポリシー準拠)
    if len(req.user_prompt) > 32000:
        raise HTTPException(status_code=413, detail="プロンプト長が上限（32,000文字）を超えています。")

    with get_db() as conn:
        user_row = ensure_and_refresh_user(conn, req.user_id, req.account_type)
        if user_row["is_banned"]:
            raise HTTPException(
                status_code=403,
                detail=f"【利用制限】LLMの不正利用検知により定額プランが凍結されています: {user_row['ban_reason']}",
            )

        win = get_window_usage(conn, req.user_id)
        if win["used_1m"] >= 30:
            conn.execute(
                "UPDATE users SET is_banned = 1, ban_reason = '自動ボット連投検知 (30回/分超過)', updated_at = ? WHERE user_id = ?",
                (now_str, req.user_id),
            )
            raise HTTPException(status_code=429, detail="異常な高頻度アクセス（ボット連投）が検知されたため、利用を一時制限しました。")

        # 2. NanndemoyaAPI ライセンスキー利用モード vs 定額プランクォータ消費モード
        lic_key = (req.nanndemoya_license_key or "").strip()
        is_nanndemoya_api = len(lic_key) > 0
        preferred_prov = "auto"

        # プロンプト英訳の内部補助通信はクォータ非消費（軽量処理）
        is_internal_translator = req.user_id == "tohostudio-prompt-translator" or req.task_type == "prompt_translate"

        if is_nanndemoya_api:
            lic = conn.execute(
                "SELECT * FROM nanndemoya_licenses WHERE license_key = ?",
                (lic_key,),
            ).fetchone()
            if not lic or lic["status"] != "ACTIVE":
                raise HTTPException(status_code=401, detail="NanndemoyaAPI ライセンスキーが無効または停止中です。")
            preferred_prov = lic["preferred_provider"]
        elif not is_internal_translator:
            plan_cfg = FLAT_RATE_PLANS.get(user_row["plan_id"], FLAT_RATE_PLANS["free"])
            total_rem = (
                user_row["base_remaining"]
                + user_row["ad_bonus_remaining"]
                + user_row["rollover_remaining"]
                + user_row["addon_remaining"]
            )
            if total_rem <= 0:
                raise HTTPException(
                    status_code=403,
                    detail="利用可能プロンプト残数が0です。お試し広告視聴、追加プロンプト購入、またはプラン変更を行ってください。",
                )
            # 追加パック残高がない場合は 5時間枠・週次枠バースト上限を適用
            if user_row["addon_remaining"] <= 0:
                if win["used_5h"] >= plan_cfg["limit_5hour"]:
                    raise HTTPException(
                        status_code=429,
                        detail=f"5時間あたりの利用上限（{plan_cfg['limit_5hour']}回）に達しました。時間を置くか上位プラン・追加プロンプトをご利用ください。",
                    )
                if win["used_weekly"] >= plan_cfg["limit_weekly"]:
                    raise HTTPException(
                        status_code=429,
                        detail=f"週間利用上限（{plan_cfg['limit_weekly']}回）に達しました。上位プランまたは追加プロンプトをご利用ください。",
                    )

    # 3. システムプロンプト構築 (AI編集モード or 東方RAGチャット)
    if req.edit_mode:
        built = build_ai_edit_prompts(req.edit_mode, req.user_prompt, req.tone_description or "博麗霊夢")
        final_sys = built["system_prompt"]
        final_usr = built["user_prompt"]
    elif is_internal_translator:
        final_sys = req.system_prompt or "Translate Japanese media prompt to concise English tags."
        final_usr = req.user_prompt
    else:
        final_sys = build_rag_system_prompt(req.system_prompt, req.user_prompt, req.persona)
        final_usr = req.user_prompt

    # 4. LLM推論実行
    try:
        ai_text, thinking_log, engine_used, p_tok, c_tok = route_inference(
            system_prompt=final_sys,
            user_prompt=final_usr,
            requested_model=req.model,
            preferred_provider=preferred_prov,
            temperature=req.temperature,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"LLM推論エンジン通信エラー: {str(e)}")

    latency_ms = round((time.time() - start_ts) * 1000.0, 1)

    # 5. クォータ減算 or NanndemoyaAPI 明細記録
    with get_db() as conn:
        user_row = ensure_and_refresh_user(conn, req.user_id, req.account_type)
        if is_nanndemoya_api:
            conn.execute(
                """
                UPDATE nanndemoya_licenses SET
                    total_requests = total_requests + 1,
                    total_prompt_tokens = total_prompt_tokens + ?,
                    total_completion_tokens = total_completion_tokens + ?,
                    last_used_at = ?
                WHERE license_key = ?
                """,
                (p_tok, c_tok, now_str, lic_key),
            )
            conn.execute(
                """
                INSERT INTO usage_logs
                (user_id, billing_mode, license_key, provider_used, model_used, task_type, prompt_tokens, completion_tokens, latency_ms, created_epoch, created_at)
                VALUES (?, 'nanndemoya_api', ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (req.user_id, lic_key, engine_used, req.model, req.edit_mode or req.task_type, p_tok, c_tok, latency_ms, now_ep, now_str),
            )
        elif not is_internal_translator:
            # 消化優先順: 1. お試し広告ボーナス -> 2. 月間基本枠 -> 3. 繰越枠 -> 4. 追加購入パック
            b_rem = user_row["base_remaining"]
            ad_rem = user_row["ad_bonus_remaining"]
            ro_rem = user_row["rollover_remaining"]
            add_rem = user_row["addon_remaining"]

            if ad_rem > 0:
                ad_rem -= 1
            elif b_rem > 0:
                b_rem -= 1
            elif ro_rem > 0:
                ro_rem -= 1
            elif add_rem > 0:
                add_rem -= 1

            conn.execute(
                """
                UPDATE users SET
                    base_remaining = ?,
                    ad_bonus_remaining = ?,
                    rollover_remaining = ?,
                    addon_remaining = ?,
                    updated_at = ?
                WHERE user_id = ?
                """,
                (b_rem, ad_rem, ro_rem, add_rem, now_str, req.user_id),
            )
            conn.execute(
                """
                INSERT INTO usage_logs
                (user_id, billing_mode, license_key, provider_used, model_used, task_type, prompt_tokens, completion_tokens, latency_ms, created_epoch, created_at)
                VALUES (?, 'flat_rate', NULL, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (req.user_id, engine_used, req.model, req.edit_mode or req.task_type, p_tok, c_tok, latency_ms, now_ep, now_str),
            )

        updated_row = conn.execute("SELECT * FROM users WHERE user_id = ?", (req.user_id,)).fetchone()
        quota_status = serialize_user_quota(conn, updated_row)

    # 絵コンテ生成モード時は JSON パース結果も構造化添付
    parsed_scenes = None
    if req.edit_mode == "sceneStoryboard":
        try:
            json_match = re.search(r"\{.*\}", ai_text, flags=re.DOTALL)
            if json_match:
                obj = json.loads(json_match.group(0))
                if isinstance(obj.get("scenes"), list):
                    parsed_scenes = obj["scenes"]
        except Exception:
            parsed_scenes = None

    return {
        "response": ai_text,
        "thinking": thinking_log,
        "engine": engine_used,
        "model": req.model,
        "billing_mode": "nanndemoya_api" if is_nanndemoya_api else "flat_rate",
        "remaining_prompts": quota_status["remaining_prompts"],
        "used_tokens": p_tok + c_tok,
        "prompt_tokens": p_tok,
        "completion_tokens": c_tok,
        "latency_ms": latency_ms,
        "scenes": parsed_scenes,
        "quota": quota_status,
    }


@app.post("/v1/colab/endpoint")
def sync_colab_endpoint(req: ColabEndpointSyncRequest):
    with get_db() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO runtime_state (key, value) VALUES ('colab_url', ?)",
            (req.colab_url.strip(),),
        )
    return {"status": "OK", "colab_url": req.colab_url.strip()}


# ==============================================================================
# 「何でも屋」管理者専用 API (NanndemoyaAPI キー発行 & 利用明細確認)
# ==============================================================================
def verify_admin(x_admin_token: Optional[str]):
    if not x_admin_token or x_admin_token != ADMIN_TOKEN:
        raise HTTPException(status_code=401, detail="管理者トークンが一致しません。")


@app.post("/v1/admin/nanndemoya/issue")
def admin_issue_nanndemoya_key(req: AdminIssueLicenseRequest, x_admin_token: Optional[str] = Header(default=None)):
    verify_admin(x_admin_token)
    new_key = "NDM-" + secrets.token_hex(3).upper() + "-" + secrets.token_hex(4).upper()
    now_str = iso_utc(utc_now())
    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO nanndemoya_licenses
            (license_key, owner_user_id, label, preferred_provider, status, note, created_at)
            VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?)
            """,
            (new_key, req.owner_user_id, req.label, req.preferred_provider, req.note, now_str),
        )
    return {
        "license_key": new_key,
        "owner_user_id": req.owner_user_id,
        "label": req.label,
        "preferred_provider": req.preferred_provider,
        "status": "ACTIVE",
        "created_at": now_str,
    }


@app.get("/v1/admin/nanndemoya/usage")
def admin_list_nanndemoya_usage(x_admin_token: Optional[str] = Header(default=None)):
    verify_admin(x_admin_token)
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM nanndemoya_licenses ORDER BY created_at DESC").fetchall()
        return {"licenses": [dict(r) for r in rows]}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT)
