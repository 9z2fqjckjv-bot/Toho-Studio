#!/usr/bin/env python3
"""
『東方Project恋愛シミュレーター』自宅Linux省リソースAPIサーバー (app.py)
【外部素材クライアントローカル参照方式】:
  - 立ち絵・背景などの外部画像素材はホストサーバーから一切配信しない（再配布・商用配信防止＋サーバーHDD I/Oゼロ化）
  - サーバーは Gemini API 対話生成・音声記号列生成・AquesTalk1 オンメモリ音声合成・課金台帳のみを担当
  - Minecraftサーバー等と共存するため FastAPI + Uvicorn 1ワーカー + nice 15 + ionice idle + Semaphore(2) で稼働
"""

import os
import sys
import time
import base64
import hashlib
import asyncio
import urllib.parse
from collections import OrderedDict
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, Header, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

SERVER_DIR = os.path.abspath(os.path.dirname(__file__))
if SERVER_DIR not in sys.path:
    sys.path.insert(0, SERVER_DIR)

_ENV_FILE = os.path.join(SERVER_DIR, ".env")
if os.path.exists(_ENV_FILE):
    with open(_ENV_FILE, "r", encoding="utf-8") as _ef:
        for _line in _ef:
            _s = _line.strip()
            if _s and not _s.startswith("#") and "=" in _s:
                _k, _v = _s.split("=", 1)
                os.environ.setdefault(_k.strip(), _v.strip().strip('"').strip("'"))

import db
from voice_service import get_voice_engine_status, synthesize_aquestalk1_in_memory
from gemini_service import (
    build_canon_prologue,
    close_shared_http_client,
    generate_dialogue_turn,
    generate_new_background_image_in_memory,
    get_master_stage_catalog,
)
from payment_auth import (
    create_google_auth_start,
    handle_google_oauth_callback,
    complete_dev_login,
    get_auth_poll_status,
    validate_player_name_and_kana,
    start_paypal_deposit_checkout,
    verify_and_capture_paypal_order,
)

MAX_HEAVY = max(1, min(4, int(os.environ.get("MAX_CONCURRENT_HEAVY_TASKS", "2"))))
HEAVY_SEMAPHORE = asyncio.Semaphore(MAX_HEAVY)
PREFETCH_SEMAPHORE = asyncio.Semaphore(1)

_PREFETCH_CACHE: "OrderedDict[str, Dict[str, Any]]" = OrderedDict()
_PREFETCH_MAX_ITEMS = 3
_PREFETCH_TTL_SEC = 120.0


def _put_prefetch(key: str, payload: Dict[str, Any]) -> None:
    now = time.time()
    expired = [k for k, v in _PREFETCH_CACHE.items() if now - v["ts"] > _PREFETCH_TTL_SEC]
    for k in expired:
        _PREFETCH_CACHE.pop(k, None)
    _PREFETCH_CACHE[key] = {"ts": now, "data": payload}
    while len(_PREFETCH_CACHE) > _PREFETCH_MAX_ITEMS:
        _PREFETCH_CACHE.popitem(last=False)


def _pop_prefetch(key: str) -> Optional[Dict[str, Any]]:
    item = _PREFETCH_CACHE.pop(key, None)
    if not item:
        return None
    if time.time() - item["ts"] > _PREFETCH_TTL_SEC:
        return None
    return item["data"]


def _make_prefetch_key(
    char_id: str,
    turn_index: int,
    choice_text: str,
    player_name: str,
    ai_mode: str = "purchase",
    api_key_override: str = "",
    affection: int = 0,
) -> str:
    key_fp = hashlib.sha256(api_key_override.strip().encode("utf-8")).hexdigest()[:8] if api_key_override.strip() else "nokey"
    raw = f"{char_id}|{turn_index}|{choice_text.strip()}|{player_name.strip()}|{ai_mode}|{key_fp}|{affection}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:24]


def _is_loopback_request(req: Request) -> bool:
    host = (req.client.host if req.client else "") or ""
    return host in ("127.0.0.1", "::1", "localhost")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    try:
        cur_nice = os.nice(0)
        if cur_nice < 10:
            os.nice(10 - cur_nice)
    except Exception:
        pass
    await asyncio.to_thread(db.bootstrap_assets_if_needed, False)
    yield
    _PREFETCH_CACHE.clear()
    await close_shared_http_client()


app = FastAPI(
    title="東方Project恋愛シミュレーター API Server",
    version="1.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _optional_user(authorization: Optional[str]) -> Optional[Dict[str, Any]]:
    if authorization and authorization.lower().startswith("bearer "):
        return db.get_user_by_session_token(authorization[7:].strip())
    return None


def _require_user(authorization: Optional[str]) -> Dict[str, Any]:
    user = _optional_user(authorization)
    if not user:
        raise HTTPException(status_code=401, detail="認証セッションが無効です。再度ログインしてください。")
    return user


def _public_base(req: Request) -> str:
    env_url = os.environ.get("RENAI_PUBLIC_BASE_URL", "").strip()
    if env_url:
        return env_url.rstrip("/")
    return f"{req.url.scheme}://{req.headers.get('host', 'localhost:8096')}"


# ==================== 1. ヘルスチェック・マスターカタログ ====================

@app.get("/api/health")
async def api_health():
    with db.get_conn() as conn:
        chars = conn.execute("SELECT COUNT(*) FROM characters").fetchone()[0]
        pers = conn.execute("SELECT COUNT(*) FROM personalities").fetchone()[0]
    return {
        "ok": True,
        "service": "touhou-renai-simulator-server",
        "asset_mode": "client_local_folder_only",
        "voice_engine": get_voice_engine_status(),
        "voice_pool": db.get_aquestalk_pool_status(),
        "paypal_mode": os.environ.get("PAYPAL_MODE", "sandbox"),
        "paypal_live_configured": bool(os.environ.get("PAYPAL_CLIENT_ID", "").strip() and os.environ.get("PAYPAL_CLIENT_SECRET", "").strip()),
        "counts": {"characters": chars, "personalities": pers},
        "server_gemini_key_configured": bool(os.environ.get("GEMINI_API_KEY", "").strip()),
        "max_concurrent_heavy": MAX_HEAVY,
    }


@app.get("/api/catalog")
async def api_catalog(authorization: Optional[str] = Header(default=None)):
    categories = await asyncio.to_thread(db.list_categories_with_characters)
    personalities = await asyncio.to_thread(db.list_personalities)
    monthly_counts: Dict[str, int] = {}
    u = _optional_user(authorization)
    if u:
        monthly_counts = db.get_monthly_purchase_counts(u["user_id"])

    deposit_options = []
    for gross in db.DEPOSIT_OPTIONS_YEN:
        fee, net = db.calc_deposit_net(gross)
        deposit_options.append({"gross_yen": gross, "fee_yen": fee, "net_yen": net})

    return {
        "asset_mode": "client_local_folder_only",
        "categories": categories,
        "personalities": personalities,
        "stage_catalog": get_master_stage_catalog(),
        "prompt_plans": db.PROMPT_PLANS,
        "auto_charge_plans": db.AUTO_CHARGE_PLANS,
        "voice_plans": db.VOICE_PLANS,
        "voice_pool": db.get_aquestalk_pool_status(),
        "deposit_options": deposit_options,
        "monthly_purchase_counts": monthly_counts,
        "bg_generation_cost_yen": db.BG_GENERATION_COST_YEN,
    }


# ==================== 2. Google OAuth 認証 & 名前NG検証 ====================

@app.post("/api/auth/start")
async def api_auth_start(request: Request):
    return create_google_auth_start(_public_base(request))


@app.get("/api/auth/poll")
async def api_auth_poll(auth_request_id: str = Query(...)):
    return get_auth_poll_status(auth_request_id)


@app.get("/api/auth/me")
async def api_auth_me(authorization: Optional[str] = Header(default=None)):
    u = _require_user(authorization)
    return {"user": u, "monthly_purchase_counts": db.get_monthly_purchase_counts(u["user_id"])}


@app.get("/api/auth/google/callback", response_class=HTMLResponse)
async def api_google_callback(code: str = Query(default=""), state: str = Query(default="")):
    ok, msg = await handle_google_oauth_callback(code=code, state=state)
    color = "#0ea5e9" if ok else "#ef4444"
    return f"""<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>認証結果</title>
    <style>body{{font-family:sans-serif;background:#4db8ff;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}}
    .box{{background:rgba(0,0,0,0.35);padding:32px 40px;border-radius:16px;text-align:center;max-width:480px}}
    button{{margin-top:18px;padding:10px 24px;border:none;border-radius:8px;background:{color};color:#fff;font-size:16px;cursor:pointer}}</style></head>
    <body><div class="box"><h2>{'認証完了' if ok else '認証エラー'}</h2><p>{msg}</p>
    <button onclick="window.close()">このタブを閉じる</button></div></body></html>"""


@app.get("/api/auth/dev_login", response_class=HTMLResponse)
async def api_dev_login_page(state: str = Query(...)):
    return f"""<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>Googleアカウント認証 (ローカル検証対応)</title>
    <style>body{{font-family:sans-serif;background:#4db8ff;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}}
    .card{{background:#fff;color:#1e293b;padding:32px;border-radius:16px;box-shadow:0 12px 32px rgba(0,0,0,.2);width:380px}}
    input{{width:100%;padding:10px;margin:8px 0 16px;border:1px solid #cbd5e1;border-radius:8px;box-sizing:border-box}}
    button{{width:100%;padding:12px;background:#0284c7;color:#fff;border:none;border-radius:8px;font-size:16px;font-weight:bold;cursor:pointer}}</style></head>
    <body><div class="card"><h3>アカウント認証（課金管理紐付け）</h3>
    <p style="font-size:13px;color:#475569">ローカルテストまたはGoogleリダイレクト未登録環境用の即時ログイン画面です。</p>
    <form method="post" action="/api/auth/dev_login_submit">
      <input type="hidden" name="state" value="{state}">
      <label>メールアドレス</label><input type="email" name="email" value="player@local.example" required>
      <label>表示名</label><input type="text" name="name" value="Player" required>
      <button type="submit">このアカウントで認証完了</button>
    </form></div></body></html>"""


@app.post("/api/auth/dev_login_submit", response_class=HTMLResponse)
async def api_dev_login_submit(request: Request):
    raw_body = (await request.body()).decode("utf-8", errors="replace")
    form = {k: v[0] for k, v in urllib.parse.parse_qs(raw_body).items()}
    state = str(form.get("state", ""))
    email = str(form.get("email", "player@local.test"))
    name = str(form.get("name", "Player"))
    ok, msg = complete_dev_login(state=state, email=email, name=name)
    return f"""<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>認証完了</title></head>
    <body style="font-family:sans-serif;background:#4db8ff;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
    <div style="background:rgba(0,0,0,.35);padding:32px;border-radius:16px;text-align:center">
    <h2>{'認証完了' if ok else 'エラー'}</h2><p>{msg}</p>
    <script>setTimeout(()=>window.close(), 1200);</script></div></body></html>"""


class ValidateNameReq(BaseModel):
    player_name: str
    player_kana: str


@app.post("/api/validate_player")
async def api_validate_player(body: ValidateNameReq):
    ok, msg = validate_player_name_and_kana(body.player_name, body.player_kana)
    return {"ok": ok, "message": msg}


# ==================== 3. デポジット・プロンプト購入・PayPal決済 ====================

class CreateCheckoutReq(BaseModel):
    gross_yen: int
    initial_plan_id: str = ""
    initial_voice_plan_id: str = ""
    auto_charge_plan_id: str = "none"


@app.post("/api/billing/create_checkout")
async def api_create_checkout(
    body: CreateCheckoutReq,
    request: Request,
    authorization: Optional[str] = Header(default=None),
):
    user = _require_user(authorization)
    try:
        order = await start_paypal_deposit_checkout(
            user_id=user["user_id"],
            gross_yen=body.gross_yen,
            initial_plan_id=body.initial_plan_id,
            auto_charge_plan_id=body.auto_charge_plan_id,
            public_base_url=_public_base(request),
            initial_voice_plan_id=body.initial_voice_plan_id,
        )
        return {"ok": True, "order": order}
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))


@app.get("/api/paypal/sandbox_checkout", response_class=HTMLResponse)
async def api_paypal_sandbox_page(order_id: str = Query(...)):
    order = db.get_deposit_order(order_id)
    if not order:
        return HTMLResponse("<h3>注文が見つかりません</h3>", status_code=404)
    return f"""<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>PayPal デポジット支払い (テスト決済)</title>
    <style>body{{font-family:sans-serif;background:#f1f5f9;color:#0f172a;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}}
    .card{{background:#fff;padding:32px;border-radius:16px;box-shadow:0 10px 28px rgba(0,0,0,.12);width:420px}}
    .pay-btn{{width:100%;padding:14px;background:#0070ba;color:#fff;border:none;border-radius:24px;font-size:16px;font-weight:bold;cursor:pointer;margin-top:16px}}
    .cancel-btn{{width:100%;padding:10px;background:#e2e8f0;color:#334155;border:none;border-radius:24px;font-size:14px;cursor:pointer;margin-top:8px}}</style></head>
    <body><div class="card">
      <h2 style="color:#003087;margin-top:0">PayPal 決済シミュレーター</h2>
      <p>注文ID: <code>{order['order_id']}</code></p>
      <p>お支払い額: <strong>¥{order['gross_yen']:,}</strong></p>
      <p style="font-size:13px;color:#64748b">決済手数料差引後の追加デポジット残高: ¥{order['net_yen']:,}<br>
      ※ 本番運用時は .env に PAYPAL_CLIENT_ID / SECRET を設定すると公式 PayPal 決済画面へ遷移します。</p>
      <form method="post" action="/api/paypal/sandbox_approve">
        <input type="hidden" name="order_id" value="{order['order_id']}">
        <button class="pay-btn" type="submit">PayPalで支払いを完了する (¥{order['gross_yen']:,})</button>
      </form>
      <button class="cancel-btn" onclick="window.close()">キャンセルしてゲームに戻る</button>
    </div></body></html>"""


@app.post("/api/paypal/sandbox_approve", response_class=HTMLResponse)
async def api_paypal_sandbox_approve(request: Request):
    raw_body = (await request.body()).decode("utf-8", errors="replace")
    form = {k: v[0] for k, v in urllib.parse.parse_qs(raw_body).items()}
    order_id = str(form.get("order_id", ""))
    with db._DB_WRITE_LOCK, db.get_conn() as conn:
        conn.execute("UPDATE deposit_orders SET status = 'APPROVED_SIM' WHERE order_id = ? AND status = 'PENDING'", (order_id,))
        conn.commit()
    return """<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>支払い承認完了</title></head>
    <body style="font-family:sans-serif;background:#4db8ff;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
    <div style="background:rgba(0,0,0,.35);padding:32px;border-radius:16px;text-align:center">
      <h2>PayPal支払いが承認されました</h2>
      <p>ゲームのウィンドウに戻ると自動で「支払いを確認中…」から進行します。</p>
      <script>setTimeout(()=>window.close(), 1200);</script>
    </div></body></html>"""


@app.get("/api/paypal/return", response_class=HTMLResponse)
async def api_paypal_return(order_id: str = Query(...)):
    return f"""<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>PayPal 完了</title></head>
    <body style="font-family:sans-serif;background:#4db8ff;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
    <div style="background:rgba(0,0,0,.35);padding:32px;border-radius:16px;text-align:center">
      <h2>PayPal支払い手続きが完了しました</h2><p>ゲームのウィンドウへ戻ると自動的に残高へ反映されます（注文: {order_id}）。</p>
      <script>setTimeout(()=>window.close(), 1500);</script>
    </div></body></html>"""


@app.get("/api/paypal/cancel", response_class=HTMLResponse)
async def api_paypal_cancel(order_id: str = Query(default="")):
    if order_id:
        with db._DB_WRITE_LOCK, db.get_conn() as conn:
            conn.execute("UPDATE deposit_orders SET status = 'CANCELED' WHERE order_id = ? AND status = 'PENDING'", (order_id,))
            conn.commit()
    return """<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>PayPal キャンセル</title></head>
    <body style="font-family:sans-serif;background:#4db8ff;color:#fff;display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
    <div style="background:rgba(0,0,0,.35);padding:32px;border-radius:16px;text-align:center">
      <h2>お支払いをキャンセルしました</h2><p>ゲームの購入確認画面に戻って内容を修正できます（次回起動時も購入確認から再開可能です）。</p>
      <script>setTimeout(()=>window.close(), 1800);</script>
    </div></body></html>"""


class VerifyOrderReq(BaseModel):
    order_id: str


@app.post("/api/billing/verify_order")
async def api_verify_order(body: VerifyOrderReq, authorization: Optional[str] = Header(default=None)):
    user = _require_user(authorization)
    order = db.get_deposit_order(body.order_id)
    if not order or order["user_id"] != user["user_id"]:
        raise HTTPException(status_code=404, detail="該当する注文が見つかりません。")
    try:
        res = await verify_and_capture_paypal_order(body.order_id)
        return {"ok": True, "voice_pool": db.get_aquestalk_pool_status(), **res}
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))


class PurchasePromptReq(BaseModel):
    plan_id: str
    auto_charge_plan_id: Optional[str] = None


@app.post("/api/billing/purchase_prompts")
async def api_purchase_prompts(body: PurchasePromptReq, authorization: Optional[str] = Header(default=None)):
    user = _require_user(authorization)
    try:
        updated = db.purchase_prompt_from_deposit(user["user_id"], body.plan_id, body.auto_charge_plan_id)
        return {"ok": True, "user": updated, "monthly_purchase_counts": db.get_monthly_purchase_counts(user["user_id"])}
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))


class PurchaseVoicePlanReq(BaseModel):
    voice_plan_id: str


@app.post("/api/billing/purchase_voice_plan")
async def api_purchase_voice_plan(body: PurchaseVoicePlanReq, authorization: Optional[str] = Header(default=None)):
    user = _require_user(authorization)
    try:
        res = db.purchase_voice_plan_from_deposit(user["user_id"], body.voice_plan_id)
        return {"ok": True, **res}
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))


# ==================== 4. ゲーム進行・インメモリ音声合成・選択肢先読み ====================

class StartGameReq(BaseModel):
    char_id: str
    player_name: str
    player_kana: str
    player_gender: str = Field(default="M", pattern="^(M|W)$")
    ai_mode: str = Field(default="purchase", pattern="^(purchase|apikey)$")
    voice_enabled: bool = True
    user_gemini_api_key: str = ""
    available_backgrounds: List[Dict[str, Any]] = Field(default_factory=list)
    available_sound_effects: List[Dict[str, Any]] = Field(default_factory=list)


async def _schedule_choices_prefetch(
    char_info: Dict[str, Any],
    player_name: str,
    player_kana: str,
    player_gender: str,
    next_turn_index: int,
    choices: List[str],
    history: List[Dict[str, Any]],
    affection: int,
    active_personality_ids: List[int],
    bg_id: str,
    available_backgrounds: List[Dict[str, Any]],
    available_sound_effects: List[Dict[str, Any]],
    api_key_override: str,
    ai_mode: str = "purchase",
    personality_mode: str = "auto",
    pinned_personality_ids: Optional[List[int]] = None,
    custom_personality_note: str = "",
) -> None:
    # 省CPU・省メモリ・APIクォータ節約のためデフォルトは false（明示有効化時のみテキスト先読み・音声WAVは選択時にオンデマンド合成）
    if os.environ.get("ENABLE_CHOICE_PREFETCH", "false").lower() not in ("1", "true", "yes"):
        return
    for choice_txt in choices[:3]:
        await asyncio.sleep(0.45)
        key = _make_prefetch_key(
            char_info["char_id"], next_turn_index, choice_txt, player_name,
            ai_mode=ai_mode, api_key_override=api_key_override, affection=affection,
        )
        if key in _PREFETCH_CACHE:
            continue
        async with PREFETCH_SEMAPHORE:
            try:
                turn_data = await generate_dialogue_turn(
                    char_id=char_info["char_id"],
                    player_name=player_name,
                    player_kana=player_kana,
                    player_gender=player_gender,
                    turn_index=next_turn_index,
                    selected_choice=choice_txt,
                    history=history,
                    current_affection=affection,
                    active_personality_ids=active_personality_ids,
                    current_bg_id=bg_id,
                    available_backgrounds=available_backgrounds,
                    available_sound_effects=available_sound_effects,
                    personality_mode=personality_mode,
                    pinned_personality_ids=pinned_personality_ids,
                    custom_personality_note=custom_personality_note,
                    api_key_override=api_key_override,
                )
                turn_data.pop("_pre_synthesized_voice", None)
                _put_prefetch(key, turn_data)
            except Exception:
                break


@app.post("/api/game/start")
async def api_game_start(body: StartGameReq, request: Request, authorization: Optional[str] = Header(default=None)):
    ok, msg = validate_player_name_and_kana(body.player_name, body.player_kana)
    if not ok:
        raise HTTPException(status_code=400, detail=msg)

    char_info = db.get_character(body.char_id)
    if not char_info:
        raise HTTPException(status_code=404, detail="キャラクターが見つかりません。")

    user_obj = _optional_user(authorization)
    if body.ai_mode == "purchase":
        user_obj = _require_user(authorization)
        try:
            user_obj = db.consume_one_prompt(user_obj["user_id"], reason="initial_prologue")
        except ValueError as ve:
            raise HTTPException(status_code=402, detail=str(ve))

    is_local = _is_loopback_request(request)
    voice_entitlement = {"allowed": False, "source": "disabled"}
    if body.voice_enabled:
        voice_entitlement = db.check_and_consume_voice_entitlement(
            user_obj["user_id"] if user_obj else None, consume=True, is_local_client=is_local
        )
        if voice_entitlement.get("user"):
            user_obj = voice_entitlement["user"]

    async with HEAVY_SEMAPHORE:
        prologue = build_canon_prologue(
            char_info=char_info,
            player_name=body.player_name,
            player_kana=body.player_kana,
            player_gender=body.player_gender,
            available_backgrounds=body.available_backgrounds,
            available_sound_effects=body.available_sound_effects,
        )
        if body.voice_enabled and voice_entitlement.get("allowed"):
            wav_bytes, clean_koe, v_mode = await asyncio.to_thread(
                synthesize_aquestalk1_in_memory,
                prologue["aquestalk_koe"],
                prologue["dialogue"],
                char_info["aq1_voice"],
                char_info["aq1_spd"],
                char_info["aq1_fsc"],
                char_info["aq1_vol"],
                char_info["char_id"],
                char_info["name"],
            )
            prologue["aquestalk_koe"] = clean_koe
            prologue["voice_engine_mode"] = v_mode
            prologue["audio_wav_base64"] = base64.b64encode(wav_bytes).decode("ascii")
        else:
            prologue["audio_wav_base64"] = ""
        prologue["voice_entitlement"] = {k: v for k, v in voice_entitlement.items() if k != "user"}

    bg_id = prologue["background"]["bg_id"] if prologue.get("background") else ""
    eff_api_key = body.user_gemini_api_key if body.ai_mode == "apikey" else ""
    asyncio.create_task(
        _schedule_choices_prefetch(
            char_info=char_info,
            player_name=body.player_name,
            player_kana=body.player_kana,
            player_gender=body.player_gender,
            next_turn_index=1,
            choices=prologue["choices"],
            history=[{"narration": prologue["narration"], "dialogue": prologue["dialogue"]}],
            affection=prologue["affection"],
            active_personality_ids=[],
            bg_id=bg_id,
            available_backgrounds=body.available_backgrounds,
            available_sound_effects=body.available_sound_effects,
            api_key_override=eff_api_key,
            ai_mode=body.ai_mode,
        )
    )

    return {"ok": True, "scene": prologue, "user": user_obj, "voice_pool": db.get_aquestalk_pool_status()}


class GameTurnReq(BaseModel):
    char_id: str
    player_name: str
    player_kana: str
    player_gender: str = Field(default="M", pattern="^(M|W)$")
    turn_index: int = Field(ge=1)
    selected_choice: str
    is_free_input: bool = False
    history: List[Dict[str, Any]] = Field(default_factory=list)
    current_affection: int = Field(default=5, ge=0, le=100)
    active_personality_ids: List[int] = Field(default_factory=list)
    personality_mode: str = Field(default="auto", pattern="^(auto|hybrid|locked)$")
    pinned_personality_ids: List[int] = Field(default_factory=list)
    custom_personality_note: str = ""
    current_bg_id: str = ""
    allow_paid_bg_generation: bool = False
    auto_bg_generation: bool = True
    ai_mode: str = Field(default="purchase", pattern="^(purchase|apikey)$")
    voice_enabled: bool = True
    user_gemini_api_key: str = ""
    available_backgrounds: List[Dict[str, Any]] = Field(default_factory=list)
    available_sound_effects: List[Dict[str, Any]] = Field(default_factory=list)


@app.post("/api/game/turn")
async def api_game_turn(body: GameTurnReq, request: Request, authorization: Optional[str] = Header(default=None)):
    # 自由入力は Gemini API キー利用モード時のみ許可
    if body.is_free_input and (body.ai_mode != "apikey" or not body.user_gemini_api_key.strip()):
        raise HTTPException(
            status_code=403,
            detail="自由入力での会話は、ご自身のGemini APIキーを指定して利用している場合のみ使用できます。",
        )

    char_info = db.get_character(body.char_id)
    if not char_info:
        raise HTTPException(status_code=404, detail="キャラクターが見つかりません。")

    user_obj = _optional_user(authorization)
    if body.ai_mode == "purchase":
        user_obj = _require_user(authorization)
        try:
            user_obj = db.consume_one_prompt(user_obj["user_id"], reason=f"turn_{body.turn_index}")
        except ValueError as ve:
            raise HTTPException(status_code=402, detail=str(ve))

    is_local = _is_loopback_request(request)
    voice_entitlement = {"allowed": False, "source": "disabled"}
    if body.voice_enabled:
        voice_entitlement = db.check_and_consume_voice_entitlement(
            user_obj["user_id"] if user_obj else None, consume=True, is_local_client=is_local
        )
        if voice_entitlement.get("user"):
            user_obj = voice_entitlement["user"]

    eff_api_key = body.user_gemini_api_key if body.ai_mode == "apikey" else ""
    pf_key = _make_prefetch_key(
        body.char_id, body.turn_index, body.selected_choice, body.player_name,
        ai_mode=body.ai_mode, api_key_override=eff_api_key, affection=body.current_affection,
    )
    cached_turn = _pop_prefetch(pf_key) if (body.personality_mode == "auto" and not body.custom_personality_note) else None

    if cached_turn is not None:
        turn_data = cached_turn
        turn_data["from_prefetch_cache"] = True
        if not (body.voice_enabled and voice_entitlement.get("allowed")):
            turn_data["audio_wav_base64"] = ""
        elif not turn_data.get("audio_wav_base64"):
            async with HEAVY_SEMAPHORE:
                wav_bytes, clean_koe, v_mode = await asyncio.to_thread(
                    synthesize_aquestalk1_in_memory,
                    turn_data["aquestalk_koe"],
                    turn_data["dialogue"],
                    char_info["aq1_voice"],
                    char_info["aq1_spd"],
                    char_info["aq1_fsc"],
                    char_info["aq1_vol"],
                    char_info["char_id"],
                    char_info["name"],
                    int(turn_data.get("serif_spd_delta", 0) or 0),
                    int(turn_data.get("serif_fsc_delta", 0) or 0),
                )
                turn_data["aquestalk_koe"] = clean_koe
                turn_data["voice_engine_mode"] = v_mode
                turn_data["audio_wav_base64"] = base64.b64encode(wav_bytes).decode("ascii")
        turn_data["voice_entitlement"] = {k: v for k, v in voice_entitlement.items() if k != "user"}
    else:
        async with HEAVY_SEMAPHORE:
            try:
                turn_data = await generate_dialogue_turn(
                    char_id=body.char_id,
                    player_name=body.player_name,
                    player_kana=body.player_kana,
                    player_gender=body.player_gender,
                    turn_index=body.turn_index,
                    selected_choice=body.selected_choice,
                    history=body.history,
                    current_affection=body.current_affection,
                    active_personality_ids=body.active_personality_ids,
                    current_bg_id=body.current_bg_id,
                    available_backgrounds=body.available_backgrounds,
                    available_sound_effects=body.available_sound_effects,
                    personality_mode=body.personality_mode,
                    pinned_personality_ids=body.pinned_personality_ids,
                    custom_personality_note=body.custom_personality_note,
                    api_key_override=eff_api_key,
                )
            except Exception as exc:
                raise HTTPException(status_code=502, detail=str(exc))

            should_gen_bg = bool(turn_data.get("needs_ai_bg_generation")) and bool(turn_data.get("suggest_new_bg_prompt"))
            allow_bg_now = (
                (body.ai_mode == "apikey" and body.auto_bg_generation and bool(eff_api_key))
                or (body.ai_mode == "purchase" and body.allow_paid_bg_generation)
            )
            if should_gen_bg and allow_bg_now:
                can_gen = True
                if body.ai_mode == "purchase" and user_obj:
                    try:
                        user_obj = db.charge_background_generation(user_obj["user_id"], turn_data["suggest_new_bg_prompt"][:40])
                    except ValueError:
                        can_gen = False
                if can_gen:
                    scene_lbl = turn_data.get("background", {}).get("keyword") or f"{char_info['name']}との情景"
                    bg_meta, webp_b64 = await generate_new_background_image_in_memory(
                        scene_title=scene_lbl,
                        prompt_en=turn_data["suggest_new_bg_prompt"],
                        time_of_day=turn_data.get("bg_time_of_day", "day"),
                        dialogue_context=f"{turn_data.get('narration', '')} {turn_data.get('dialogue', '')}",
                        api_key_override=eff_api_key,
                    )
                    turn_data["background"] = bg_meta
                    turn_data["generated_bg_webp_base64"] = webp_b64

            pre_v = turn_data.pop("_pre_synthesized_voice", None)
            if body.voice_enabled and voice_entitlement.get("allowed"):
                if pre_v is not None:
                    wav_bytes, clean_koe, v_mode = pre_v
                else:
                    wav_bytes, clean_koe, v_mode = await asyncio.to_thread(
                        synthesize_aquestalk1_in_memory,
                        turn_data["aquestalk_koe"],
                        turn_data["dialogue"],
                        char_info["aq1_voice"],
                        char_info["aq1_spd"],
                        char_info["aq1_fsc"],
                        char_info["aq1_vol"],
                        char_info["char_id"],
                        char_info["name"],
                        int(turn_data.get("serif_spd_delta", 0) or 0),
                        int(turn_data.get("serif_fsc_delta", 0) or 0),
                    )
                turn_data["aquestalk_koe"] = clean_koe
                turn_data["voice_engine_mode"] = v_mode
                turn_data["audio_wav_base64"] = base64.b64encode(wav_bytes).decode("ascii")
            else:
                turn_data["audio_wav_base64"] = ""
            turn_data["voice_entitlement"] = {k: v for k, v in voice_entitlement.items() if k != "user"}
            turn_data["from_prefetch_cache"] = False

    if not turn_data.get("is_wedding_goal") and turn_data.get("choices"):
        next_hist = list(body.history[-5:]) + [
            {
                "player_choice": body.selected_choice,
                "narration": turn_data["narration"],
                "dialogue": turn_data["dialogue"],
                "personality_names": turn_data.get("active_personality_names", []),
            }
        ]
        bg_id = turn_data["background"]["bg_id"] if turn_data.get("background") else body.current_bg_id
        asyncio.create_task(
            _schedule_choices_prefetch(
                char_info=char_info,
                player_name=body.player_name,
                player_kana=body.player_kana,
                player_gender=body.player_gender,
                next_turn_index=body.turn_index + 1,
                choices=turn_data["choices"],
                history=next_hist,
                affection=turn_data["affection"],
                active_personality_ids=turn_data["active_personality_ids"],
                bg_id=bg_id,
                available_backgrounds=body.available_backgrounds,
                available_sound_effects=body.available_sound_effects,
                api_key_override=eff_api_key,
                ai_mode=body.ai_mode,
                personality_mode=body.personality_mode,
                pinned_personality_ids=body.pinned_personality_ids,
                custom_personality_note=body.custom_personality_note,
            )
        )

    return {"ok": True, "scene": turn_data, "user": user_obj, "voice_pool": db.get_aquestalk_pool_status()}


class GenerateBgReq(BaseModel):
    scene_title: str
    prompt_en: str = ""
    time_of_day: str = "day"
    dialogue_context: str = ""
    ai_mode: str = "purchase"
    user_gemini_api_key: str = ""


@app.post("/api/game/generate_background")
async def api_generate_bg(body: GenerateBgReq, authorization: Optional[str] = Header(default=None)):
    user_obj = None
    if body.ai_mode == "purchase":
        user_obj = _require_user(authorization)
        try:
            user_obj = db.charge_background_generation(user_obj["user_id"], body.scene_title)
        except ValueError as ve:
            raise HTTPException(status_code=402, detail=str(ve))

    async with HEAVY_SEMAPHORE:
        bg_meta, webp_b64 = await generate_new_background_image_in_memory(
            scene_title=body.scene_title,
            prompt_en=body.prompt_en,
            time_of_day=body.time_of_day,
            dialogue_context=body.dialogue_context,
            api_key_override=body.user_gemini_api_key if body.ai_mode == "apikey" else "",
        )
    return {"ok": True, "background": bg_meta, "image_webp_base64": webp_b64, "user": user_obj}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("RENAI_PORT", sys.argv[1] if len(sys.argv) > 1 else "8096"))
    host = os.environ.get("RENAI_HOST", "0.0.0.0")
    uvicorn.run(app, host=host, port=port, workers=1, access_log=False)
