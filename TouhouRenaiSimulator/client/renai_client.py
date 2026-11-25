#!/usr/bin/env python3
"""
『東方Project恋愛シミュレーター』超省リソース デスクトップクライアント (Mac / Linux / Windows 対応)
GitHub 無償配布対象クライアント:
  - AquesTalk ライブラリ本体 (.so / .dll / .phont) は一切同梱しない
  - 立ち絵・背景・効果音などの外部素材も一切同梱せず、サーバーからも配信しない
  - 利用者が自身のPCへ配置したローカル素材フォルダ（立ち絵・背景・効果音）を直接走査・表示・再生する
  - 標準ライブラリのみで動作し、多重起動防止シングルインスタンス機構＋終了後自動メモリ解放を搭載:
    1. 起動時のソースコード・ファイル改ざん検証 (Slide 11: 検証中… / 不正時は起動ブロック)
    2. 利用者PC内のローカル素材フォルダ（立ち絵・背景・効果音）の設定・インデックス化・直接配信
    3. 全セーブセッション一覧読込・任意ターン巻き戻し/分岐再開・ZIP/JSONインポート＆エクスポート
    4. 『キャラステージ演出メーカー』単体スタジオとのシームレス連携
"""

import io
import os
import re
import gc
import sys
import json
import time
import base64
import shutil
import socket
import zipfile
import hashlib
import platform
import mimetypes
import threading
import webbrowser
import subprocess
import unicodedata
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import urlparse, parse_qs

CLIENT_DIR = os.path.abspath(os.path.dirname(__file__))
WEB_DIR = os.path.join(CLIENT_DIR, "web")
MANIFEST_FILE = os.path.join(CLIENT_DIR, "integrity_manifest.json")

# 同PC内に『キャラステージ演出メーカー』が存在する場合は演出推論エンジンも共用（未導入環境でも単体フォールバック完備）
_STAGE_STUDIO_CANDIDATE = os.path.abspath(os.path.join(CLIENT_DIR, "..", "..", "キャラステージ演出メーカー"))
_HAS_STAGE_STUDIO = os.path.isdir(_STAGE_STUDIO_CANDIDATE)
if _HAS_STAGE_STUDIO and _STAGE_STUDIO_CANDIDATE not in sys.path:
    sys.path.insert(0, _STAGE_STUDIO_CANDIDATE)

try:
    from stage_director_engine import normalize_stage_direction as _ext_normalize_stage  # type: ignore
except Exception:
    _ext_normalize_stage = None

if CLIENT_DIR not in sys.path:
    sys.path.insert(0, CLIENT_DIR)

from standalone_engine import (  # noqa: E402
    generate_starter_bg_svg,
    generate_starter_portrait_svg,
    load_standalone_catalog,
    standalone_generate_bg,
    standalone_start_scene,
    standalone_turn_scene,
)

# ユーザーPC上のローカル保存ディレクトリ
USER_DATA_DIR = os.path.join(os.path.expanduser("~"), ".touhou_renai_simulator")
SAVES_DIR = os.path.join(USER_DATA_DIR, "saves")
DEFAULT_USER_ASSETS_DIR = os.path.join(USER_DATA_DIR, "assets")
CUSTOM_PORTRAITS_DIR = os.path.join(USER_DATA_DIR, "custom_portraits")
TACHIE_EXPORT_DIR = os.path.join(USER_DATA_DIR, "tachie_exports")
GENERATED_BG_LOCAL_DIR = os.path.join(USER_DATA_DIR, "generated_backgrounds")
LOCAL_CONFIG_FILE = os.path.join(USER_DATA_DIR, "local_config.json")
LOCAL_ASSETS_CACHE_FILE = os.path.join(USER_DATA_DIR, "local_assets_cache.json")
INSTANCE_LOCK_FILE = os.path.join(USER_DATA_DIR, "client_instance.json")
TAMPER_LOCK_FILE = os.path.join(USER_DATA_DIR, ".tamper_blocked")

DEFAULT_API_SERVER = os.environ.get("RENAI_SERVER_URL", "http://127.0.0.1:8096")

os.makedirs(SAVES_DIR, exist_ok=True)
os.makedirs(CUSTOM_PORTRAITS_DIR, exist_ok=True)
os.makedirs(TACHIE_EXPORT_DIR, exist_ok=True)
os.makedirs(os.path.join(DEFAULT_USER_ASSETS_DIR, "はるか式立ち絵"), exist_ok=True)
os.makedirs(os.path.join(DEFAULT_USER_ASSETS_DIR, "背景"), exist_ok=True)
os.makedirs(os.path.join(DEFAULT_USER_ASSETS_DIR, "効果音"), exist_ok=True)
os.makedirs(GENERATED_BG_LOCAL_DIR, exist_ok=True)

_GUIDE_TXT = os.path.join(DEFAULT_USER_ASSETS_DIR, "素材配置ガイド.txt")
if not os.path.exists(_GUIDE_TXT):
    with open(_GUIDE_TXT, "w", encoding="utf-8") as _gf:
        _gf.write(
            "【東方Project恋愛シミュレーター ローカル素材配置フォルダ】\n\n"
            "本ゲームでは各素材の規約を遵守するため、立ち絵・背景・効果音素材をサーバーからは配信せず、\n"
            "利用者ご自身のPCに配置したフォルダから直接読み込みます。\n\n"
            "■ 配置方法（またはゲーム起動画面の「素材フォルダ設定」で任意の既存フォルダを指定可能）:\n"
            "  1. 立ち絵素材: 「はるか式立ち絵」（または「立ち絵」）フォルダ内にキャラ別のPNG画像を配置\n"
            "  2. 背景素材  : 「背景」フォルダ内に背景画像 (.jpg / .png / .webp) を配置\n"
            "  3. 効果音素材: 「効果音」フォルダ内に効果音 (.wav / .mp3 / .ogg) を配置（※未配置でも内蔵シンセSE 20種が自動再生されます）\n"
        )

_LAST_CLIENT_PING = time.time()
_CLIENT_SEEN_ONCE = False


def _norm(s: str) -> str:
    return unicodedata.normalize("NFKC", s or "").strip()


def _fallback_stage_direction(sc: Dict[str, Any], turn_index: int = 1) -> Dict[str, Any]:
    if isinstance(sc.get("stage_direction"), dict) and sc["stage_direction"]:
        return sc["stage_direction"]
    if _ext_normalize_stage is not None:
        return _ext_normalize_stage(
            None,
            emotion=sc.get("emotion", "normal"),
            prefer_blush=bool(sc.get("prefer_blush")),
            affection=int(sc.get("affection", 20)),
            narration=sc.get("narration", ""),
            dialogue=sc.get("dialogue", ""),
            is_wedding=bool(sc.get("is_wedding_goal")),
            turn_index=turn_index,
        )
    txt = f"{sc.get('narration', '')} {sc.get('dialogue', '')}"
    aff = int(sc.get("affection", 20))
    scale = 1.48 if ("ぎゅー" in txt or "抱き" in txt) else (1.32 if "近づけ" in txt else (1.16 if aff >= 70 else 1.0))
    return {
        "distance_preset": "close" if scale > 1.05 else "normal",
        "narration_scale": max(0.85, round(scale - 0.1, 2)),
        "dialogue_scale": scale,
        "offset_x": 0.0,
        "offset_y": 5.5 if scale > 1.25 else (3.0 if scale > 1.05 else 0.0),
        "origin_y_pct": 23 if scale > 1.1 else 55,
        "narration_motion": "step_closer" if scale > 1.05 else "none",
        "dialogue_motion": "lean_in" if scale > 1.25 else "nod",
        "transition_ms": 620,
        "screen_effect": "warm_bloom" if sc.get("prefer_blush") else "none",
        "bg_zoom": 1.06 if scale > 1.1 else 1.02,
        "bg_blur_px": 1.5 if scale > 1.25 else 0.0,
        "se_cues": [{"se_id": "cloth_rustle", "trigger": "dialogue", "delay_ms": 0, "volume": 0.7}],
    }


def _sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_client_integrity() -> Dict[str, Any]:
    if os.path.exists(TAMPER_LOCK_FILE):
        return {
            "ok": False,
            "blocked": True,
            "reason": "過去に不正な改ざんが検出されたため、ゲームの起動がブロックされています。",
        }
    if not os.path.exists(MANIFEST_FILE):
        return {"ok": True, "blocked": False, "detail": "manifest_not_present_dev_mode"}

    try:
        with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
            manifest = json.load(f)
        files_map: Dict[str, str] = manifest.get("files", {})
        for rel_p, expected_hash in files_map.items():
            abs_p = os.path.join(CLIENT_DIR, rel_p)
            if not os.path.isfile(abs_p):
                with open(TAMPER_LOCK_FILE, "w", encoding="utf-8") as lf:
                    lf.write(f"missing:{rel_p}\n")
                return {"ok": False, "blocked": True, "reason": f"必須ファイルが欠損しています: {rel_p}"}
            if _sha256_file(abs_p) != expected_hash:
                with open(TAMPER_LOCK_FILE, "w", encoding="utf-8") as lf:
                    lf.write(f"mismatch:{rel_p}\n")
                return {"ok": False, "blocked": True, "reason": f"プログラムの不正な改ざんが検出されました: {rel_p}"}
        return {"ok": True, "blocked": False, "verified_files": len(files_map)}
    except Exception as exc:
        return {"ok": False, "blocked": False, "reason": f"検証処理エラー: {exc}"}


def _detect_initial_assets_root() -> str:
    home = os.path.expanduser("~")
    candidates = [
        os.path.join(CLIENT_DIR, "assets"),
        DEFAULT_USER_ASSETS_DIR,
        os.path.join(home, "ドキュメント"),
        os.path.join(home, "Documents"),
        os.path.abspath(os.path.join(CLIENT_DIR, "../..")),
    ]
    for c in candidates:
        if c and os.path.isdir(c):
            try:
                entries = [_norm(e) for e in os.listdir(c)]
                if any(k in entries for k in ("はるか式立ち絵", "立ち絵", "背景")):
                    for sub in os.listdir(c):
                        if _norm(sub) in ("はるか式立ち絵", "立ち絵", "背景"):
                            sub_p = os.path.join(c, sub)
                            if os.path.isdir(sub_p) and any(not x.startswith(".") for x in os.listdir(sub_p)):
                                return os.path.abspath(c)
            except OSError:
                pass
    return DEFAULT_USER_ASSETS_DIR


def load_local_config() -> Dict[str, Any]:
    cfg: Dict[str, Any] = {
        "server_url": DEFAULT_API_SERVER,
        "session_token": "",
        "user_gemini_api_key": "",
        "voice_enabled": True,
        "se_enabled": True,
        "se_volume": 0.8,
        "auto_bg_generation": True,
        "char_color_profiles": {},
        "assets_root_dir": "",
        "portraits_dir_override": "",
        "backgrounds_dir_override": "",
        "se_dir_override": "",
        "pending_purchase": None,
        "last_session_id": "",
    }
    if os.path.exists(LOCAL_CONFIG_FILE):
        try:
            with open(LOCAL_CONFIG_FILE, "r", encoding="utf-8") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                cfg.update(loaded)
        except Exception:
            pass

    if not cfg.get("assets_root_dir") or not os.path.isdir(str(cfg["assets_root_dir"])):
        cfg["assets_root_dir"] = _detect_initial_assets_root()

    if cfg["server_url"] == "http://127.0.0.1:8096":
        try:
            with socket.create_connection(("127.0.0.1", 8096), timeout=0.3):
                cfg["server_url"] = "http://127.0.0.1:8096"
        except OSError:
            pass
    return cfg


def save_local_config(updates: Dict[str, Any]) -> Dict[str, Any]:
    cfg = load_local_config()
    cfg.update(updates)
    os.makedirs(USER_DATA_DIR, exist_ok=True)
    with open(LOCAL_CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    try:
        os.chmod(LOCAL_CONFIG_FILE, 0o600)
    except OSError:
        pass
    return cfg


# ==================== ローカル素材フォルダ走査・解決エンジン ====================

_ASSETS_MEM_CACHE: Optional[Dict[str, Any]] = None
_ASSETS_LOCK = threading.Lock()


def _classify_emotion(label: str) -> Tuple[str, int]:
    lb = _norm(label)
    is_blush = 1 if ("赤面" in lb or "照" in lb) else 0
    if any(k in lb for k in ("病み", "狂気", "ヤンデレ", "絶望")):
        return "yandere", is_blush
    if any(k in lb for k in ("疑問", "きょとん", "はてな", "？", "?")):
        return "question", is_blush
    if any(k in lb for k in ("微笑", "笑顔", "笑い", "にっこり", "嬉", "喜")):
        return "smile", is_blush
    if any(k in lb for k in ("怒", "激おこ", "ムッ", "ジト", "睨")):
        return "angry", is_blush
    if any(k in lb for k in ("驚", "びっくり", "焦", "汗")):
        return "surprised", is_blush
    if any(k in lb for k in ("泣", "涙", "悲")):
        return "sad", is_blush
    if any(k in lb for k in ("困", "苦笑", "呆", "欠伸")):
        return "troubled", is_blush
    if any(k in lb for k in ("不敵", "ドヤ", "余裕")):
        return "smug", is_blush
    if is_blush:
        return "blush", 1
    if any(k in lb for k in ("普通", "通常", "ノーマル")):
        return "normal", is_blush
    return "other", is_blush


def _classify_bg_tags_and_time(name: str) -> Tuple[str, str]:
    nm = _norm(name)
    tod = "any"
    if any(k in nm for k in ("夜", "暗", "月", "星")):
        tod = "night"
    elif any(k in nm for k in ("夕", "黄昏", "茜")):
        tod = "evening"
    elif any(k in nm for k in ("昼", "日中", "晴", "青空")):
        tod = "day"

    tags = [nm]
    keyword_groups = [
        ("神社・境内", ("神社", "鳥居", "境内", "博麗", "守矢")),
        ("紅魔館・洋館", ("紅魔", "館", "ロビー", "書斎", "図書館", "食堂")),
        ("日常・室内", ("部屋", "家", "部室", "玄関", "廊下", "教室", "会議室", "診察室", "研究室")),
        ("デート・街", ("観覧車", "映画館", "ショッピング", "ゲームセンター", "カフェ", "居酒屋", "バー", "屋上", "宴会")),
        ("自然・幻想郷", ("森", "竹林", "湖", "山", "峡谷", "桜", "花", "川", "道", "空")),
    ]
    for grp, words in keyword_groups:
        if any(w in nm for w in words):
            tags.append(grp)
    return ", ".join(tags), tod


def resolve_asset_directories(cfg: Optional[Dict[str, Any]] = None) -> Tuple[str, List[str], List[str], List[str]]:
    """(assets_root, portrait_dirs, background_dirs, se_dirs) を解決して返す"""
    c = cfg or load_local_config()
    root = os.path.expanduser(str(c.get("assets_root_dir") or DEFAULT_USER_ASSETS_DIR).strip())
    p_override = os.path.expanduser(str(c.get("portraits_dir_override") or "").strip())
    b_override = os.path.expanduser(str(c.get("backgrounds_dir_override") or "").strip())
    se_override = os.path.expanduser(str(c.get("se_dir_override") or "").strip())

    portrait_dirs: List[str] = []
    if os.path.isdir(CUSTOM_PORTRAITS_DIR):
        portrait_dirs.append(os.path.abspath(CUSTOM_PORTRAITS_DIR))
    if p_override and os.path.isdir(p_override):
        portrait_dirs.append(os.path.abspath(p_override))
    if os.path.isdir(root):
        for entry in sorted(os.listdir(root)):
            ne = _norm(entry)
            full = os.path.join(root, entry)
            if os.path.isdir(full):
                if ne in ("立ち絵作成ツール",):
                    out_sub = os.path.join(full, "出力")
                    if os.path.isdir(out_sub):
                        portrait_dirs.insert(0, os.path.abspath(out_sub))
                elif ne in ("はるか式立ち絵", "立ち絵", "portraits", "characters"):
                    portrait_dirs.append(os.path.abspath(full))
        if not portrait_dirs and any("主人公" in _norm(x) or "紅魔郷" in _norm(x) for x in os.listdir(root)):
            portrait_dirs.append(os.path.abspath(root))

    bg_dirs: List[str] = []
    if b_override and os.path.isdir(b_override):
        bg_dirs.append(os.path.abspath(b_override))
    if os.path.isdir(root):
        for entry in sorted(os.listdir(root)):
            if _norm(entry) in ("背景", "backgrounds", "bg"):
                full = os.path.join(root, entry)
                if os.path.isdir(full):
                    bg_dirs.append(os.path.abspath(full))
    if os.path.isdir(GENERATED_BG_LOCAL_DIR):
        bg_dirs.append(os.path.abspath(GENERATED_BG_LOCAL_DIR))

    se_dirs: List[str] = []
    if se_override and os.path.isdir(se_override):
        se_dirs.append(os.path.abspath(se_override))
    if os.path.isdir(root):
        for entry in sorted(os.listdir(root)):
            if _norm(entry).lower() in ("効果音", "se", "sfx", "sound_effects", "sounds"):
                full = os.path.join(root, entry)
                if os.path.isdir(full) and os.path.abspath(full) not in se_dirs:
                    se_dirs.append(os.path.abspath(full))
    default_se = os.path.join(DEFAULT_USER_ASSETS_DIR, "効果音")
    if os.path.isdir(default_se) and os.path.abspath(default_se) not in se_dirs:
        se_dirs.append(os.path.abspath(default_se))

    return os.path.abspath(root), portrait_dirs, bg_dirs, se_dirs


def _dir_mtime_sig(dirs: List[str]) -> str:
    parts = []
    for d in dirs:
        if not os.path.isdir(d):
            continue
        try:
            st = os.stat(d)
            sub_cnt = len(os.listdir(d))
            parts.append(f"{d}:{int(st.st_mtime)}:{sub_cnt}")
        except OSError:
            parts.append(d)
    return "v2|" + "|".join(parts)


def scan_local_assets(force: bool = False) -> Dict[str, Any]:
    global _ASSETS_MEM_CACHE
    with _ASSETS_LOCK:
        root, p_dirs, b_dirs, se_dirs = resolve_asset_directories()
        sig = _dir_mtime_sig(p_dirs + b_dirs + se_dirs)

        if not force and _ASSETS_MEM_CACHE is not None and _ASSETS_MEM_CACHE.get("signature") == sig:
            return _ASSETS_MEM_CACHE

        if not force and os.path.isfile(LOCAL_ASSETS_CACHE_FILE):
            try:
                with open(LOCAL_ASSETS_CACHE_FILE, "r", encoding="utf-8") as f:
                    cached = json.load(f)
                if cached.get("signature") == sig:
                    _ASSETS_MEM_CACHE = cached
                    return cached
            except Exception:
                pass

        # 1. 立ち絵走査
        char_groups: List[Dict[str, Any]] = []
        total_portrait_files = 0
        for pd in p_dirs:
            if not os.path.isdir(pd):
                continue
            for cur_root, _, files in os.walk(pd):
                imgs = sorted(f for f in files if not f.startswith(".") and f.lower().endswith((".png", ".webp")))
                if not imgs:
                    continue
                rel = os.path.relpath(cur_root, pd)
                parts = [_norm(p) for p in rel.split(os.sep) if p and p != "."]
                if len(parts) >= 2 and parts[-1] in ("通常", "赤面", "服ビリ", "差分", "normal", "blush"):
                    char_folder = parts[-2]
                elif len(parts) >= 1:
                    char_folder = parts[-1]
                else:
                    char_folder = _norm(os.path.basename(pd))

                if "ちび" in char_folder or "やられ" in char_folder:
                    continue

                base_name = re.split(r"[(（]", char_folder, maxsplit=1)[0].strip()
                is_variant = 1 if ("(" in char_folder or "（" in char_folder) else 0

                grp_items = []
                for fn in imgs:
                    abs_img = os.path.join(cur_root, fn)
                    stem = _norm(os.path.splitext(fn)[0])
                    m = re.search(r"[(（]([^)）]+)[)）]$", stem)
                    face_label = m.group(1) if m else stem
                    if parts and parts[-1] == "赤面" and "赤面" not in face_label:
                        face_label = f"赤面:{face_label}"
                    emo, is_blush = _classify_emotion(face_label)
                    grp_items.append({"emo": emo, "blush": is_blush, "label": face_label, "path": abs_img})
                    total_portrait_files += 1

                char_groups.append({
                    "char_base": base_name,
                    "folder_title": char_folder,
                    "is_variant": is_variant,
                    "items": grp_items,
                })

        char_groups.sort(key=lambda g: (g["is_variant"], g["folder_title"]))

        # 2. 背景走査
        backgrounds: List[Dict[str, Any]] = []
        seen_bg_ids = set()
        for bd in b_dirs:
            if not os.path.isdir(bd):
                continue
            is_gen = 1 if os.path.abspath(bd) == os.path.abspath(GENERATED_BG_LOCAL_DIR) else 0
            for idx, fn in enumerate(sorted(os.listdir(bd))):
                if fn.startswith(".") or not fn.lower().endswith((".jpg", ".jpeg", ".png", ".webp", ".svg")):
                    continue
                abs_bg = os.path.join(bd, fn)
                if not os.path.isfile(abs_bg):
                    continue
                raw_stem = _norm(os.path.splitext(fn)[0])
                m_nc = re.match(r"^(nc\d+)[_＿]?(.*)$", raw_stem)
                bg_id = m_nc.group(1) if m_nc else f"{'gen' if is_gen else 'bg'}_{idx:04d}_{raw_stem[:12]}"
                if bg_id in seen_bg_ids:
                    bg_id = f"{bg_id}_{idx}"
                seen_bg_ids.add(bg_id)
                clean_name = m_nc.group(2) if m_nc and m_nc.group(2) else raw_stem
                for rm_tok in ("【背景素材】", "【背景画像】", "【背景】"):
                    clean_name = clean_name.replace(rm_tok, "")
                clean_name = clean_name.strip() or fn
                tags, tod = _classify_bg_tags_and_time(clean_name)
                backgrounds.append({
                    "bg_id": bg_id,
                    "name": clean_name,
                    "tags": tags,
                    "time_of_day": tod,
                    "is_generated": is_gen,
                    "path": abs_bg,
                })

        # 3. 効果音フォルダ走査 (.wav / .mp3 / .ogg / .m4a / .webm)
        sound_effects: List[Dict[str, Any]] = []
        seen_se_ids = set()
        for sd in se_dirs:
            if not os.path.isdir(sd):
                continue
            for cur_root, _, files in os.walk(sd):
                for idx, fn in enumerate(sorted(files)):
                    if fn.startswith(".") or not fn.lower().endswith((".wav", ".mp3", ".ogg", ".m4a", ".webm")):
                        continue
                    abs_se = os.path.join(cur_root, fn)
                    stem = _norm(os.path.splitext(fn)[0])
                    se_id = f"lse_{idx:03d}_{re.sub(r'[^0-9A-Za-z_]', '', stem)[:12]}"
                    if se_id in seen_se_ids:
                        se_id = f"{se_id}_{len(seen_se_ids)}"
                    seen_se_ids.add(se_id)
                    sound_effects.append({
                        "se_id": se_id,
                        "name": stem,
                        "tags": stem,
                        "path": abs_se,
                    })

        result = {
            "signature": sig,
            "assets_root_dir": root,
            "portrait_dirs": p_dirs,
            "background_dirs": b_dirs,
            "se_dirs": se_dirs,
            "char_group_count": len(char_groups),
            "portrait_file_count": total_portrait_files,
            "background_count": len(backgrounds),
            "se_count": len(sound_effects),
            "char_groups": char_groups,
            "backgrounds": backgrounds,
            "sound_effects": sound_effects,
        }
        try:
            with open(LOCAL_ASSETS_CACHE_FILE, "w", encoding="utf-8") as cf:
                json.dump(result, cf, ensure_ascii=False)
        except Exception:
            pass
        _ASSETS_MEM_CACHE = result
        return result


def resolve_local_portrait_path(
    char_name: str,
    aliases_csv: str = "",
    emotion: str = "normal",
    prefer_blush: bool = False,
) -> Optional[str]:
    idx = scan_local_assets(force=False)
    groups = idx.get("char_groups", [])
    if not groups:
        return None

    search_names = [_norm(char_name)]
    for al in (aliases_csv or "").split(","):
        nal = _norm(al)
        if nal and nal not in search_names:
            search_names.append(nal)

    matched_groups = []
    for g in groups:
        cb = g["char_base"]
        ft = g["folder_title"]
        if any(cb == nm or ft == nm for nm in search_names if nm):
            matched_groups.append((0, g))
        elif any(len(nm) >= 2 and (nm in cb or cb in nm) for nm in search_names if nm):
            matched_groups.append((1, g))

    if not matched_groups:
        return None
    matched_groups.sort(key=lambda x: (x[0], x[1]["is_variant"]))

    emo = (emotion or "normal").lower().strip()
    blush_int = 1 if (prefer_blush or emo == "blush") else 0
    emo_order = ["smile", "normal", "troubled", "blush"] if emo == "blush" else [emo, "normal", "smile", "other"]

    for _, grp in matched_groups:
        for cand_e in emo_order:
            for it in grp["items"]:
                if it["emo"] == cand_e and it["blush"] == blush_int and os.path.isfile(it["path"]):
                    return it["path"]
    for _, grp in matched_groups:
        for cand_e in emo_order:
            for it in grp["items"]:
                if it["emo"] == cand_e and os.path.isfile(it["path"]):
                    return it["path"]
    for _, grp in matched_groups:
        for it in grp["items"]:
            if os.path.isfile(it["path"]):
                return it["path"]
    return None


def resolve_local_background_path(bg_id: str = "", keyword: str = "", time_of_day: str = "") -> Optional[str]:
    idx = scan_local_assets(force=False)
    bgs = idx.get("backgrounds", [])
    if not bgs:
        return None

    if bg_id:
        for b in bgs:
            if b["bg_id"] == bg_id and os.path.isfile(b["path"]):
                return b["path"]

    kw = _norm(keyword)
    if kw:
        for b in bgs:
            if (kw in b["name"] or kw in b["tags"]) and (not time_of_day or time_of_day == "any" or b["time_of_day"] in (time_of_day, "any")):
                if os.path.isfile(b["path"]):
                    return b["path"]
        for b in bgs:
            if kw in b["name"] or kw in b["tags"]:
                if os.path.isfile(b["path"]):
                    return b["path"]

    for b in bgs:
        if os.path.isfile(b["path"]):
            return b["path"]
    return None


def resolve_local_se_path(se_id: str = "", keyword: str = "") -> Optional[str]:
    idx = scan_local_assets(force=False)
    ses = idx.get("sound_effects", [])
    if not ses:
        return None
    if se_id:
        for s in ses:
            if s["se_id"] == se_id and os.path.isfile(s["path"]):
                return s["path"]
    kw = _norm(keyword)
    if kw:
        for s in ses:
            if (kw in s["name"] or s["name"] in kw) and os.path.isfile(s["path"]):
                return s["path"]
    return None


_PSD_CACHE: Optional[Tuple[str, List[Dict[str, Any]]]] = None


def _resolve_psd_base_dir() -> str:
    root, p_dirs, _, _ = resolve_asset_directories()
    for d in p_dirs:
        if _norm(os.path.basename(d)) in ("はるか式立ち絵", "立ち絵"):
            return d
    cand = os.path.join(root, "はるか式立ち絵")
    if os.path.isdir(cand):
        return cand
    return p_dirs[-1] if p_dirs else root


def scan_local_psds(force_refresh: bool = False) -> Tuple[str, List[Dict[str, Any]]]:
    """内蔵『東方キャラ立絵スタジオ』用の高速PSDファイルスキャナー"""
    global _PSD_CACHE
    base_dir = _resolve_psd_base_dir()
    if not os.path.isdir(base_dir):
        return base_dir, []
    if not force_refresh and _PSD_CACHE is not None and _PSD_CACHE[0] == base_dir:
        return _PSD_CACHE

    skip_dirs = {"通常", "赤面", "表情", "パーツ", "差分"}
    found: List[Tuple[str, str, int]] = []

    def _walk_psd(cur: str, depth: int):
        if depth > 5:
            return
        try:
            entries = list(os.scandir(cur))
        except OSError:
            return
        psds = []
        subs = []
        for e in entries:
            if e.name.startswith("."):
                continue
            if e.is_file(follow_symlinks=True) and e.name.lower().endswith((".psd", ".psb")):
                psds.append(e)
            elif e.is_dir(follow_symlinks=True):
                subs.append(e)
        for pf in psds:
            try:
                sz = pf.stat().st_size
            except OSError:
                sz = 0
            found.append((pf.path, os.path.relpath(pf.path, base_dir), sz))
        for sd in subs:
            if psds and sd.name in skip_dirs:
                continue
            _walk_psd(sd.path, depth + 1)

    _walk_psd(base_dir, 0)
    out: List[Dict[str, Any]] = []
    for _, rel_p, sz in found:
        parts = rel_p.split(os.sep)
        fn = parts[-1]
        stem = os.path.splitext(fn)[0].strip()
        cat = re.split(r"[(（]", parts[0], maxsplit=1)[0].strip() if len(parts) >= 3 else "東方Project"
        folder_nm = parts[1] if len(parts) >= 3 else (parts[0] if len(parts) == 2 else stem)
        m = re.match(r"^(.+?)[(（](.+)[)）]$", folder_nm.strip())
        cname = m.group(1).strip() if m else folder_nm.strip()
        var = m.group(2).strip() if m else "通常"
        out.append({
            "category": cat or "東方Project",
            "name": cname,
            "variation": var,
            "filename": fn,
            "rel_path": rel_p,
            "size": sz,
            "size_str": f"{sz / (1024 * 1024):.1f} MB" if sz >= 1024 * 1024 else f"{sz / 1024:.0f} KB",
            "search_keywords": _norm(f"{cat} {cname} {var} {stem}").lower(),
        })
    out.sort(key=lambda x: (x["category"], x["name"], x["variation"]))
    _PSD_CACHE = (base_dir, out)
    return base_dir, out


def _pick_folder_native(prompt_title: str = "素材フォルダを選択") -> Optional[str]:
    sys_name = platform.system()
    try:
        if sys_name == "Darwin":
            res = subprocess.run(
                ["osascript", "-e", f'POSIX path of (choose folder with prompt "{prompt_title}")'],
                capture_output=True, text=True, timeout=120,
            )
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.strip()
        elif sys_name == "Windows":
            ps_cmd = (
                "Add-Type -AssemblyName System.Windows.Forms; "
                "$f = New-Object System.Windows.Forms.FolderBrowserDialog; "
                f"$f.Description = '{prompt_title}'; "
                "if ($f.ShowDialog() -eq 'OK') { Write-Output $f.SelectedPath }"
            )
            res = subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd], capture_output=True, text=True, timeout=120)
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.strip()
        else:
            if shutil.which("zenity"):
                res = subprocess.run(["zenity", "--file-selection", "--directory", f"--title={prompt_title}"], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip():
                    return res.stdout.strip()
            if shutil.which("kdialog"):
                res = subprocess.run(["kdialog", "--getexistingdirectory", os.path.expanduser("~")], capture_output=True, text=True, timeout=120)
                if res.returncode == 0 and res.stdout.strip():
                    return res.stdout.strip()
    except Exception:
        pass
    return None


def _open_folder_in_os(folder_path: str) -> bool:
    if not folder_path or not os.path.isdir(folder_path):
        return False
    sys_name = platform.system()
    try:
        if sys_name == "Darwin":
            subprocess.Popen(["open", folder_path])
        elif sys_name == "Windows":
            os.startfile(folder_path)  # type: ignore[attr-defined]
        else:
            subprocess.Popen(["xdg-open", folder_path])
        return True
    except Exception:
        return False


# ==================== ローカルセーブ管理（一覧・途中再開・分岐・インポート/エクスポート） ====================

def _safe_id(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_\-]", "_", s or "")[:48] or "session_default"


def _build_session_meta_from_turn(session_id: str, turn_payload: Dict[str, Any], turn_count: int = 1) -> Dict[str, Any]:
    sc = turn_payload.get("scene") or {}
    setup = turn_payload.get("setup") or {}
    return {
        "session_id": session_id,
        "char_id": setup.get("char_id", ""),
        "char_name": sc.get("speaker_name", ""),
        "player_name": setup.get("player_name", ""),
        "player_kana": setup.get("player_kana", ""),
        "player_gender": setup.get("player_gender", "M"),
        "ai_mode": setup.get("ai_mode", "apikey"),
        "latest_turn": int(turn_payload.get("turn_index", 0)),
        "turn_count": turn_count,
        "affection": int(sc.get("affection", 0)),
        "relationship_stage": sc.get("relationship_stage", "出会い"),
        "active_personality_names": sc.get("active_personality_names", []),
        "personality_mode": sc.get("personality_mode", "auto"),
        "preview_dialogue": str(sc.get("dialogue", ""))[:54],
        "updated_at": turn_payload.get("saved_at") or time.strftime("%Y-%m-%dT%H:%M:%S"),
    }


def save_turn_to_disk(payload: Dict[str, Any]) -> Dict[str, Any]:
    session_id = _safe_id(payload.get("session_id", ""))
    turn_index = int(payload.get("turn_index", 0))
    sess_dir = os.path.join(SAVES_DIR, session_id)
    os.makedirs(sess_dir, exist_ok=True)

    wav_b64 = payload.pop("audio_wav_base64", "")
    wav_filename = f"turn_{turn_index:04d}.wav"
    if wav_b64:
        with open(os.path.join(sess_dir, wav_filename), "wb") as wf:
            wf.write(base64.b64decode(wav_b64))
        payload["saved_wav_file"] = wav_filename

    payload["saved_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    with open(os.path.join(sess_dir, f"turn_{turn_index:04d}.json"), "w", encoding="utf-8") as jf:
        json.dump(payload, jf, ensure_ascii=False, indent=2)

    turn_cnt = sum(1 for fn in os.listdir(sess_dir) if fn.startswith("turn_") and fn.endswith(".json"))
    meta = _build_session_meta_from_turn(session_id, payload, turn_count=turn_cnt)
    with open(os.path.join(sess_dir, "session_meta.json"), "w", encoding="utf-8") as mf:
        json.dump(meta, mf, ensure_ascii=False, indent=2)

    save_local_config({"last_session_id": session_id})
    return meta


def list_saved_sessions() -> List[Dict[str, Any]]:
    sessions = []
    if not os.path.exists(SAVES_DIR):
        return sessions
    for d in sorted(os.listdir(SAVES_DIR), reverse=True):
        sdir = os.path.join(SAVES_DIR, d)
        if not os.path.isdir(sdir):
            continue
        meta_p = os.path.join(sdir, "session_meta.json")
        meta: Optional[Dict[str, Any]] = None
        if os.path.isfile(meta_p):
            try:
                with open(meta_p, "r", encoding="utf-8") as f:
                    meta = json.load(f)
            except Exception:
                meta = None
        # 旧形式メタデータに対して最新ターンの性格・プレビュー情報を補完
        turn_files = sorted(fn for fn in os.listdir(sdir) if fn.startswith("turn_") and fn.endswith(".json"))
        if turn_files and (meta is None or "preview_dialogue" not in meta):
            try:
                with open(os.path.join(sdir, turn_files[-1]), "r", encoding="utf-8") as tf:
                    last_t = json.load(tf)
                enriched = _build_session_meta_from_turn(d, last_t, turn_count=len(turn_files))
                if meta:
                    enriched["updated_at"] = meta.get("updated_at") or enriched["updated_at"]
                meta = enriched
            except Exception:
                pass
        if meta:
            meta.setdefault("turn_count", len(turn_files))
            sessions.append(meta)
    sessions.sort(key=lambda x: x.get("updated_at", ""), reverse=True)
    return sessions


def load_session_turns(session_id: str) -> List[Dict[str, Any]]:
    sess_dir = os.path.join(SAVES_DIR, _safe_id(session_id))
    if not os.path.isdir(sess_dir):
        return []
    turns = []
    for fn in sorted(os.listdir(sess_dir)):
        if fn.startswith("turn_") and fn.endswith(".json"):
            try:
                with open(os.path.join(sess_dir, fn), "r", encoding="utf-8") as f:
                    t = json.load(f)
                sc = t.get("scene") or {}
                sc["stage_direction"] = _fallback_stage_direction(sc, turn_index=int(t.get("turn_index", 0)))
                t["scene"] = sc
                turns.append(t)
            except Exception:
                pass
    return turns


def rewind_or_branch_session(session_id: str, target_turn_index: int, branch: bool = False) -> Tuple[str, List[Dict[str, Any]]]:
    src_id = _safe_id(session_id)
    src_dir = os.path.join(SAVES_DIR, src_id)
    if not os.path.isdir(src_dir):
        return src_id, []

    dst_id = f"{src_id[:30]}_br{int(time.time()) % 100000}" if branch else src_id
    dst_dir = os.path.join(SAVES_DIR, dst_id)
    os.makedirs(dst_dir, exist_ok=True)

    for fn in sorted(os.listdir(src_dir)):
        m = re.match(r"^turn_(\d{4})\.(json|wav)$", fn)
        if not m:
            continue
        t_num = int(m.group(1))
        if branch:
            if t_num <= target_turn_index:
                shutil.copy2(os.path.join(src_dir, fn), os.path.join(dst_dir, fn))
        else:
            if t_num > target_turn_index:
                try:
                    os.remove(os.path.join(src_dir, fn))
                except OSError:
                    pass

    turns = load_session_turns(dst_id)
    if turns:
        meta = _build_session_meta_from_turn(dst_id, turns[-1], turn_count=len(turns))
        meta["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
        with open(os.path.join(dst_dir, "session_meta.json"), "w", encoding="utf-8") as mf:
            json.dump(meta, mf, ensure_ascii=False, indent=2)
        save_local_config({"last_session_id": dst_id})
    return dst_id, turns


def export_session_zip_bytes(session_id: str) -> Optional[bytes]:
    sid = _safe_id(session_id)
    sdir = os.path.join(SAVES_DIR, sid)
    if not os.path.isdir(sdir):
        return None
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for fn in sorted(os.listdir(sdir)):
            fp = os.path.join(sdir, fn)
            if os.path.isfile(fp) and (fn == "session_meta.json" or fn.startswith("turn_")):
                zf.write(fp, arcname=f"{sid}/{fn}")
    return buf.getvalue()


def import_save_archive(filename: str, data_b64: str) -> Dict[str, Any]:
    raw = base64.b64decode(data_b64)
    low_fn = (filename or "").lower()

    if low_fn.endswith(".zip"):
        with zipfile.ZipFile(io.BytesIO(raw), "r") as zf:
            names = [n for n in zf.namelist() if not n.endswith("/")]
            if not names:
                raise ValueError("ZIP内にセーブデータが含まれていません。")
            first_parts = names[0].replace("\\", "/").split("/")
            base_sid = _safe_id(first_parts[0] if len(first_parts) > 1 else os.path.splitext(os.path.basename(filename))[0])
            if os.path.exists(os.path.join(SAVES_DIR, base_sid)):
                base_sid = f"{base_sid[:34]}_imp{int(time.time()) % 10000}"
            out_dir = os.path.join(SAVES_DIR, base_sid)
            os.makedirs(out_dir, exist_ok=True)

            for member in names:
                leaf = os.path.basename(member.replace("\\", "/"))
                if leaf == "session_meta.json" or re.match(r"^turn_\d{4}\.(json|wav)$", leaf):
                    with open(os.path.join(out_dir, leaf), "wb") as out_f:
                        out_f.write(zf.read(member))

            turns = load_session_turns(base_sid)
            if not turns:
                shutil.rmtree(out_dir, ignore_errors=True)
                raise ValueError("有効な turn_*.json が見つかりませんでした。")
            meta = _build_session_meta_from_turn(base_sid, turns[-1], turn_count=len(turns))
            with open(os.path.join(out_dir, "session_meta.json"), "w", encoding="utf-8") as mf:
                json.dump(meta, mf, ensure_ascii=False, indent=2)
            return meta

    # 単一JSONセーブまたはセッションエクスポートJSONの読込
    parsed = json.loads(raw.decode("utf-8"))
    turns_list = parsed.get("turns") if isinstance(parsed, dict) and isinstance(parsed.get("turns"), list) else [parsed]
    base_sid = _safe_id((turns_list[-1].get("session_id") if turns_list else "") or f"sess_import_{int(time.time())}")
    if os.path.exists(os.path.join(SAVES_DIR, base_sid)):
        base_sid = f"{base_sid[:34]}_imp{int(time.time()) % 10000}"
    out_dir = os.path.join(SAVES_DIR, base_sid)
    os.makedirs(out_dir, exist_ok=True)
    for idx, t in enumerate(turns_list):
        if not isinstance(t, dict) or "scene" not in t:
            continue
        ti = int(t.get("turn_index", idx))
        t["session_id"] = base_sid
        with open(os.path.join(out_dir, f"turn_{ti:04d}.json"), "w", encoding="utf-8") as tf:
            json.dump(t, tf, ensure_ascii=False, indent=2)
    turns = load_session_turns(base_sid)
    if not turns:
        shutil.rmtree(out_dir, ignore_errors=True)
        raise ValueError("JSONセーブデータの形式が正しくありません。")
    meta = _build_session_meta_from_turn(base_sid, turns[-1], turn_count=len(turns))
    with open(os.path.join(out_dir, "session_meta.json"), "w", encoding="utf-8") as mf:
        json.dump(meta, mf, ensure_ascii=False, indent=2)
    return meta


# ==================== ローカルHTTPハンドラ ====================

class ClientLocalHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def log_message(self, format: str, *args: Any) -> None:
        pass

    def _send_json(self, data: Any, status: int = 200) -> None:
        raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _send_local_media(self, abs_path: Optional[str], fallback_mime: str = "image/png") -> None:
        if not abs_path or not os.path.isfile(abs_path):
            self.send_response(204)
            self.end_headers()
            return
        _, p_dirs, b_dirs, se_dirs = resolve_asset_directories()
        real_target = os.path.realpath(abs_path)
        allowed_roots = [os.path.realpath(d) for d in (p_dirs + b_dirs + se_dirs)]
        if not any(real_target == r or real_target.startswith(r + os.sep) for r in allowed_roots):
            self.send_error(403, "Forbidden path")
            return
        mime, _ = mimetypes.guess_type(real_target)
        with open(real_target, "rb") as f:
            raw = f.read()
        self.send_response(200)
        self.send_header("Content-Type", mime or fallback_mime)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "public, max-age=300")
        self.end_headers()
        self.wfile.write(raw)

    def _build_assets_summary(self, idx: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "assets_root_dir": idx["assets_root_dir"],
            "portrait_dirs": idx["portrait_dirs"],
            "background_dirs": idx["background_dirs"],
            "se_dirs": idx.get("se_dirs", []),
            "char_group_count": idx["char_group_count"],
            "portrait_file_count": idx["portrait_file_count"],
            "background_count": idx["background_count"],
            "se_count": idx.get("se_count", 0),
            "backgrounds": [
                {"bg_id": b["bg_id"], "name": b["name"], "tags": b["tags"], "time_of_day": b["time_of_day"]}
                for b in idx["backgrounds"][:120]
            ],
            "sound_effects": [
                {"se_id": s["se_id"], "name": s["name"], "tags": s["tags"]}
                for s in idx.get("sound_effects", [])[:60]
            ],
        }

    def do_GET(self):
        global _LAST_CLIENT_PING, _CLIENT_SEEN_ONCE
        _LAST_CLIENT_PING = time.time()
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path == "/local/ping":
            _CLIENT_SEEN_ONCE = True
            self._send_json({"ok": True})
            return

        if path == "/local/verify":
            _CLIENT_SEEN_ONCE = True
            self._send_json(verify_client_integrity())
            return

        if path == "/local/config":
            _CLIENT_SEEN_ONCE = True
            cfg = load_local_config()
            idx = scan_local_assets(force=False)
            self._send_json({
                "server_url": cfg["server_url"],
                "session_token": cfg["session_token"],
                "has_local_gemini_key": bool(cfg.get("user_gemini_api_key")),
                "user_gemini_api_key": cfg.get("user_gemini_api_key", ""),
                "voice_enabled": bool(cfg.get("voice_enabled", True)),
                "se_enabled": bool(cfg.get("se_enabled", True)),
                "se_volume": float(cfg.get("se_volume", 0.8)),
                "auto_bg_generation": bool(cfg.get("auto_bg_generation", True)),
                "char_color_profiles": cfg.get("char_color_profiles") or {},
                "assets_root_dir": cfg.get("assets_root_dir", DEFAULT_USER_ASSETS_DIR),
                "portraits_dir_override": cfg.get("portraits_dir_override", ""),
                "backgrounds_dir_override": cfg.get("backgrounds_dir_override", ""),
                "se_dir_override": cfg.get("se_dir_override", ""),
                "has_stage_studio": _HAS_STAGE_STUDIO,
                "assets_summary": self._build_assets_summary(idx),
                "pending_purchase": cfg.get("pending_purchase"),
                "last_session_id": cfg.get("last_session_id", ""),
                "saved_sessions": list_saved_sessions(),
            })
            return

        if path == "/local/assets/status":
            force = qs.get("rescan", ["0"])[0] == "1"
            idx = scan_local_assets(force=force)
            self._send_json({"ok": True, **self._build_assets_summary(idx)})
            return

        if path == "/local/assets/portrait":
            char_name = qs.get("char_name", [""])[0]
            aliases = qs.get("aliases", [""])[0]
            emotion = qs.get("emotion", ["normal"])[0]
            blush = qs.get("blush", ["0"])[0] in ("1", "true")
            img_p = resolve_local_portrait_path(char_name=char_name, aliases_csv=aliases, emotion=emotion, prefer_blush=blush)
            if img_p and os.path.isfile(img_p):
                self._send_local_media(img_p, "image/png")
            else:
                svg_raw = generate_starter_portrait_svg(char_name=char_name, emotion=emotion, blush=blush)
                self.send_response(200)
                self.send_header("Content-Type", "image/svg+xml; charset=utf-8")
                self.send_header("Content-Length", str(len(svg_raw)))
                self.send_header("X-Starter-Fallback", "1")
                self.end_headers()
                self.wfile.write(svg_raw)
            return

        if path == "/local/assets/background":
            bg_id = qs.get("bg_id", [""])[0]
            keyword = qs.get("keyword", [""])[0]
            tod = qs.get("time_of_day", [""])[0]
            bg_p = resolve_local_background_path(bg_id=bg_id, keyword=keyword, time_of_day=tod)
            if bg_p and os.path.isfile(bg_p):
                self._send_local_media(bg_p, "image/jpeg")
            else:
                svg_bg = generate_starter_bg_svg(keyword=keyword or "幻想郷", time_of_day=tod or "day")
                self.send_response(200)
                self.send_header("Content-Type", "image/svg+xml; charset=utf-8")
                self.send_header("Content-Length", str(len(svg_bg)))
                self.send_header("X-Starter-Fallback", "1")
                self.end_headers()
                self.wfile.write(svg_bg)
            return

        # 内蔵『東方キャラ立絵スタジオ』用PSD一覧＆PSD配信API
        if path == "/api/characters":
            force_r = qs.get("refresh", ["0"])[0] in ("1", "true", "yes")
            base_d, chars = scan_local_psds(force_refresh=force_r)
            self._send_json({
                "success": True,
                "count": len(chars),
                "characters": chars,
                "characters_dir": base_d,
                "export_dir": TACHIE_EXPORT_DIR,
            })
            return

        if path == "/api/psd_file":
            rel_p = qs.get("path", [""])[0]
            base_d, _ = scan_local_psds(force_refresh=False)
            base_real = os.path.realpath(base_d)
            cand_real = os.path.realpath(os.path.join(base_d, rel_p))
            if not rel_p or not (cand_real == base_real or cand_real.startswith(base_real + os.sep)) or not os.path.isfile(cand_real):
                self.send_error(404, "PSD not found")
                return
            fsz = os.path.getsize(cand_real)
            self.send_response(200)
            self.send_header("Content-Type", "image/vnd.adobe.photoshop")
            self.send_header("Content-Length", str(fsz))
            self.send_header("Cache-Control", "public, max-age=1800")
            self.end_headers()
            with open(cand_real, "rb") as pf:
                shutil.copyfileobj(pf, self.wfile, length=262144)
            return

        # スタンドアロン即実行用カタログAPI（サーバー未起動PCでもダウンロード直後に動作）
        if path == "/local/standalone_api/catalog":
            self._send_json(load_standalone_catalog())
            return

        if path == "/local/assets/se":
            se_id = qs.get("se_id", [""])[0]
            keyword = qs.get("keyword", [""])[0]
            se_p = resolve_local_se_path(se_id=se_id, keyword=keyword)
            self._send_local_media(se_p, "audio/wav")
            return

        if path == "/local/saves":
            sid = qs.get("session_id", [""])[0]
            if sid:
                self._send_json({"session_id": sid, "turns": load_session_turns(sid)})
            else:
                self._send_json({"sessions": list_saved_sessions()})
            return

        if path == "/local/saves/export":
            sid = _safe_id(qs.get("session_id", [""])[0])
            zbytes = export_session_zip_bytes(sid)
            if not zbytes:
                self.send_error(404, "Save session not found")
                return
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Disposition", f'attachment; filename="{sid}.zip"')
            self.send_header("Content-Length", str(len(zbytes)))
            self.end_headers()
            self.wfile.write(zbytes)
            return

        if path == "/local/save_audio":
            sid = _safe_id(qs.get("session_id", [""])[0])
            wav_fn = os.path.basename(qs.get("file", [""])[0])
            wav_p = os.path.join(SAVES_DIR, sid, wav_fn)
            if not os.path.isfile(wav_p):
                self.send_error(404, "Audio not found")
                return
            with open(wav_p, "rb") as wf:
                data = wf.read()
            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        super().do_GET()

    def do_POST(self):
        global _LAST_CLIENT_PING
        _LAST_CLIENT_PING = time.time()
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode("utf-8")) if length > 0 else {}

        if parsed.path == "/local/config":
            updated = save_local_config(body)
            if any(k in body for k in ("assets_root_dir", "portraits_dir_override", "backgrounds_dir_override", "se_dir_override")):
                scan_local_assets(force=True)
            self._send_json({"ok": True, "has_local_gemini_key": bool(updated.get("user_gemini_api_key"))})
            return

        if parsed.path == "/local/assets/pick_folder":
            chosen = _pick_folder_native(str(body.get("prompt", "立ち絵・背景・効果音が配置されたフォルダを選択")))
            self._send_json({"ok": bool(chosen), "path": chosen or ""})
            return

        if parsed.path == "/local/assets/open_folder":
            target = os.path.expanduser(str(body.get("path") or load_local_config().get("assets_root_dir") or DEFAULT_USER_ASSETS_DIR))
            os.makedirs(target, exist_ok=True)
            opened = _open_folder_in_os(target)
            self._send_json({"ok": opened, "path": target})
            return

        if parsed.path == "/local/assets/save_generated_bg":
            bg_id = _safe_id(str(body.get("bg_id", f"gen_{int(time.time())}")))
            name = _norm(str(body.get("name", "AI生成背景")))
            b64_img = str(body.get("image_webp_base64", ""))
            if not b64_img:
                self._send_json({"ok": False, "error": "No image data"}, status=400)
                return
            out_fn = f"{bg_id}_{re.sub(r'[^0-9A-Za-zぁ-んァ-ヶ一-龠々ー_-]', '', name)[:24] or 'bg'}.webp"
            if str(body.get("ext", "")).lower() == "svg":
                out_fn = out_fn.replace(".webp", ".svg")
            out_p = os.path.join(GENERATED_BG_LOCAL_DIR, out_fn)
            with open(out_p, "wb") as bf:
                bf.write(base64.b64decode(b64_img))
            idx = scan_local_assets(force=True)
            saved_entry = next((b for b in idx["backgrounds"] if b["path"] == out_p), None)
            self._send_json({"ok": True, "background": saved_entry or {"bg_id": bg_id, "name": name}})
            return

        # 内蔵『東方キャラ立絵スタジオ』保存・反映API
        if parsed.path == "/api/save_export":
            fn = os.path.basename(str(body.get("filename") or "export.png")).strip() or "export.png"
            d_b64 = str(body.get("data") or "")
            if "," in d_b64:
                d_b64 = d_b64.split(",", 1)[1]
            sub = re.sub(r'[\\/:*?"<>|]', "", str(body.get("subfolder") or "")).strip()
            tdir = os.path.join(TACHIE_EXPORT_DIR, sub) if sub and sub not in (".", "..") else TACHIE_EXPORT_DIR
            os.makedirs(tdir, exist_ok=True)
            tp = os.path.join(tdir, fn)
            raw_b = base64.b64decode(d_b64)
            with open(tp, "wb") as ef:
                ef.write(raw_b)
            self._send_json({"success": True, "saved_path": tp, "filename": fn, "size": len(raw_b)})
            return

        if parsed.path == "/api/open_export_dir":
            _open_folder_in_os(TACHIE_EXPORT_DIR)
            self._send_json({"success": True, "export_dir": TACHIE_EXPORT_DIR})
            return

        if parsed.path == "/local/tachie/register_portraits":
            cname = re.sub(r'[\\/:*?"<>|]', "", _norm(str(body.get("char_name") or "カスタムキャラ")))[:40] or "カスタムキャラ"
            items = body.get("items") or []
            cdir = os.path.join(CUSTOM_PORTRAITS_DIR, cname)
            os.makedirs(cdir, exist_ok=True)
            saved_cnt = 0
            for it in items[:16]:
                fn = os.path.basename(str(it.get("filename") or "normal(普通).png"))
                durl = str(it.get("data_url") or "")
                if "," in durl:
                    durl = durl.split(",", 1)[1]
                if durl:
                    with open(os.path.join(cdir, fn), "wb") as pf:
                        pf.write(base64.b64decode(durl))
                    saved_cnt += 1
            idx = scan_local_assets(force=True)
            self._send_json({"ok": True, "char_name": cname, "saved_count": saved_cnt, "portrait_file_count": idx["portrait_file_count"]})
            return

        if parsed.path == "/local/tachie/clear_portraits":
            cname = re.sub(r'[\\/:*?"<>|]', "", _norm(str(body.get("char_name") or "")))[:40]
            if cname:
                shutil.rmtree(os.path.join(CUSTOM_PORTRAITS_DIR, cname), ignore_errors=True)
                scan_local_assets(force=True)
            self._send_json({"ok": True})
            return

        # スタンドアロン対話・背景生成API（外部サーバーなしでの即実行をサポート）
        if parsed.path == "/local/standalone_api/validate_player":
            pnm = _norm(str(body.get("player_name") or ""))
            pkn = _norm(str(body.get("player_kana") or ""))
            if not pnm or not pkn:
                self._send_json({"ok": False, "message": "プレイヤー名と読み方を入力してください。"})
            else:
                self._send_json({"ok": True, "message": "OK"})
            return

        if parsed.path == "/local/standalone_api/game/start":
            self._send_json({"ok": True, "scene": standalone_start_scene(body), "user": None, "voice_pool": None})
            return

        if parsed.path == "/local/standalone_api/game/turn":
            if body.get("is_free_input") and (body.get("ai_mode") != "apikey" or not str(body.get("user_gemini_api_key") or "").strip()):
                self._send_json({"detail": "自由入力での会話は、ご自身のGemini APIキーを指定して利用している場合のみ使用できます。"}, status=403)
                return
            self._send_json({"ok": True, "scene": standalone_turn_scene(body), "user": None, "voice_pool": None})
            return

        if parsed.path == "/local/standalone_api/game/generate_background":
            meta, b64_img = standalone_generate_bg(
                scene_title=str(body.get("scene_title") or "幻想郷"),
                prompt_en=str(body.get("prompt_en") or ""),
                time_of_day=str(body.get("time_of_day") or "day"),
                dialogue_context=str(body.get("dialogue_context") or ""),
                api_key=str(body.get("user_gemini_api_key") or ""),
            )
            self._send_json({"ok": True, "background": meta, "image_webp_base64": b64_img, "user": None})
            return

        if parsed.path == "/local/save_turn":
            meta = save_turn_to_disk(body)
            self._send_json({"ok": True, "meta": meta})
            return

        if parsed.path == "/local/saves/rewind":
            sid = str(body.get("session_id", ""))
            tidx = int(body.get("turn_index", 0))
            branch = bool(body.get("branch", False))
            new_sid, turns = rewind_or_branch_session(sid, tidx, branch=branch)
            self._send_json({"ok": True, "session_id": new_sid, "turns": turns, "sessions": list_saved_sessions()})
            return

        if parsed.path == "/local/saves/delete":
            sid = _safe_id(str(body.get("session_id", "")))
            sdir = os.path.join(SAVES_DIR, sid)
            if os.path.isdir(sdir):
                shutil.rmtree(sdir, ignore_errors=True)
            self._send_json({"ok": True, "sessions": list_saved_sessions()})
            return

        if parsed.path == "/local/saves/import":
            try:
                meta = import_save_archive(str(body.get("filename", "save.json")), str(body.get("data_base64", "")))
                self._send_json({"ok": True, "meta": meta, "sessions": list_saved_sessions()})
            except Exception as exc:
                self._send_json({"ok": False, "error": str(exc)}, status=400)
            return

        if parsed.path == "/local/saves/update_personality":
            sid = _safe_id(str(body.get("session_id", "")))
            tidx = int(body.get("turn_index", 0))
            tp = os.path.join(SAVES_DIR, sid, f"turn_{tidx:04d}.json")
            if os.path.isfile(tp):
                try:
                    with open(tp, "r", encoding="utf-8") as f:
                        tdata = json.load(f)
                    sc = tdata.setdefault("scene", {})
                    for k in ("active_personality_ids", "active_personality_names", "personality_mode", "pinned_personality_ids", "custom_personality_note"):
                        if k in body:
                            sc[k] = body[k]
                    with open(tp, "w", encoding="utf-8") as f:
                        json.dump(tdata, f, ensure_ascii=False, indent=2)
                    meta = _build_session_meta_from_turn(sid, tdata, turn_count=len(load_session_turns(sid)))
                    with open(os.path.join(SAVES_DIR, sid, "session_meta.json"), "w", encoding="utf-8") as mf:
                        json.dump(meta, mf, ensure_ascii=False, indent=2)
                except Exception:
                    pass
            self._send_json({"ok": True})
            return

        if parsed.path == "/local/open_stage_studio":
            studio_script = os.path.join(_STAGE_STUDIO_CANDIDATE, "stage_director_server.py")
            if os.path.isfile(studio_script):
                subprocess.Popen(
                    [sys.executable, studio_script],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                self._send_json({"ok": True})
            else:
                self._send_json({"ok": False, "error": "キャラステージ演出メーカーが見つかりません"}, status=404)
            return

        if parsed.path == "/local/open_external":
            target_url = str(body.get("url", "")).strip()
            if target_url.startswith(("http://", "https://")):
                webbrowser.open(target_url)
                self._send_json({"ok": True})
            else:
                self._send_json({"ok": False, "error": "Invalid URL"}, status=400)
            return

        self.send_error(404, "Not found")


def _find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _probe_existing_client() -> Optional[str]:
    if not os.path.isfile(INSTANCE_LOCK_FILE):
        return None
    try:
        with open(INSTANCE_LOCK_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        port = int(data.get("port", 0))
        if port > 0:
            with socket.create_connection(("127.0.0.1", port), timeout=0.25):
                return f"http://127.0.0.1:{port}/index.html"
    except Exception:
        pass
    return None


def _launch_app_window(url: str) -> None:
    sys_name = platform.system()
    candidates: List[List[str]] = []
    autoplay_flag = "--autoplay-policy=no-user-gesture-required"
    if sys_name == "Darwin":
        candidates = [
            ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", f"--app={url}", autoplay_flag],
            ["/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge", f"--app={url}", autoplay_flag],
            ["/Applications/Brave Browser.app/Contents/MacOS/Brave Browser", f"--app={url}", autoplay_flag],
        ]
    elif sys_name == "Windows":
        pf = os.environ.get("PROGRAMFILES", r"C:\Program Files")
        pf86 = os.environ.get("PROGRAMFILES(X86)", r"C:\Program Files (x86)")
        candidates = [
            [os.path.join(pf, r"Google\Chrome\Application\chrome.exe"), f"--app={url}", autoplay_flag],
            [os.path.join(pf86, r"Microsoft\Edge\Application\msedge.exe"), f"--app={url}", autoplay_flag],
        ]
    else:
        for b in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "microsoft-edge"):
            p = shutil.which(b)
            if p:
                candidates.append([p, f"--app={url}", "--window-size=1280,720", autoplay_flag])

    env = os.environ.copy()
    if sys_name == "Linux":
        if not env.get("DISPLAY"):
            env["DISPLAY"] = ":10.0" if os.path.exists("/tmp/.X11-unix/X10") else ":0"
        uid = os.getuid() if hasattr(os, "getuid") else 1000
        if not env.get("XDG_RUNTIME_DIR") and os.path.exists(f"/run/user/{uid}"):
            env["XDG_RUNTIME_DIR"] = f"/run/user/{uid}"
        if not env.get("DBUS_SESSION_BUS_ADDRESS") and os.path.exists(f"/run/user/{uid}/bus"):
            env["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path=/run/user/{uid}/bus"

    for cmd in candidates:
        if os.path.exists(cmd[0]):
            try:
                subprocess.Popen(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                pass
    webbrowser.open(url)


def main() -> None:
    if "--generate-manifest" in sys.argv:
        files_to_hash = [
            "renai_client.py",
            "standalone_engine.py",
            "web/index.html",
            "web/styles.css",
            "web/stage_fx.css",
            "web/stage_fx.js",
            "web/tachie_color_live.js",
            "web/app.js",
        ]
        manifest = {"version": "1.3.0", "files": {rp: _sha256_file(os.path.join(CLIENT_DIR, rp)) for rp in files_to_hash}}
        with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
        print(f"Generated {MANIFEST_FILE}")
        return

    try:
        os.nice(10)
    except Exception:
        pass

    # 既に起動中のクライアントがあれば重複プロセスを作らず既存ポートを再利用（メモリ節約）
    existing = _probe_existing_client()
    if existing and "--no-browser" not in sys.argv and len([a for a in sys.argv[1:] if a.isdigit()]) == 0:
        _launch_app_window(existing)
        return

    port = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else _find_free_port()
    srv = ThreadingHTTPServer(("127.0.0.1", port), ClientLocalHandler)
    url = f"http://127.0.0.1:{port}/index.html"

    try:
        with open(INSTANCE_LOCK_FILE, "w", encoding="utf-8") as lf:
            json.dump({"port": port, "pid": os.getpid()}, lf)
    except OSError:
        pass

    if "--keep-alive" not in sys.argv and "--no-browser" not in sys.argv:
        def _idle_reaper():
            while True:
                time.sleep(10.0)
                gc.collect()
                if _CLIENT_SEEN_ONCE and (time.time() - _LAST_CLIENT_PING > 32.0):
                    try:
                        os.remove(INSTANCE_LOCK_FILE)
                    except OSError:
                        pass
                    srv.shutdown()
                    return

        threading.Thread(target=_idle_reaper, daemon=True).start()

    print(f"東方Project恋愛シミュレーター クライアント起動: {url}")
    if "--no-browser" not in sys.argv:
        threading.Timer(0.35, _launch_app_window, args=(url,)).start()

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        try:
            os.remove(INSTANCE_LOCK_FILE)
        except OSError:
            pass
        srv.server_close()


if __name__ == "__main__":
    main()
