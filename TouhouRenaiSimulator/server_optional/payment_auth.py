#!/usr/bin/env python3
"""
Google OAuth 2.0 認証 & PayPal デポジット決済管理 (payment_auth.py)
Keynote Slide 3, 13, 19-24 準拠:
  - Google OAuth クライアント情報 (secrets/google_oauth_client.json) はサーバー側のみ保持し、クライアントへ秘密鍵を渡さない
  - PayPal Orders v2 API 連携 + ローカル検証用サンドボックス即時確認モード対応
  - プレイヤー名・読み方の NGワード検証 (Slide 16)
"""

import os
import re
import json
import uuid
import secrets
import urllib.parse
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional, Tuple

import httpx

from db import (
    SERVER_DIR,
    DEPOSIT_OPTIONS_YEN,
    PROMPT_PLANS_MAP,
    AUTO_CHARGE_MAP,
    VOICE_PLANS_MAP,
    upsert_user,
    save_auth_session,
    create_deposit_order,
    get_deposit_order,
    complete_deposit_and_initial_purchase,
)

DEFAULT_OAUTH_JSON = os.path.join(SERVER_DIR, "secrets", "google_oauth_client.json")

#保留中の OAuth state (メモリ上限64件・TTL 10分)
_PENDING_AUTH_STATES: Dict[str, Dict[str, Any]] = {}


def _cleanup_states() -> None:
    now = datetime.now(timezone.utc).timestamp()
    expired = [k for k, v in _PENDING_AUTH_STATES.items() if now - v.get("ts", 0) > 600]
    for k in expired:
        _PENDING_AUTH_STATES.pop(k, None)


def load_google_oauth_config() -> Optional[Dict[str, Any]]:
    path = os.environ.get("GOOGLE_OAUTH_JSON_PATH") or DEFAULT_OAUTH_JSON
    if not os.path.isabs(path):
        path = os.path.join(SERVER_DIR, path)
    if not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            raw = json.load(f)
        return raw.get("installed") or raw.get("web")
    except Exception:
        return None


def create_google_auth_start(redirect_base_url: str) -> Dict[str, Any]:
    """GoogleログインURLを発行し、ポーリング用 auth_request_id を返す"""
    _cleanup_states()
    auth_req_id = secrets.token_urlsafe(24)
    cfg = load_google_oauth_config()
    callback_uri = f"{redirect_base_url.rstrip('/')}/api/auth/google/callback"

    _PENDING_AUTH_STATES[auth_req_id] = {
        "ts": datetime.now(timezone.utc).timestamp(),
        "status": "PENDING",
        "session_token": "",
        "user": None,
        "callback_uri": callback_uri,
    }

    if cfg and cfg.get("client_id"):
        params = {
            "client_id": cfg["client_id"],
            "redirect_uri": callback_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "state": auth_req_id,
            "access_type": "online",
            "prompt": "select_account",
        }
        auth_url = f"{cfg.get('auth_uri', 'https://accounts.google.com/o/oauth2/auth')}?{urllib.parse.urlencode(params)}"
        return {
            "auth_request_id": auth_req_id,
            "auth_url": auth_url,
            "dev_auth_url": f"{redirect_base_url.rstrip('/')}/api/auth/dev_login?state={auth_req_id}",
            "oauth_configured": True,
        }

    return {
        "auth_request_id": auth_req_id,
        "auth_url": f"{redirect_base_url.rstrip('/')}/api/auth/dev_login?state={auth_req_id}",
        "dev_auth_url": f"{redirect_base_url.rstrip('/')}/api/auth/dev_login?state={auth_req_id}",
        "oauth_configured": False,
    }


async def handle_google_oauth_callback(code: str, state: str) -> Tuple[bool, str]:
    st = _PENDING_AUTH_STATES.get(state)
    if not st:
        return False, "認証セッションの有効期限が切れました。ゲーム画面からやり直してください。"

    cfg = load_google_oauth_config()
    if not cfg:
        return False, "サーバー側の Google OAuth 設定ファイルが見つかりません。"

    token_uri = cfg.get("token_uri", "https://oauth2.googleapis.com/token")
    async with httpx.AsyncClient(timeout=12.0) as client:
        resp = await client.post(
            token_uri,
            data={
                "code": code,
                "client_id": cfg["client_id"],
                "client_secret": cfg["client_secret"],
                "redirect_uri": st["callback_uri"],
                "grant_type": "authorization_code",
            },
        )
        if resp.status_code != 200:
            st["status"] = "ERROR"
            return False, f"トークン交換に失敗しました (HTTP {resp.status_code})。Google Cloud Consoleの承認済みリダイレクトURIに {st['callback_uri']} を追加してください。"

        tok_data = resp.json()
        access_token = tok_data.get("access_token", "")
        u_resp = await client.get(
            "https://openidconnect.googleapis.com/v1/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        if u_resp.status_code != 200:
            st["status"] = "ERROR"
            return False, "Googleユーザー情報の取得に失敗しました。"
        u_info = u_resp.json()

    user_id = f"google_{u_info.get('sub', uuid.uuid4().hex)}"
    email = u_info.get("email", "")
    name = u_info.get("name") or email.split("@")[0] or "Player"
    user = upsert_user(user_id=user_id, email=email, display_name=name)

    sess_token = secrets.token_urlsafe(32)
    expires = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat(timespec="seconds")
    save_auth_session(sess_token, user_id, expires)

    st["status"] = "COMPLETED"
    st["session_token"] = sess_token
    st["user"] = user
    return True, "Googleアカウント認証が完了しました。ゲームのウィンドウに戻ってください。"


def complete_dev_login(state: str, email: str = "player@local.test", name: str = "テストプレイヤー") -> Tuple[bool, str]:
    if os.environ.get("ALLOW_DEV_AUTH", "true").lower() not in ("1", "true", "yes"):
        return False, "開発用ログインは無効化されています。"
    st = _PENDING_AUTH_STATES.get(state)
    if not st:
        return False, "認証セッションが見つかりません。ゲームの「認証開始」を押し直してください。"

    clean_email = (email or "player@local.test").strip().lower()
    user_id = "dev_" + re.sub(r"[^a-z0-9_]", "_", clean_email)[:40]
    user = upsert_user(user_id=user_id, email=clean_email, display_name=(name or "Player").strip())

    sess_token = secrets.token_urlsafe(32)
    expires = (datetime.now(timezone.utc) + timedelta(days=30)).isoformat(timespec="seconds")
    save_auth_session(sess_token, user_id, expires)

    st["status"] = "COMPLETED"
    st["session_token"] = sess_token
    st["user"] = user
    return True, "認証が完了しました。ゲームのウィンドウへ自動的に戻ります。"


def get_auth_poll_status(auth_req_id: str) -> Dict[str, Any]:
    st = _PENDING_AUTH_STATES.get(auth_req_id)
    if not st:
        return {"status": "EXPIRED"}
    return {
        "status": st["status"],
        "session_token": st.get("session_token", ""),
        "user": st.get("user"),
    }


# ==================== Slide 16: プレイヤー名・読み方 NGワード検証 ====================

_NG_PATTERNS = [
    r"(死ね|しね|殺す|ころす|自殺|レイプ|強姦|麻薬|覚醒剤|覚せい剤|爆破予告|テロ)",
    r"(fuck|shit|bitch|nigger|cunt|asshole)",
    r"(<script|javascript:|DROP\s+TABLE|SELECT\s+\*\s+FROM|--\s)",
]


def validate_player_name_and_kana(player_name: str, player_kana: str) -> Tuple[bool, str]:
    """Slide 16: NGワード・不適切表現・読み方形式の検証"""
    nm = (player_name or "").strip()
    kn = (player_kana or "").strip()

    if not nm or len(nm) > 16:
        return False, "プレイヤー名は1〜16文字で入力してください。"
    if not kn or len(kn) > 24:
        return False, "読み方は1〜24文字で入力してください。"

    # 読み方はひらがな・カタカナ・長音のみ許容
    if not re.match(r"^[ぁ-んァ-ヶー・\s]+$", kn):
        return False, "読み方は「ひらがな」または「カタカナ」で入力してください。"

    combined = f"{nm} {kn}".lower()
    for pat in _NG_PATTERNS:
        if re.search(pat, combined, flags=re.IGNORECASE):
            return False, "使用できない表現（NGワード）が含まれています。別の名前と読み方を入力してください。"

    return True, "OK"


# ==================== Slide 21-24: PayPal Orders v2 決済連携 ====================

def _paypal_api_base() -> str:
    mode = os.environ.get("PAYPAL_MODE", "sandbox").lower()
    return "https://api-m.paypal.com" if mode == "live" else "https://api-m.sandbox.paypal.com"


async def _get_paypal_access_token() -> Optional[str]:
    cid = os.environ.get("PAYPAL_CLIENT_ID", "").strip()
    csec = os.environ.get("PAYPAL_CLIENT_SECRET", "").strip()
    if not cid or not csec:
        return None
    async with httpx.AsyncClient(timeout=12.0) as client:
        resp = await client.post(
            f"{_paypal_api_base()}/v1/oauth2/token",
            auth=(cid, csec),
            data={"grant_type": "client_credentials"},
        )
        if resp.status_code == 200:
            return resp.json().get("access_token")
    return None


async def start_paypal_deposit_checkout(
    user_id: str,
    gross_yen: int,
    initial_plan_id: str,
    auto_charge_plan_id: str,
    public_base_url: str,
    initial_voice_plan_id: str = "",
) -> Dict[str, Any]:
    if gross_yen not in DEPOSIT_OPTIONS_YEN:
        raise ValueError("無効なデポジット金額です。")
    if initial_plan_id and initial_plan_id not in PROMPT_PLANS_MAP:
        raise ValueError("無効なプロンプト購入プランです。")
    if initial_voice_plan_id and initial_voice_plan_id not in VOICE_PLANS_MAP:
        raise ValueError("無効なボイスプランです。")
    if auto_charge_plan_id not in AUTO_CHARGE_MAP:
        raise ValueError("無効なオートチャージプランです。")

    order_id = "ord_" + uuid.uuid4().hex[:20]
    return_url = f"{public_base_url.rstrip('/')}/api/paypal/return?order_id={order_id}"
    cancel_url = f"{public_base_url.rstrip('/')}/api/paypal/cancel?order_id={order_id}"

    pp_token = await _get_paypal_access_token()
    if pp_token:
        sku_id = f"THRENAI-DEPOSIT-{gross_yen}"
        item_name = f"東方Project恋愛シミュレーター デポジット {gross_yen:,}円"
        sub_notes = []
        if initial_plan_id and initial_plan_id in PROMPT_PLANS_MAP:
            sub_notes.append(f"プロンプト{PROMPT_PLANS_MAP[initial_plan_id]['prompts']}回")
        if initial_voice_plan_id and initial_voice_plan_id in VOICE_PLANS_MAP:
            sub_notes.append(VOICE_PLANS_MAP[initial_voice_plan_id]["label"].split(":")[0].strip())
        item_desc = "実費回収デポジットチャージ" + (f"（初回充当: {'＋'.join(sub_notes)}）" if sub_notes else "")

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"{_paypal_api_base()}/v2/checkout/orders",
                headers={
                    "Authorization": f"Bearer {pp_token}",
                    "Content-Type": "application/json",
                    "PayPal-Request-Id": order_id,
                },
                json={
                    "intent": "CAPTURE",
                    "purchase_units": [
                        {
                            "reference_id": order_id,
                            "custom_id": sku_id,
                            "description": item_desc[:120],
                            "amount": {
                                "currency_code": "JPY",
                                "value": str(gross_yen),
                                "breakdown": {
                                    "item_total": {"currency_code": "JPY", "value": str(gross_yen)}
                                },
                            },
                            "items": [
                                {
                                    "name": item_name,
                                    "sku": sku_id,
                                    "description": item_desc[:120],
                                    "unit_amount": {"currency_code": "JPY", "value": str(gross_yen)},
                                    "quantity": "1",
                                    "category": "DIGITAL_GOODS",
                                }
                            ],
                        }
                    ],
                    "application_context": {
                        "brand_name": "東方Project恋愛シミュレーター",
                        "locale": "ja-JP",
                        "shipping_preference": "NO_SHIPPING",
                        "user_action": "PAY_NOW",
                        "return_url": return_url,
                        "cancel_url": cancel_url,
                    },
                },
            )
            if resp.status_code in (200, 201):
                pp_data = resp.json()
                pp_order_id = pp_data.get("id", "")
                approve_url = next(
                    (lk["href"] for lk in pp_data.get("links", []) if lk.get("rel") == "approve"),
                    "",
                )
                return create_deposit_order(
                    order_id=order_id,
                    user_id=user_id,
                    gross_yen=gross_yen,
                    initial_plan_id=initial_plan_id,
                    auto_charge_plan_id=auto_charge_plan_id,
                    initial_voice_plan_id=initial_voice_plan_id,
                    paypal_order_id=pp_order_id,
                    approve_url=approve_url,
                )
            raise ValueError(f"PayPal注文作成エラー (HTTP {resp.status_code}): {resp.text[:200]}")

    if os.environ.get("ALLOW_SANDBOX_SIMULATION", "false").lower() not in ("1", "true", "yes"):
        raise ValueError("PayPal APIとの通信に失敗しました。時間をおいて再度お試しください。")

    # PayPal API認証情報未設定時のローカル検証用チェックアウト画面
    sim_url = f"{public_base_url.rstrip('/')}/api/paypal/sandbox_checkout?order_id={order_id}"
    return create_deposit_order(
        order_id=order_id,
        user_id=user_id,
        gross_yen=gross_yen,
        initial_plan_id=initial_plan_id,
        auto_charge_plan_id=auto_charge_plan_id,
        initial_voice_plan_id=initial_voice_plan_id,
        paypal_order_id=f"SIM_{order_id}",
        approve_url=sim_url,
    )


async def verify_and_capture_paypal_order(order_id: str) -> Dict[str, Any]:
    order = get_deposit_order(order_id)
    if not order:
        raise ValueError("注文が見つかりません。")
    if order["status"] == "COMPLETED":
        return complete_deposit_and_initial_purchase(order_id)

    pp_oid = order.get("paypal_order_id", "")
    if pp_oid and not pp_oid.startswith("SIM_"):
        pp_token = await _get_paypal_access_token()
        if not pp_token:
            raise ValueError("PayPal API認証に失敗しました。")
        async with httpx.AsyncClient(timeout=15.0) as client:
            cap_resp = await client.post(
                f"{_paypal_api_base()}/v2/checkout/orders/{pp_oid}/capture",
                headers={"Authorization": f"Bearer {pp_token}", "Content-Type": "application/json"},
            )
            if cap_resp.status_code not in (200, 201):
                # 既にキャプチャ済みか確認
                get_resp = await client.get(
                    f"{_paypal_api_base()}/v2/checkout/orders/{pp_oid}",
                    headers={"Authorization": f"Bearer {pp_token}"},
                )
                if get_resp.status_code != 200 or get_resp.json().get("status") != "COMPLETED":
                    raise ValueError("PayPal支払いが未完了です。支払いを完了してから再試行してください。")
        return complete_deposit_and_initial_purchase(order_id)

    # SIMモードの場合は sandbox_checkout で承認済みのステータス (APPROVED_SIM) を確認
    if order["status"] != "APPROVED_SIM":
        raise ValueError("支払い手続きがまだ完了していません。")
    return complete_deposit_and_initial_purchase(order_id)
