#!/usr/bin/env python3
"""
『東方Project恋愛シミュレーター』単体即実行用エンジン＆初期スターターSVGリソース生成器 (standalone_engine.py)
目的:
  - GitHub からダウンロードした利用者が `pip install` や外部サーバー構築なし（Python 3 標準ライブラリのみ）で
    即座に起動・プレイできるよう、スタンドアロン Gemini API 対話・演出・16:9背景生成・初期ベクター素材を提供する。
  - AquesTalk ライブラリ本体・ライセンスキー・外部著作物画像は一切含まないクリーン実装。
"""

import os
import re
import json
import html
import uuid
import base64
import urllib.request
import urllib.error
from typing import Any, Dict, List, Optional, Tuple

CLIENT_DIR = os.path.abspath(os.path.dirname(__file__))
CATALOG_JSON = os.path.join(CLIENT_DIR, "data", "standalone_catalog.json")
GEMINI_API_BASE = "https://generativelanguage.googleapis.com/v1beta"

_CATALOG_CACHE: Optional[Dict[str, Any]] = None


def load_standalone_catalog() -> Dict[str, Any]:
    global _CATALOG_CACHE
    if _CATALOG_CACHE is not None:
        return _CATALOG_CACHE
    if os.path.isfile(CATALOG_JSON):
        with open(CATALOG_JSON, "r", encoding="utf-8") as f:
            _CATALOG_CACHE = json.load(f)
            return _CATALOG_CACHE
    _CATALOG_CACHE = {"categories": [], "personalities": [], "stage_catalog": {}}
    return _CATALOG_CACHE


def find_char_in_catalog(char_id: str) -> Dict[str, Any]:
    cat = load_standalone_catalog()
    for grp in cat.get("categories", []):
        for ch in grp.get("characters", []):
            if ch.get("char_id") == char_id:
                return ch
    return {
        "char_id": char_id or "reimu",
        "name": "博麗霊夢",
        "kana": "はくれいれいむ",
        "category": "主人公",
        "default_bg_keyword": "博麗神社",
        "canon_profile": "博麗神社の巫女。裏表がなくマイペースだが面倒見が良い。",
    }


# ==================== 1. 未配置環境でも即遊べるオリジナルSVGスターター立ち絵・背景生成 ====================

def _char_theme_colors(char_name: str) -> Tuple[str, str, str]:
    nm = char_name or ""
    if "霊夢" in nm:
        return ("#dc2626", "#fef2f2", "#312e81")
    if "魔理沙" in nm:
        return ("#1e293b", "#facc15", "#fef08a")
    if "フラン" in nm:
        return ("#be123c", "#fde047", "#fda4af")
    if "レミリア" in nm:
        return ("#fb7185", "#93c5fd", "#fda4af")
    if "咲夜" in nm:
        return ("#1d4ed8", "#e2e8f0", "#cbd5e1")
    if "妖夢" in nm:
        return ("#059669", "#f1f5f9", "#e2e8f0")
    if "早苗" in nm:
        return ("#16a34a", "#dcfce7", "#4ade80")
    if "こいし" in nm:
        return ("#0d9488", "#fde047", "#6ee7b7")
    if "さとり" in nm:
        return ("#db2777", "#93c5fd", "#f9a8d4")
    if "チルノ" in nm:
        return ("#0284c7", "#bae6fd", "#38bdf8")
    # キャラ名のハッシュから固有カラーを決定
    h = sum(ord(c) for c in nm) % 360
    return (f"hsl({h}, 68%, 48%)", f"hsl({(h+45)%360}, 82%, 88%)", f"hsl({(h+15)%360}, 60%, 35%)")


def generate_starter_portrait_svg(char_name: str, emotion: str = "normal", blush: bool = False) -> bytes:
    """外部立ち絵フォルダ未配置時用のクリーンなアニメ調スターター立ち絵SVG（色変えスタジオとも完全互換）"""
    primary, accent, hair = _char_theme_colors(char_name)
    safe_name = html.escape((char_name or "ヒロイン")[:14])
    emo = (emotion or "normal").lower()

    # 表情パーツ差分
    if emo in ("smile", "blush"):
        eyes = '<path d="M212 248 Q226 234 240 248" stroke="#1e1b4b" stroke-width="5" fill="none" stroke-linecap="round"/><path d="M280 248 Q294 234 308 248" stroke="#1e1b4b" stroke-width="5" fill="none" stroke-linecap="round"/>'
        mouth = '<path d="M246 288 Q260 304 274 288" stroke="#be123c" stroke-width="4" fill="#fb7185" stroke-linecap="round"/>'
    elif emo == "angry":
        eyes = '<circle cx="226" cy="248" r="10" fill="#1e1b4b"/><circle cx="294" cy="248" r="10" fill="#1e1b4b"/><path d="M208 228 L242 238 M312 228 L278 238" stroke="#1e1b4b" stroke-width="4.5" stroke-linecap="round"/>'
        mouth = '<path d="M248 295 Q260 284 272 295" stroke="#9f1239" stroke-width="4" fill="none" stroke-linecap="round"/>'
    elif emo == "surprised":
        eyes = '<ellipse cx="226" cy="248" rx="11" ry="14" fill="#1e1b4b"/><ellipse cx="294" cy="248" rx="11" ry="14" fill="#1e1b4b"/><circle cx="222" cy="243" r="4" fill="#fff"/><circle cx="290" cy="243" r="4" fill="#fff"/>'
        mouth = '<ellipse cx="260" cy="293" rx="9" ry="11" fill="#fb7185" stroke="#9f1239" stroke-width="3"/>'
    elif emo in ("sad", "troubled"):
        eyes = '<circle cx="226" cy="250" r="10" fill="#1e1b4b"/><circle cx="294" cy="250" r="10" fill="#1e1b4b"/><path d="M208 238 L240 230 M312 238 L280 230" stroke="#1e1b4b" stroke-width="4" stroke-linecap="round"/>'
        mouth = '<path d="M249 294 Q260 288 271 294" stroke="#9f1239" stroke-width="3.5" fill="none" stroke-linecap="round"/>'
    else:
        eyes = '<ellipse cx="226" cy="248" rx="10" ry="12" fill="#1e1b4b"/><ellipse cx="294" cy="248" rx="10" ry="12" fill="#1e1b4b"/><circle cx="223" cy="243" r="3.8" fill="#fff"/><circle cx="291" cy="243" r="3.8" fill="#fff"/>'
        mouth = '<path d="M250 290 Q260 297 270 290" stroke="#9f1239" stroke-width="3.5" fill="none" stroke-linecap="round"/>'

    blush_svg = ""
    if blush or emo == "blush":
        blush_svg = '<ellipse cx="204" cy="268" rx="16" ry="8" fill="#fb7185" opacity="0.52"/><ellipse cx="316" cy="268" rx="16" ry="8" fill="#fb7185" opacity="0.52"/>'

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 900" width="520" height="900">
  <defs>
    <linearGradient id="dressG" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{primary}"/>
      <stop offset="100%" stop-color="#1e1b4b"/>
    </linearGradient>
  </defs>
  <!-- 背面リボン -->
  <path d="M180 128 L122 86 L146 168 Z" fill="{primary}" stroke="#0f172a" stroke-width="4"/>
  <path d="M340 128 L398 86 L374 168 Z" fill="{primary}" stroke="#0f172a" stroke-width="4"/>
  <!-- 後ろ髪 -->
  <path d="M168 180 Q138 380 156 560 Q260 600 364 560 Q382 380 352 180 Z" fill="{hair}" stroke="#0f172a" stroke-width="4"/>
  <!-- 衣装（上半身＋スカート） -->
  <path d="M206 334 L314 334 L388 740 Q260 778 132 740 Z" fill="url(#dressG)" stroke="#0f172a" stroke-width="4.5"/>
  <path d="M214 336 L306 336 L332 520 L188 520 Z" fill="{accent}" opacity="0.92" stroke="#0f172a" stroke-width="3.5"/>
  <!-- 胸元リボン -->
  <polygon points="260,362 224,344 232,386" fill="{primary}" stroke="#0f172a" stroke-width="3"/>
  <polygon points="260,362 296,344 288,386" fill="{primary}" stroke="#0f172a" stroke-width="3"/>
  <circle cx="260" cy="362" r="10" fill="#fde047" stroke="#0f172a" stroke-width="3"/>
  <!-- 首・顔輪郭 -->
  <rect x="242" y="302" width="36" height="40" rx="12" fill="#ffe4d6"/>
  <path d="M184 214 Q184 316 260 318 Q336 316 336 214 Q336 142 260 142 Q184 142 184 214 Z" fill="#ffe4d6" stroke="#0f172a" stroke-width="4"/>
  <!-- 前髪 -->
  <path d="M174 226 Q182 126 260 126 Q338 126 346 226 Q318 178 294 212 Q266 168 238 212 Q208 176 174 226 Z" fill="{hair}" stroke="#0f172a" stroke-width="4"/>
  {blush_svg}
  {eyes}
  {mouth}
  <!-- ネームプレート（スターター表示） -->
  <rect x="150" y="790" width="220" height="42" rx="21" fill="rgba(15,23,42,0.78)" stroke="{accent}" stroke-width="2"/>
  <text x="260" y="817" font-family="sans-serif" font-size="18" font-weight="bold" fill="#ffffff" text-anchor="middle">{safe_name}</text>
</svg>"""
    return svg.encode("utf-8")


def generate_starter_bg_svg(keyword: str = "幻想郷", time_of_day: str = "day") -> bytes:
    """外部背景未配置時用の16:9幻想郷風景スターターSVG"""
    kw = keyword or "博麗神社"
    tod = time_of_day or "day"
    if "紅魔" in kw or "館" in kw or "書斎" in kw or "部屋" in kw:
        c1, c2, hill = ("#2e1022", "#5c162e", "#1c0913")
    elif tod == "night" or "夜" in kw or "月" in kw or "星" in kw:
        c1, c2, hill = ("#090d26", "#1e2959", "#0b132b")
    elif tod == "evening" or "夕" in kw:
        c1, c2, hill = ("#7c2d12", "#fb923c", "#29150d")
    else:
        c1, c2, hill = ("#0284c7", "#bae6fd", "#14532d")

    safe_kw = html.escape(kw[:24])
    moon_or_sun = (
        '<circle cx="1020" cy="150" r="56" fill="#fef08a" opacity="0.88"/>'
        if tod in ("night", "day")
        else '<circle cx="960" cy="390" r="78" fill="#fde047" opacity="0.82"/>'
    )
    torii = (
        '<g fill="#b91c1c" opacity="0.88"><rect x="200" y="300" width="26" height="280"/><rect x="394" y="300" width="26" height="280"/><rect x="165" y="290" width="290" height="24" rx="6"/><rect x="185" y="340" width="250" height="16"/></g>'
        if ("神社" in kw or "境内" in kw or "鳥居" in kw)
        else ""
    )

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 720" width="1280" height="720">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="{c1}"/>
      <stop offset="100%" stop-color="{c2}"/>
    </linearGradient>
  </defs>
  <rect width="1280" height="720" fill="url(#sky)"/>
  {moon_or_sun}
  <path d="M0 540 Q320 410 660 510 T1280 470 L1280 720 L0 720 Z" fill="{hill}" opacity="0.65"/>
  <path d="M0 590 Q440 520 880 585 T1280 560 L1280 720 L0 720 Z" fill="#0f172a" opacity="0.78"/>
  {torii}
  <text x="32" y="692" font-family="sans-serif" font-size="16" fill="rgba(255,255,255,0.45)">Scene: {safe_kw}</text>
</svg>"""
    return svg.encode("utf-8")


# ==================== 2. スタンドアロン Gemini API 呼び出し（標準ライブラリ urllib のみ） ====================

def _http_post_json(url: str, payload: Dict[str, Any], headers: Optional[Dict[str, str]] = None, timeout: float = 30.0) -> Tuple[int, Dict[str, Any]]:
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=hdrs, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as he:
        try:
            err_json = json.loads(he.read().decode("utf-8", errors="replace"))
        except Exception:
            err_json = {"error": str(he)}
        return he.code, err_json
    except Exception as exc:
        return 599, {"error": str(exc)}


def standalone_generate_bg(scene_title: str, prompt_en: str, time_of_day: str, dialogue_context: str, api_key: str) -> Tuple[Dict[str, Any], str]:
    bg_id = "gen_" + uuid.uuid4().hex[:10]
    key = (api_key or "").strip()
    if key:
        full_prompt = (
            f"Masterpiece 16:9 anime visual novel background art, Touhou Project Gensokyo atmosphere, "
            f"strictly NO characters, NO people, NO text. Location: {scene_title}. {prompt_en}. "
            f"Time of day: {time_of_day}. Context: {dialogue_context[:140]}"
        )
        # 1. Interactions API (gemini-nano-banana-2.1)
        st, data = _http_post_json(
            f"{GEMINI_API_BASE}/interactions",
            {
                "model": "gemini-nano-banana-2.1",
                "store": False,
                "input": full_prompt,
                "response_format": {"type": "image", "aspect_ratio": "16:9", "image_size": "1K"},
            },
            headers={"x-goog-api-key": key, "Api-Revision": "2026-05-20"},
            timeout=35.0,
        )
        img_b64 = ""
        if st == 200:
            out_img = data.get("output_image") or (data.get("interaction") or {}).get("output_image")
            if isinstance(out_img, dict) and out_img.get("data"):
                img_b64 = out_img["data"]
            else:
                for step in reversed(data.get("steps") or []):
                    for c in reversed(step.get("content") or []):
                        if c.get("type") == "image" and c.get("data"):
                            img_b64 = c["data"]
                            break
                    if img_b64:
                        break
        # 2. generateContent fallback
        if not img_b64:
            for m in ("gemini-nano-banana-2.1", "gemini-3.1-flash-lite-image"):
                st2, d2 = _http_post_json(
                    f"{GEMINI_API_BASE}/models/{m}:generateContent?key={key}",
                    {
                        "contents": [{"role": "user", "parts": [{"text": full_prompt}]}],
                        "generationConfig": {"responseModalities": ["IMAGE"]},
                    },
                    timeout=35.0,
                )
                if st2 == 200:
                    parts = ((d2.get("candidates") or [{}])[0].get("content") or {}).get("parts") or []
                    for pt in parts:
                        if (pt.get("inlineData") or {}).get("data"):
                            img_b64 = pt["inlineData"]["data"]
                            break
                    if img_b64:
                        break
        if img_b64:
            return ({"bg_id": bg_id, "name": scene_title, "keyword": scene_title, "time_of_day": time_of_day, "is_generated": 1}, img_b64)

    svg_b64 = base64.b64encode(generate_starter_bg_svg(scene_title, time_of_day)).decode("ascii")
    return ({"bg_id": bg_id, "name": scene_title, "keyword": scene_title, "time_of_day": time_of_day, "is_generated": 1, "ext": "svg"}, svg_b64)


def standalone_start_scene(body: Dict[str, Any]) -> Dict[str, Any]:
    ch = find_char_in_catalog(str(body.get("char_id", "reimu")))
    pronoun = "僕" if body.get("player_gender", "M") == "M" else "私"
    pname = str(body.get("player_name") or "旅人")
    cname = ch["name"]
    bg_kw = ch.get("default_bg_keyword", "博麗神社")

    narration = f"「んっ…」{pronoun}がふと目を覚ますと、幻想的な『{bg_kw}』の景色が広がっていた。戸惑う{pronoun}の前に、{cname}が歩み寄ってくる。"
    dialogue = f"「あら、見かけない顔ね。あなた、外の世界から迷い込んだのかしら？」"
    return {
        "turn_index": 0,
        "narration": narration,
        "speaker_name": cname,
        "dialogue": dialogue,
        "aquestalk_koe": "",
        "emotion": "question",
        "prefer_blush": False,
        "background": {"bg_id": "", "name": bg_kw, "keyword": bg_kw, "time_of_day": "day"},
        "stage_direction": {
            "distance_preset": "slightly_far",
            "narration_scale": 0.86,
            "dialogue_scale": 0.98,
            "offset_x": 0.0,
            "offset_y": 0.5,
            "origin_y_pct": 60,
            "narration_motion": "slide_in_right",
            "dialogue_motion": "head_tilt",
            "transition_ms": 680,
            "screen_effect": "none",
            "bg_zoom": 1.02,
            "bg_blur_px": 0.0,
            "se_cues": [
                {"se_id": "footsteps_walk", "trigger": "narration", "delay_ms": 0, "volume": 0.7},
                {"se_id": "question_pon", "trigger": "dialogue", "delay_ms": 80, "volume": 0.65},
            ],
        },
        "choices": [
            f"「{pronoun}は{pname}です。ここはどこですか？」",
            "「君の名前を教えてくれる？」",
            "「すごく綺麗な場所だね」",
        ],
        "affection": 5,
        "relationship_stage": "出会い",
        "active_personality_ids": [],
        "active_personality_names": [],
        "personality_mode": "auto",
        "is_wedding_goal": False,
        "audio_wav_base64": "",
    }


def standalone_turn_scene(body: Dict[str, Any]) -> Dict[str, Any]:
    cat = load_standalone_catalog()
    ch = find_char_in_catalog(str(body.get("char_id", "reimu")))
    all_p = {int(p["id"]): p for p in cat.get("personalities", [])}
    api_key = str(body.get("user_gemini_api_key") or "").strip()
    choice = str(body.get("selected_choice") or "")
    turn_idx = int(body.get("turn_index", 1))
    cur_aff = int(body.get("current_affection", 5))
    prev_ids = [int(x) for x in (body.get("active_personality_ids") or []) if int(x) in all_p][:2]
    p_mode = str(body.get("personality_mode") or "auto")
    pin_ids = [int(x) for x in (body.get("pinned_personality_ids") or []) if int(x) in all_p][:2]
    custom_note = str(body.get("custom_personality_note") or "").strip()
    bgs = body.get("available_backgrounds") or []

    parsed: Optional[Dict[str, Any]] = None
    if api_key:
        bg_summary = ", ".join(f"{b.get('bg_id')}:{b.get('name')}" for b in bgs[:120]) or "ローカル背景なし(generate_ai推奨)"
        pers_summary = ", ".join(f"{pid}:{p['name']}" for pid, p in list(all_p.items())[:50])
        sys_prompt = (
            f"あなたは東方Project恋愛シミュレーターAIです。ヒロイン:{ch['name']} ({ch.get('canon_profile','')}) / "
            f"プレイヤー:{body.get('player_name','旅人')} / 現在好感度:{cur_aff}/100 / 性格モード:{p_mode} {custom_note}\n"
            f"会話内容に忠実に背景選択(bg_action: keep / select_local / generate_ai, bg_id, bg_keyword, bg_time_of_day: day/evening/night, suggest_new_bg_prompt)と、"
            f"プレゼン風の立ち絵拡大縮小・モーション・効果音(stage_direction)、および会話に応じた動的性格変化(selected_personality_ids, personality_shift_reason)をJSONのみで返してください。\n"
            f"背景候補: {bg_summary}\n性格50種: {pers_summary}"
        )
        contents = []
        for h in (body.get("history") or [])[-5:]:
            if h.get("player_choice"):
                contents.append({"role": "user", "parts": [{"text": h["player_choice"]}]})
            if h.get("dialogue"):
                contents.append({"role": "model", "parts": [{"text": f"{h.get('narration','')}\n{h['dialogue']}"}]})
        contents.append({"role": "user", "parts": [{"text": f"プレイヤー発言: 『{choice}』 JSONで応答してください: narration, dialogue, emotion(normal/smile/question/blush/angry/surprised/sad/troubled/smug/yandere), prefer_blush, bg_action, bg_id, bg_keyword, bg_time_of_day, suggest_new_bg_prompt, affection_delta, selected_personality_ids, personality_shift_reason, stage_direction(distance_preset, narration_scale, dialogue_scale, narration_motion, dialogue_motion, screen_effect, se_cues), choices(3個), is_wedding_goal"}]})

        for m in ("gemini-4-hydrogen", "gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.1-flash-lite"):
            st, resp = _http_post_json(
                f"{GEMINI_API_BASE}/models/{m}:generateContent?key={api_key}",
                {
                    "systemInstruction": {"parts": [{"text": sys_prompt}]},
                    "contents": contents,
                    "generationConfig": {"temperature": 0.82, "maxOutputTokens": 2048, "responseMimeType": "application/json"},
                },
                timeout=30.0,
            )
            if st == 200:
                try:
                    parts = ((resp.get("candidates") or [{}])[0].get("content") or {}).get("parts") or []
                    txt = [p["text"] for p in parts if isinstance(p.get("text"), str) and not p.get("thought")][-1]
                    parsed = json.loads(txt.strip().strip("`").removeprefix("json").strip())
                    break
                except Exception:
                    pass

    if not parsed:
        parsed = {
            "narration": f"『{choice}』という言葉を聞いて、{ch['name']}は少し頬を緩めて一歩近づいた。",
            "dialogue": f"「ふふ、{body.get('player_name','あなた')}と話していると退屈しないわね。次はどこへ行こうか？」",
            "emotion": "smile",
            "prefer_blush": cur_aff >= 45,
            "bg_action": "keep",
            "bg_id": str(body.get("current_bg_id") or ""),
            "bg_keyword": ch.get("default_bg_keyword", "博麗神社"),
            "bg_time_of_day": "day",
            "suggest_new_bg_prompt": "",
            "affection_delta": 12,
            "selected_personality_ids": [4, 44] if "好き" in choice or "可愛" in choice else [1, 8],
            "personality_shift_reason": "会話の距離感に合わせて態度が変化",
            "stage_direction": {
                "distance_preset": "close",
                "narration_scale": 1.04,
                "dialogue_scale": 1.18,
                "narration_motion": "step_closer",
                "dialogue_motion": "nod",
                "screen_effect": "warm_bloom",
                "se_cues": [{"se_id": "footsteps_walk", "trigger": "narration", "delay_ms": 0, "volume": 0.7}, {"se_id": "sparkle_twinkle", "trigger": "dialogue", "delay_ms": 80, "volume": 0.7}],
            },
            "choices": ["「一緒に散歩しよう」", "「もっと近くに来ていいよ」", "「君の好きな場所へ連れて行って」"],
            "is_wedding_goal": cur_aff + 12 >= 100,
        }

    delta = max(-5, min(18, int(parsed.get("affection_delta", 8))))
    new_aff = max(0, min(100, cur_aff + delta))
    is_wed = bool(parsed.get("is_wedding_goal")) or new_aff >= 100
    if is_wed:
        new_aff = 100

    ai_pids = [int(x) for x in (parsed.get("selected_personality_ids") or []) if int(x) in all_p][:2]
    if p_mode == "locked" and pin_ids:
        final_pids = pin_ids[:2]
    elif p_mode == "hybrid" and pin_ids:
        final_pids = ([pin_ids[0]] + [x for x in ai_pids if x != pin_ids[0]])[:2]
    else:
        final_pids = ai_pids or prev_ids

    stage = "結婚式" if is_wed else ("プロポーズ" if new_aff >= 90 else ("恋人" if new_aff >= 75 else ("気になる人" if new_aff >= 55 else ("友人" if new_aff >= 35 else ("知人" if new_aff >= 15 else "出会い")))))
    sd = parsed.get("stage_direction") or {}
    d_scale = max(0.6, min(1.75, float(sd.get("dialogue_scale", 1.12))))
    sd.setdefault("narration_scale", max(0.6, round(d_scale - 0.1, 2)))
    sd["dialogue_scale"] = d_scale
    sd.setdefault("origin_y_pct", 23 if d_scale > 1.15 else 55)
    sd.setdefault("offset_y", 4.5 if d_scale > 1.15 else 0.0)

    scene_out: Dict[str, Any] = {
        "turn_index": turn_idx,
        "narration": parsed.get("narration", ""),
        "speaker_name": ch["name"],
        "dialogue": parsed.get("dialogue", ""),
        "aquestalk_koe": "",
        "emotion": parsed.get("emotion", "smile"),
        "prefer_blush": bool(parsed.get("prefer_blush")) or new_aff >= 65,
        "background": {
            "bg_id": parsed.get("bg_id", "") or str(body.get("current_bg_id") or ""),
            "name": parsed.get("bg_keyword", ch.get("default_bg_keyword", "幻想郷")),
            "keyword": parsed.get("bg_keyword", ch.get("default_bg_keyword", "幻想郷")),
            "time_of_day": parsed.get("bg_time_of_day", "day"),
        },
        "bg_action": parsed.get("bg_action", "select_local"),
        "bg_time_of_day": parsed.get("bg_time_of_day", "day"),
        "suggest_new_bg_prompt": parsed.get("suggest_new_bg_prompt", ""),
        "stage_direction": sd,
        "choices": [] if is_wed else (parsed.get("choices") or ["「そうだね」", "「もっと話そう」", "「手を繋いでもいい？」"])[:3],
        "affection": new_aff,
        "affection_delta": delta,
        "relationship_stage": stage,
        "active_personality_ids": final_pids,
        "active_personality_names": [all_p[pid]["name"] for pid in final_pids if pid in all_p],
        "personality_mode": p_mode,
        "personality_changed": final_pids != prev_ids,
        "personality_shift_reason": str(parsed.get("personality_shift_reason") or ""),
        "is_wedding_goal": is_wed,
        "audio_wav_base64": "",
    }

    if api_key and body.get("auto_bg_generation", True) and parsed.get("bg_action") == "generate_ai" and parsed.get("suggest_new_bg_prompt"):
        bg_meta, b64_img = standalone_generate_bg(
            scene_title=scene_out["background"]["keyword"],
            prompt_en=parsed["suggest_new_bg_prompt"],
            time_of_day=scene_out["bg_time_of_day"],
            dialogue_context=f"{scene_out['narration']} {scene_out['dialogue']}",
            api_key=api_key,
        )
        scene_out["background"] = bg_meta
        if not bg_meta.get("ext") == "svg":
            scene_out["generated_bg_webp_base64"] = b64_img

    return scene_out
