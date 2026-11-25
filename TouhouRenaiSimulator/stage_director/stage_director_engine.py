#!/usr/bin/env python3
"""
『キャラステージ演出メーカー』コア演出エンジン (stage_director_engine.py)
設計方針:
  - Python標準ライブラリのみで動作（外部依存ゼロ・追加メモリ約0.2MB未満・常駐デーモン不要）
  - 『東方Project恋愛シミュレーター』のサーバー (gemini_service.py) からインプロセスで直接import可能
  - 一般的なプレゼンテーションソフト（Keynote / PowerPoint のマジックムーブ・ビルド演出）のように、
    キャラクター立ち絵の「拡大・縮小（距離感）」「位置オフセット」「登場・強調アニメーション」「画面効果」
    「効果音（内蔵シンセSE 20種 ＋ 利用者ローカル効果音ファイル）のタイムライン再生」を構造化制御する
"""

import os
import re
import json
import unicodedata
from typing import Any, Dict, List, Optional, Tuple

STUDIO_DIR = os.path.abspath(os.path.dirname(__file__))
DATA_DIR = os.path.join(STUDIO_DIR, "data")
CUSTOM_PRESETS_FILE = os.path.join(DATA_DIR, "custom_stage_presets.json")

# ==================== 1. 距離・拡大縮小プリセット（Keynote マジックムーブ風カメラワーク） ====================
# はるか式立ち絵（全身〜膝上・顔中心は上端から約22〜26%付近）で拡大時に頭が見切れないよう、
# origin_y_pct と offset_y_vh を光学的に最適化したプリセット定義
DISTANCE_PRESETS: Dict[str, Dict[str, Any]] = {
    "far": {
        "id": "far",
        "label": "遠景（遠くにいる）",
        "scale": 0.72,
        "origin_y_pct": 86,
        "offset_y_vh": 2.0,
        "bg_zoom": 1.00,
        "bg_blur_px": 0.0,
        "desc": "離れた場所から声をかける・見送る距離感（72%縮小）",
    },
    "slightly_far": {
        "id": "slightly_far",
        "label": "やや遠め（控えめな距離）",
        "scale": 0.86,
        "origin_y_pct": 78,
        "offset_y_vh": 1.0,
        "bg_zoom": 1.01,
        "bg_blur_px": 0.0,
        "desc": "初対面や警戒中・少し距離を置いた立ち位置（86%）",
    },
    "normal": {
        "id": "normal",
        "label": "標準（通常の会話距離）",
        "scale": 1.00,
        "origin_y_pct": 55,
        "offset_y_vh": 0.0,
        "bg_zoom": 1.02,
        "bg_blur_px": 0.0,
        "desc": "自然な立ち話・日常会話の標準サイズ（100%）",
    },
    "close": {
        "id": "close",
        "label": "接近（一歩歩み寄る）",
        "scale": 1.18,
        "origin_y_pct": 26,
        "offset_y_vh": 3.5,
        "bg_zoom": 1.05,
        "bg_blur_px": 0.8,
        "desc": "親しくなって一歩近づく・袖を掴む距離感（118%拡大）",
    },
    "very_close": {
        "id": "very_close",
        "label": "急接近（顔を近づける・覗き込み）",
        "scale": 1.38,
        "origin_y_pct": 23,
        "offset_y_vh": 6.0,
        "bg_zoom": 1.08,
        "bg_blur_px": 1.8,
        "desc": "耳元で囁く・じっと瞳を見つめるアップ演出（138%拡大＋背景ボケ）",
    },
    "hug_closeup": {
        "id": "hug_closeup",
        "label": "至近距離（抱擁・ゼロ距離アップ）",
        "scale": 1.56,
        "origin_y_pct": 22,
        "offset_y_vh": 8.0,
        "bg_zoom": 1.12,
        "bg_blur_px": 2.8,
        "desc": "ぎゅっと抱きしめる・キス寸前の超至近距離（156%拡大＋背景ボケ）",
    },
}

# ==================== 2. プレゼン風アニメーションプリセット（全18種・有限回数でCPUアイドル0%） ====================
MOTION_PRESETS: Dict[str, Dict[str, Any]] = {
    "none": {"id": "none", "category": "基本", "label": "静止（トランジションのみ）", "duration_ms": 450, "desc": "拡大縮小・移動のみを滑らかに補間"},
    "slide_in_left": {"id": "slide_in_left", "category": "登場・移動", "label": "左からスライドイン", "duration_ms": 680, "desc": "画面左側からすっと歩み出て登場"},
    "slide_in_right": {"id": "slide_in_right", "category": "登場・移動", "label": "右からスライドイン", "duration_ms": 680, "desc": "画面右側からすっと歩み出て登場"},
    "fade_zoom_in": {"id": "fade_zoom_in", "category": "登場・移動", "label": "フェード＆ズーム登場", "duration_ms": 700, "desc": "奥からふわりと浮かび上がるように登場"},
    "float_in": {"id": "float_in", "category": "登場・移動", "label": "ふわりと舞い降りる", "duration_ms": 820, "desc": "幻想郷らしく宙から軽やかに着地"},
    "step_closer": {"id": "step_closer", "category": "登場・移動", "label": "歩み寄る（歩行ステップ）", "duration_ms": 720, "desc": "トコトコと上下に揺れながら距離を詰める"},
    "step_back": {"id": "step_back", "category": "登場・移動", "label": "一歩後ずさる", "duration_ms": 580, "desc": "照れや驚きで少し後ろへ下がる"},
    "nod": {"id": "nod", "category": "感情・強調", "label": "頷く（うんうん）", "duration_ms": 560, "desc": "肯定・納得して優しく縦に頷く"},
    "head_tilt": {"id": "head_tilt", "category": "感情・強調", "label": "小首をかしげる", "duration_ms": 620, "desc": "「？」と不思議そう・あざと可愛く傾く"},
    "jump_happy": {"id": "jump_happy", "category": "感情・強調", "label": "喜びジャンプ（ぴょんっ）", "duration_ms": 600, "desc": "嬉しくて弾むように跳ねる"},
    "double_bounce": {"id": "double_bounce", "category": "感情・強調", "label": "2回はずむ（ワクワク）", "duration_ms": 680, "desc": "楽しそうにトントンと2回弾む"},
    "tremble": {"id": "tremble", "category": "感情・強調", "label": "プルプル震える（照れ・涙・緊張）", "duration_ms": 700, "desc": "羞恥や感極まりで小刻みに震える"},
    "shake_angry": {"id": "shake_angry", "category": "感情・強調", "label": "ムッと揺れる（怒り・ツッコミ）", "duration_ms": 540, "desc": "怒りや焦りで左右に強く揺れる"},
    "sway_gentle": {"id": "sway_gentle", "category": "感情・強調", "label": "ゆったり揺れる（甘え・リラックス）", "duration_ms": 950, "desc": "安心しきって左右にふわりと体を揺らす"},
    "lean_in": {"id": "lean_in", "category": "親密・特殊", "label": "グッと身を乗り出す（覗き込み）", "duration_ms": 680, "desc": "いたずらっぽく、または甘えて顔を近づける"},
    "hug_surge": {"id": "hug_surge", "category": "親密・特殊", "label": "ぎゅっと抱きつく", "duration_ms": 760, "desc": "一気に胸元へ飛び込んで密着する"},
    "surprised_jolt": {"id": "surprised_jolt", "category": "感情・強調", "label": "ビクッと跳ねる（驚き）", "duration_ms": 480, "desc": "不意を突かれてビクッと反応する"},
    "spin_turn": {"id": "spin_turn", "category": "親密・特殊", "label": "くるっと華麗にターン", "duration_ms": 780, "desc": "プレゼンのスピン演出のように一回転して見せる"},
}

# ==================== 3. 軽量ステージ画面エフェクト（GPU合成のみ） ====================
SCREEN_EFFECTS: Dict[str, Dict[str, str]] = {
    "none": {"id": "none", "label": "なし（標準）"},
    "warm_bloom": {"id": "warm_bloom", "label": "暖色ブルーム（甘い雰囲気・夕暮れ・親密）"},
    "sparkle_glow": {"id": "sparkle_glow", "label": "ときめき発光（好感度アップ・笑顔・祝福）"},
    "heartbeat_pulse": {"id": "heartbeat_pulse", "label": "鼓動ビネット（ドキドキ・急接近・告白）"},
    "screen_shake": {"id": "screen_shake", "label": "画面シェイク（衝撃・ツッコミ・大驚き）"},
    "dark_vignette": {"id": "dark_vignette", "label": "シリアス・ヤンデレ暗転縁取り（独占欲・緊迫）"},
}

# ==================== 4. 内蔵プロシージャル効果音（Web Audio API リアルタイム合成・メモリ0KB） ====================
BUILTIN_SOUND_EFFECTS: List[Dict[str, str]] = [
    {"se_id": "footsteps_walk", "name": "歩み寄る足音（コツコツ）", "category": "移動・日常", "keywords": "足音,歩く,近づく,歩み寄る,登場"},
    {"se_id": "footsteps_run", "name": "駆け寄る足音（タタタッ）", "category": "移動・日常", "keywords": "走る,駆け寄る,急ぐ"},
    {"se_id": "cloth_rustle", "name": "衣擦れ・袖を掴む音（サッ）", "category": "距離・スキンシップ", "keywords": "衣擦れ,服,袖,近づく,隣に座る,手を繋ぐ"},
    {"se_id": "hug_embrace", "name": "抱きしめる音（ギュッ）", "category": "距離・スキンシップ", "keywords": "ハグ,抱きつく,抱きしめる,ぎゅー,密着"},
    {"se_id": "heartbeat", "name": "心臓の鼓動（ドキッ…ドキッ…）", "category": "感情・恋愛", "keywords": "鼓動,ドキッ,胸が高鳴る,緊張,見つめる"},
    {"se_id": "heartbeat_fast", "name": "早鐘の鼓動（ドキドキッ！）", "category": "感情・恋愛", "keywords": "ドキドキ,急接近,告白,キス,限界"},
    {"se_id": "sparkle_twinkle", "name": "きらめき・好感度UP（キラリーン✨）", "category": "感情・恋愛", "keywords": "きらめき,笑顔,嬉しい,ときめき,好印象"},
    {"se_id": "blush_pop", "name": "赤面・照れポップ（ポッ…）", "category": "感情・恋愛", "keywords": "赤面,照れる,頬を染める,恥ずかしい"},
    {"se_id": "question_pon", "name": "疑問・小首かしげ（ぽんっ？）", "category": "感情・リアクション", "keywords": "疑問,はてな,きょとん,首をかしげる"},
    {"se_id": "surprised_biku", "name": "驚き・ひらめき（ビクッ！／ピコーン）", "category": "感情・リアクション", "keywords": "驚く,びっくり,ハッとする,目を丸くする"},
    {"se_id": "angry_boom", "name": "ムッ・怒りアクセント（ドンッ）", "category": "感情・リアクション", "keywords": "怒る,ムッとする,睨む,不満"},
    {"se_id": "slap_tsukkomi", "name": "軽いツッコミ・手拍子（パシッ！）", "category": "感情・リアクション", "keywords": "ツッコミ,叩く,パシッ,手を叩く"},
    {"se_id": "dark_yandere", "name": "不穏・独占欲ゾクッ（低音残響）", "category": "シリアス・特殊", "keywords": "ヤンデレ,独占,逃がさない,狂気,ゾクッ,影"},
    {"se_id": "sigh_soft", "name": "吐息・安堵のため息（ふぅ…）", "category": "距離・スキンシップ", "keywords": "吐息,ため息,呼吸,耳元,落ち着く"},
    {"se_id": "door_knock", "name": "ドアノック（コンコン）", "category": "移動・日常", "keywords": "ノック,扉,部屋,訪問"},
    {"se_id": "door_open", "name": "扉が開く音（ガチャ…）", "category": "移動・日常", "keywords": "ドアを開ける,扉,入室,室内"},
    {"se_id": "tea_pour", "name": "お茶を注ぐ音（トクトク…）", "category": "移動・日常", "keywords": "お茶,紅茶,注ぐ,湯呑み,ティータイム,休憩"},
    {"se_id": "wind_breeze", "name": "幻想郷のそよ風（サーッ…）", "category": "環境・幻想郷", "keywords": "風,そよ風,境内,森,空,舞い降りる,桜"},
    {"se_id": "magic_chime", "name": "魔法・神秘チャイム（シャラン✨）", "category": "環境・幻想郷", "keywords": "魔法,幻想的,弾幕,紅魔館,妖気,奇跡"},
    {"se_id": "wedding_bell", "name": "祝福のウェディングベル（カランコロン🔔）", "category": "感情・恋愛", "keywords": "結婚式,プロポーズ,永遠,誓い,祝福"},
]
BUILTIN_SE_IDS = {item["se_id"] for item in BUILTIN_SOUND_EFFECTS}


def _norm(s: str) -> str:
    return unicodedata.normalize("NFKC", s or "").strip()


def load_custom_presets() -> List[Dict[str, Any]]:
    if not os.path.isfile(CUSTOM_PRESETS_FILE):
        return []
    try:
        with open(CUSTOM_PRESETS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def save_custom_preset(preset: Dict[str, Any]) -> List[Dict[str, Any]]:
    os.makedirs(DATA_DIR, exist_ok=True)
    presets = load_custom_presets()
    pid = re.sub(r"[^a-zA-Z0-9_\-]", "_", str(preset.get("id") or f"custom_{len(presets)+1}"))[:36]
    entry = {
        "id": pid,
        "name": _norm(str(preset.get("name") or pid))[:40],
        "stage_direction": normalize_stage_direction(preset.get("stage_direction") or {}),
    }
    presets = [p for p in presets if p.get("id") != pid]
    presets.append(entry)
    with open(CUSTOM_PRESETS_FILE, "w", encoding="utf-8") as f:
        json.dump(presets, f, ensure_ascii=False, indent=2)
    return presets


def delete_custom_preset(preset_id: str) -> List[Dict[str, Any]]:
    presets = [p for p in load_custom_presets() if p.get("id") != preset_id]
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(CUSTOM_PRESETS_FILE, "w", encoding="utf-8") as f:
        json.dump(presets, f, ensure_ascii=False, indent=2)
    return presets


def get_master_stage_catalog() -> Dict[str, Any]:
    return {
        "distance_presets": list(DISTANCE_PRESETS.values()),
        "motion_presets": list(MOTION_PRESETS.values()),
        "screen_effects": list(SCREEN_EFFECTS.values()),
        "builtin_sound_effects": BUILTIN_SOUND_EFFECTS,
        "custom_presets": load_custom_presets(),
    }


def _clamp_float(val: Any, low: float, high: float, default: float) -> float:
    try:
        v = float(val)
        if v != v:  # NaN guard
            return default
        return round(max(low, min(high, v)), 3)
    except (TypeError, ValueError):
        return default


def _clamp_int(val: Any, low: int, high: int, default: int) -> int:
    try:
        return max(low, min(high, int(val)))
    except (TypeError, ValueError):
        return default


def infer_stage_direction_from_context(
    emotion: str = "normal",
    prefer_blush: bool = False,
    affection: int = 20,
    narration: str = "",
    dialogue: str = "",
    is_wedding: bool = False,
    turn_index: int = 1,
) -> Dict[str, Any]:
    """
    既存セーブデータ読込時やAI未指定時のための軽量ヒューリスティック演出推論。
    セリフ・地の文・好感度・感情から最適な拡大率・動き・効果音を自動構築する。
    """
    text = _norm(f"{narration} {dialogue}")
    emo = (emotion or "normal").lower().strip()

    if is_wedding:
        return {
            "distance_preset": "very_close",
            "narration_scale": 1.15,
            "dialogue_scale": 1.38,
            "offset_x": 0.0,
            "offset_y": 5.5,
            "origin_y_pct": 23,
            "narration_motion": "fade_zoom_in",
            "dialogue_motion": "hug_surge",
            "transition_ms": 800,
            "screen_effect": "sparkle_glow",
            "bg_zoom": 1.09,
            "bg_blur_px": 1.8,
            "se_cues": [
                {"se_id": "wedding_bell", "trigger": "narration", "delay_ms": 0, "volume": 0.8},
                {"se_id": "sparkle_twinkle", "trigger": "dialogue", "delay_ms": 120, "volume": 0.75},
            ],
        }

    if turn_index == 0:
        if "降りて" in text or "箒" in text or "宙" in text:
            n_mot, n_se = "float_in", "wind_breeze"
        else:
            n_mot, n_se = "slide_in_right", "footsteps_walk"
        return {
            "distance_preset": "slightly_far",
            "narration_scale": 0.86,
            "dialogue_scale": 0.98,
            "offset_x": 0.0,
            "offset_y": 0.5,
            "origin_y_pct": 60,
            "narration_motion": n_mot,
            "dialogue_motion": "head_tilt" if emo == "question" else "nod",
            "transition_ms": 680,
            "screen_effect": "none",
            "bg_zoom": 1.02,
            "bg_blur_px": 0.0,
            "se_cues": [
                {"se_id": n_se, "trigger": "narration", "delay_ms": 0, "volume": 0.7},
                {"se_id": "question_pon" if emo == "question" else "cloth_rustle", "trigger": "dialogue", "delay_ms": 80, "volume": 0.65},
            ],
        }

    # 距離・拡大率の推論
    dist = "normal"
    if any(k in text for k in ("ぎゅー", "抱きしめ", "抱きつ", "胸に飛び込", "唇", "キス", "吐息がかかる", "ゼロ距離")):
        dist = "hug_closeup"
    elif any(k in text for k in ("顔を近づけ", "耳元", "覗き込", "目と鼻の先", "頬に触れ", "額を合わせ")):
        dist = "very_close"
    elif any(k in text for k in ("歩み寄", "近づ", "隣に座", "袖を掴", "手を握", "手を繋", "寄り添")) or affection >= 72:
        dist = "close"
    elif any(k in text for k in ("後ずさ", "距離を置", "離れて", "遠く")):
        dist = "slightly_far"

    preset = DISTANCE_PRESETS[dist]
    d_scale = preset["scale"]
    n_scale = round(max(0.7, d_scale - 0.12), 2) if dist in ("close", "very_close", "hug_closeup") else d_scale

    # モーション推論
    n_motion = "step_closer" if dist in ("close", "very_close", "hug_closeup") else "none"
    if "後ずさ" in text:
        n_motion = "step_back"

    if dist == "hug_closeup":
        d_motion = "hug_surge"
    elif dist == "very_close":
        d_motion = "lean_in"
    elif emo == "yandere" or any(k in text for k in ("逃がさない", "壊れるくらい", "私だけの")):
        d_motion = "lean_in"
    elif emo == "angry":
        d_motion = "shake_angry"
    elif emo == "surprised":
        d_motion = "surprised_jolt"
    elif emo == "question":
        d_motion = "head_tilt"
    elif emo in ("sad", "troubled"):
        d_motion = "tremble"
    elif emo == "blush" or prefer_blush:
        d_motion = "sway_gentle" if affection >= 55 else "tremble"
    elif emo == "smile":
        d_motion = "jump_happy" if any(k in text for k in ("やった", "嬉しい", "大好き", "わーい")) else "nod"
    else:
        d_motion = "nod"

    # 画面エフェクト推論
    scr_fx = "none"
    if emo == "yandere":
        scr_fx = "dark_vignette"
    elif dist in ("very_close", "hug_closeup"):
        scr_fx = "heartbeat_pulse" if (prefer_blush or affection >= 65) else "warm_bloom"
    elif emo == "smile" and affection >= 55:
        scr_fx = "sparkle_glow"
    elif prefer_blush and affection >= 50:
        scr_fx = "warm_bloom"

    # SEキュー推論
    cues: List[Dict[str, Any]] = []
    if any(k in text for k in ("お茶", "紅茶", "湯呑", "注ぐ")):
        cues.append({"se_id": "tea_pour", "trigger": "narration", "delay_ms": 0, "volume": 0.72})
    elif any(k in text for k in ("扉", "ドア")):
        cues.append({"se_id": "door_open", "trigger": "narration", "delay_ms": 0, "volume": 0.72})
    elif any(k in text for k in ("駆け寄", "走って")):
        cues.append({"se_id": "footsteps_run", "trigger": "narration", "delay_ms": 0, "volume": 0.72})
    elif n_motion == "step_closer" or any(k in text for k in ("歩み寄", "近づ")):
        cues.append({"se_id": "footsteps_walk", "trigger": "narration", "delay_ms": 0, "volume": 0.68})
    elif any(k in text for k in ("風", "桜", "木々")):
        cues.append({"se_id": "wind_breeze", "trigger": "narration", "delay_ms": 0, "volume": 0.55})

    if dist == "hug_closeup":
        cues.append({"se_id": "hug_embrace", "trigger": "dialogue", "delay_ms": 0, "volume": 0.82})
        cues.append({"se_id": "heartbeat_fast", "trigger": "dialogue", "delay_ms": 320, "volume": 0.68})
    elif dist == "very_close":
        cues.append({"se_id": "cloth_rustle", "trigger": "dialogue", "delay_ms": 0, "volume": 0.75})
        cues.append({"se_id": "heartbeat", "trigger": "dialogue", "delay_ms": 300, "volume": 0.65})
    elif emo == "yandere":
        cues.append({"se_id": "dark_yandere", "trigger": "dialogue", "delay_ms": 0, "volume": 0.72})
    elif emo == "surprised":
        cues.append({"se_id": "surprised_biku", "trigger": "dialogue", "delay_ms": 0, "volume": 0.75})
    elif emo == "angry":
        cues.append({"se_id": "angry_boom", "trigger": "dialogue", "delay_ms": 0, "volume": 0.72})
    elif emo == "question":
        cues.append({"se_id": "question_pon", "trigger": "dialogue", "delay_ms": 0, "volume": 0.68})
    elif emo == "blush" or prefer_blush:
        cues.append({"se_id": "blush_pop", "trigger": "dialogue", "delay_ms": 60, "volume": 0.68})
    elif emo == "smile":
        cues.append({"se_id": "sparkle_twinkle", "trigger": "dialogue", "delay_ms": 60, "volume": 0.68})
    else:
        cues.append({"se_id": "cloth_rustle", "trigger": "dialogue", "delay_ms": 40, "volume": 0.55})

    return {
        "distance_preset": dist,
        "narration_scale": n_scale,
        "dialogue_scale": d_scale,
        "offset_x": 0.0,
        "offset_y": preset["offset_y_vh"],
        "origin_y_pct": preset["origin_y_pct"],
        "narration_motion": n_motion,
        "dialogue_motion": d_motion,
        "transition_ms": 640,
        "screen_effect": scr_fx,
        "bg_zoom": preset["bg_zoom"],
        "bg_blur_px": preset["bg_blur_px"],
        "se_cues": cues[:3],
    }


def _resolve_se_id(raw_se_id: str, available_local_se: Optional[List[Dict[str, Any]]] = None) -> Tuple[str, str]:
    """(resolved_se_id, keyword) を返す。ローカルSE一覧または内蔵SE20種にマッチさせる"""
    sid = _norm(raw_se_id)
    if not sid:
        return "", ""
    local_list = available_local_se or []
    for lse in local_list:
        if lse.get("se_id") == sid:
            return sid, str(lse.get("name", sid))
    if sid in BUILTIN_SE_IDS:
        return sid, sid
    # キーワード部分一致でローカルSE→内蔵SEの順に探索
    for lse in local_list:
        nm = _norm(str(lse.get("name", "")))
        tags = _norm(str(lse.get("tags", "")))
        if sid in nm or nm in sid or (tags and sid in tags):
            return str(lse["se_id"]), nm
    for bse in BUILTIN_SOUND_EFFECTS:
        if sid in bse["name"] or any(k in sid or sid in k for k in bse["keywords"].split(",")):
            return bse["se_id"], sid
    return "cloth_rustle", sid


def normalize_stage_direction(
    raw_dir: Optional[Dict[str, Any]],
    emotion: str = "normal",
    prefer_blush: bool = False,
    affection: int = 20,
    narration: str = "",
    dialogue: str = "",
    is_wedding: bool = False,
    turn_index: int = 1,
    available_local_se: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """
    Gemini出力または手動編集された stage_direction を安全に正規化・補完する。
    """
    inferred = infer_stage_direction_from_context(
        emotion=emotion,
        prefer_blush=prefer_blush,
        affection=affection,
        narration=narration,
        dialogue=dialogue,
        is_wedding=is_wedding,
        turn_index=turn_index,
    )
    if not isinstance(raw_dir, dict) or not raw_dir:
        return inferred

    dist = str(raw_dir.get("distance_preset") or inferred["distance_preset"]).strip()
    if dist not in DISTANCE_PRESETS:
        dist = inferred["distance_preset"]
    preset = DISTANCE_PRESETS[dist]

    d_scale = _clamp_float(raw_dir.get("dialogue_scale", raw_dir.get("scale", preset["scale"])), 0.55, 1.80, preset["scale"])
    default_n_scale = round(max(0.60, d_scale - 0.10), 2) if d_scale > 1.12 else d_scale
    n_scale = _clamp_float(raw_dir.get("narration_scale", default_n_scale), 0.55, 1.80, default_n_scale)

    # スケールに応じた頭切れ防止の自動フレーミング補正
    if d_scale >= 1.45:
        default_origin_y, default_off_y, default_bg_z, default_blur = 22, 7.5, 1.11, 2.5
    elif d_scale >= 1.28:
        default_origin_y, default_off_y, default_bg_z, default_blur = 23, 5.5, 1.08, 1.6
    elif d_scale >= 1.12:
        default_origin_y, default_off_y, default_bg_z, default_blur = 26, 3.2, 1.05, 0.7
    elif d_scale <= 0.80:
        default_origin_y, default_off_y, default_bg_z, default_blur = 85, 1.8, 1.00, 0.0
    else:
        default_origin_y, default_off_y, default_bg_z, default_blur = preset["origin_y_pct"], preset["offset_y_vh"], preset["bg_zoom"], preset["bg_blur_px"]

    off_x = _clamp_float(raw_dir.get("offset_x", 0.0), -32.0, 32.0, 0.0)
    off_y = _clamp_float(raw_dir.get("offset_y", default_off_y), -12.0, 20.0, default_off_y)
    origin_y = _clamp_int(raw_dir.get("origin_y_pct", default_origin_y), 15, 95, default_origin_y)

    n_mot = str(raw_dir.get("narration_motion") or inferred["narration_motion"]).strip()
    if n_mot not in MOTION_PRESETS:
        n_mot = inferred["narration_motion"]

    d_mot = str(raw_dir.get("dialogue_motion") or raw_dir.get("motion") or inferred["dialogue_motion"]).strip()
    if d_mot not in MOTION_PRESETS:
        d_mot = inferred["dialogue_motion"]

    scr_fx = str(raw_dir.get("screen_effect") or inferred["screen_effect"]).strip()
    if scr_fx not in SCREEN_EFFECTS:
        scr_fx = inferred["screen_effect"]

    trans_ms = _clamp_int(raw_dir.get("transition_ms", 620), 180, 1800, 620)
    bg_zoom = _clamp_float(raw_dir.get("bg_zoom", default_bg_z), 1.0, 1.22, default_bg_z)
    bg_blur = _clamp_float(raw_dir.get("bg_blur_px", default_blur), 0.0, 5.0, default_blur)

    raw_cues = raw_dir.get("se_cues")
    clean_cues: List[Dict[str, Any]] = []
    if isinstance(raw_cues, list):
        for c in raw_cues[:4]:
            if not isinstance(c, dict):
                continue
            sid, kw = _resolve_se_id(str(c.get("se_id") or c.get("keyword") or ""), available_local_se)
            if not sid:
                continue
            trig = str(c.get("trigger") or "dialogue").strip().lower()
            if trig not in ("narration", "dialogue", "both"):
                trig = "dialogue"
            clean_cues.append({
                "se_id": sid,
                "keyword": kw,
                "trigger": trig,
                "delay_ms": _clamp_int(c.get("delay_ms", 0), 0, 2500, 0),
                "volume": _clamp_float(c.get("volume", 0.72), 0.1, 1.0, 0.72),
            })

    if not clean_cues:
        clean_cues = inferred["se_cues"]

    return {
        "distance_preset": dist,
        "narration_scale": n_scale,
        "dialogue_scale": d_scale,
        "offset_x": off_x,
        "offset_y": off_y,
        "origin_y_pct": origin_y,
        "narration_motion": n_mot,
        "dialogue_motion": d_mot,
        "transition_ms": trans_ms,
        "screen_effect": scr_fx,
        "bg_zoom": bg_zoom,
        "bg_blur_px": bg_blur,
        "se_cues": clean_cues,
    }


# ==================== 5. Gemini API 連携用プロンプト＆JSONスキーマ定義 ====================

STAGE_DIRECTION_JSON_SCHEMA: Dict[str, Any] = {
    "type": "OBJECT",
    "properties": {
        "distance_preset": {
            "type": "STRING",
            "enum": list(DISTANCE_PRESETS.keys()),
        },
        "narration_scale": {"type": "NUMBER"},
        "dialogue_scale": {"type": "NUMBER"},
        "offset_x": {"type": "NUMBER"},
        "narration_motion": {
            "type": "STRING",
            "enum": list(MOTION_PRESETS.keys()),
        },
        "dialogue_motion": {
            "type": "STRING",
            "enum": list(MOTION_PRESETS.keys()),
        },
        "transition_ms": {"type": "INTEGER"},
        "screen_effect": {
            "type": "STRING",
            "enum": list(SCREEN_EFFECTS.keys()),
        },
        "se_cues": {
            "type": "ARRAY",
            "items": {
                "type": "OBJECT",
                "properties": {
                    "se_id": {"type": "STRING"},
                    "trigger": {"type": "STRING", "enum": ["narration", "dialogue"]},
                    "delay_ms": {"type": "INTEGER"},
                    "volume": {"type": "NUMBER"},
                },
                "required": ["se_id", "trigger"],
            },
        },
    },
    "required": [
        "distance_preset",
        "narration_scale",
        "dialogue_scale",
        "narration_motion",
        "dialogue_motion",
        "screen_effect",
        "se_cues",
    ],
}

STAGE_DIRECTOR_FUNCTION_DECLARATION: Dict[str, Any] = {
    "name": "call_stage_director",
    "description": "『キャラステージ演出メーカー』を呼び出し、プレゼンテーションソフトのように立ち絵の拡大縮小・アニメーション・画面効果・効果音再生キューを設定する。",
    "parameters": STAGE_DIRECTION_JSON_SCHEMA,
}


def build_gemini_stage_prompt_section(available_local_se: Optional[List[Dict[str, Any]]] = None) -> str:
    builtin_str = ", ".join(f"{s['se_id']}({s['name']})" for s in BUILTIN_SOUND_EFFECTS)
    local_lines = ""
    if available_local_se:
        local_summary = ", ".join(
            f"{s.get('se_id')}:{s.get('name')}" for s in available_local_se[:30]
        )
        local_lines = f"\n- 利用者PCローカル効果音（優先使用可）: {local_summary}"

    custom_presets = load_custom_presets()
    custom_lines = ""
    if custom_presets:
        cp_str = ", ".join(
            f"{p['name']}(scale={p['stage_direction'].get('dialogue_scale')}, motion={p['stage_direction'].get('dialogue_motion')})"
            for p in custom_presets[:10]
        )
        custom_lines = f"\n- ユーザー登録カスタム演出参考: {cp_str}"

    return f"""【6. 『キャラステージ演出メーカー』プレゼン風リアリティ演出ルール (`stage_direction`)】
一般的なプレゼンテーションソフト（Keynoteのマジックムーブやビルド演出）のように、地の文（narration）→セリフ（dialogue）の2段階で立ち絵の距離感（拡大・縮小）、動き、画面効果、効果音をリアルに演出してください。
- `distance_preset` と拡大率 (`narration_scale`, `dialogue_scale` 目安 `0.70`〜`1.60`):
  - `far` (`0.72`): 遠くにいる・見送る / `slightly_far` (`0.86`): 初対面・警戒・一歩下がる
  - `normal` (`1.00`): 通常の会話距離 / `close` (`1.18`): 親しく歩み寄る・隣に座る・袖を掴む
  - `very_close` (`1.38`): 顔を近づける・覗き込む・耳元で囁く / `hug_closeup` (`1.56`): 抱きつく・密着・キス寸前
  - 例: 地の文で歩み寄ってセリフで顔を近づける場合は `narration_scale: 1.05` → `dialogue_scale: 1.35` のように差をつけると滑らかにズームインします！
- `offset_x`: 左右の位置ずらし（`-25`〜`+25`、通常は `0`、横に並ぶ・覗き込む演出では `-8`〜`+8` 程度）。
- モーション (`narration_motion`, `dialogue_motion`):
  `none`, `slide_in_left`, `slide_in_right`, `fade_zoom_in`, `float_in`, `step_closer`(歩み寄る), `step_back`(後ずさる), `nod`(頷く), `head_tilt`(小首かしげ), `jump_happy`(喜びジャンプ), `double_bounce`(弾む), `tremble`(照れ・涙で震える), `shake_angry`(怒り揺れ), `sway_gentle`(甘え揺れ), `lean_in`(覗き込み急接近), `hug_surge`(抱きつく), `surprised_jolt`(ビクッと驚く), `spin_turn`(華麗にターン)
- `screen_effect`: `none`, `warm_bloom`(甘い暖色), `sparkle_glow`(ときめき発光), `heartbeat_pulse`(鼓動ドキドキ), `screen_shake`(衝撃・ツッコミ), `dark_vignette`(ヤンデレ・緊迫)
- 効果音キュー `se_cues`（1〜3個、`trigger` は `"narration"` または `"dialogue"`、`delay_ms` は `0`〜`1200`）:
  - 内蔵効果音ID: {builtin_str}{local_lines}{custom_lines}"""
