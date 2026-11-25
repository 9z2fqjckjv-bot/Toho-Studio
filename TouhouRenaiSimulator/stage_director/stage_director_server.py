#!/usr/bin/env python3
"""
『キャラステージ演出メーカー』超省リソース単体スタジオサーバー (stage_director_server.py)
特徴:
  - Python標準ライブラリのみで動作（メモリ使用量 約18〜24MB・nice 15 低優先度）
  - 常駐デーモン化せず、アプリ起動中のみ稼働＆ウィンドウ終了後に自動スリープ終了（待機時メモリ0MB・CPU 0%）
  - シングルインスタンス機構により多重起動によるメモリ重複を完全防止
  - 『東方Project恋愛シミュレーター』のローカル素材・セーブデータ (~/.touhou_renai_simulator/saves) を直接読込・編集・通し再生可能
"""

import io
import os
import re
import sys
import json
import time
import shutil
import socket
import zipfile
import platform
import mimetypes
import threading
import subprocess
import webbrowser
import unicodedata
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse, parse_qs

STUDIO_DIR = os.path.abspath(os.path.dirname(__file__))
if STUDIO_DIR not in sys.path:
    sys.path.insert(0, STUDIO_DIR)

from stage_director_engine import (
    DATA_DIR,
    get_master_stage_catalog,
    normalize_stage_direction,
    save_custom_preset,
    delete_custom_preset,
)

WEB_DIR = os.path.join(STUDIO_DIR, "web")
DOC_ROOT = os.path.abspath(os.path.join(STUDIO_DIR, ".."))
RENAI_USER_DIR = os.path.join(os.path.expanduser("~"), ".touhou_renai_simulator")
SAVES_DIR = os.path.join(RENAI_USER_DIR, "saves")
INSTANCE_FILE = os.path.join(DATA_DIR, ".running_instance.json")

os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(os.path.join(RENAI_USER_DIR, "assets", "効果音"), exist_ok=True)
os.makedirs(os.path.join(DOC_ROOT, "効果音"), exist_ok=True)

_ASSET_CACHE: Optional[Dict[str, Any]] = None
_LAST_HEARTBEAT = time.time()
_CLIENT_CONNECTED_ONCE = False
_KEEP_ALIVE_DAEMON = "--daemon" in sys.argv


def _norm(s: str) -> str:
    return unicodedata.normalize("NFKC", s or "").strip()


def _safe_id(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_\-]", "_", s or "")[:48] or "session_default"


def _scan_studio_assets(force: bool = False) -> Dict[str, Any]:
    global _ASSET_CACHE
    if _ASSET_CACHE is not None and not force:
        return _ASSET_CACHE

    p_roots = [
        os.path.join(DOC_ROOT, "立ち絵作成ツール", "出力"),
        os.path.join(DOC_ROOT, "はるか式立ち絵"),
        os.path.join(RENAI_USER_DIR, "assets", "はるか式立ち絵"),
    ]
    b_roots = [
        os.path.join(DOC_ROOT, "背景"),
        os.path.join(RENAI_USER_DIR, "assets", "背景"),
        os.path.join(RENAI_USER_DIR, "generated_backgrounds"),
    ]
    se_roots = [
        os.path.join(DOC_ROOT, "効果音"),
        os.path.join(RENAI_USER_DIR, "assets", "効果音"),
    ]

    chars: List[Dict[str, Any]] = []
    seen_char_folders = set()
    for pr in p_roots:
        if not os.path.isdir(pr):
            continue
        for cur_root, _, files in os.walk(pr):
            imgs = sorted(f for f in files if not f.startswith(".") and f.lower().endswith((".png", ".webp")))
            if not imgs:
                continue
            rel = os.path.relpath(cur_root, pr)
            parts = [_norm(p) for p in rel.split(os.sep) if p and p != "."]
            char_name = parts[-2] if (len(parts) >= 2 and parts[-1] in ("通常", "赤面", "差分", "服ビリ")) else (parts[-1] if parts else "キャラ")
            if "ちび" in char_name or "やられ" in char_name:
                continue
            key = f"{char_name}:{parts[-1] if parts else ''}"
            if key in seen_char_folders:
                continue
            seen_char_folders.add(key)
            faces = []
            for fn in imgs[:24]:
                stem = _norm(os.path.splitext(fn)[0])
                m = re.search(r"[(（]([^)）]+)[)）]$", stem)
                faces.append({"label": m.group(1) if m else stem, "path": os.path.join(cur_root, fn)})
            chars.append({"name": char_name, "group": parts[-1] if parts else "標準", "faces": faces})

    chars.sort(key=lambda c: c["name"])

    bgs: List[Dict[str, Any]] = []
    for br in b_roots:
        if not os.path.isdir(br):
            continue
        for idx, fn in enumerate(sorted(os.listdir(br))):
            if fn.startswith(".") or not fn.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                continue
            full = os.path.join(br, fn)
            if os.path.isfile(full):
                stem = _norm(os.path.splitext(fn)[0]).replace("【背景素材】", "").strip()
                m_nc = re.match(r"^(nc\d+)[_＿]?(.*)$", stem)
                bg_id = m_nc.group(1) if m_nc else f"bg_{idx:04d}"
                bgs.append({"bg_id": bg_id, "name": (m_nc.group(2) if m_nc and m_nc.group(2) else stem) or fn, "path": full})

    local_ses: List[Dict[str, Any]] = []
    for sr in se_roots:
        if not os.path.isdir(sr):
            continue
        for idx, fn in enumerate(sorted(os.listdir(sr))):
            if fn.startswith(".") or not fn.lower().endswith((".wav", ".mp3", ".ogg", ".m4a", ".webm")):
                continue
            full = os.path.join(sr, fn)
            if os.path.isfile(full):
                stem = _norm(os.path.splitext(fn)[0])
                local_ses.append({"se_id": f"lse_{idx:03d}_{re.sub(r'[^0-9A-Za-z_]', '', stem)[:12]}", "name": stem, "path": full})

    _ASSET_CACHE = {
        "characters": chars,
        "backgrounds": bgs,
        "local_sound_effects": local_ses,
        "allowed_roots": [os.path.realpath(r) for r in (p_roots + b_roots + se_roots) if os.path.exists(r)],
    }
    return _ASSET_CACHE


def _list_saves() -> List[Dict[str, Any]]:
    out = []
    if not os.path.isdir(SAVES_DIR):
        return out
    for d in sorted(os.listdir(SAVES_DIR), reverse=True):
        mp = os.path.join(SAVES_DIR, d, "session_meta.json")
        if os.path.isfile(mp):
            try:
                with open(mp, "r", encoding="utf-8") as f:
                    out.append(json.load(f))
            except Exception:
                pass
    out.sort(key=lambda x: x.get("updated_at", ""), reverse=True)
    return out


def _load_save_session(session_id: str) -> List[Dict[str, Any]]:
    sdir = os.path.join(SAVES_DIR, _safe_id(session_id))
    if not os.path.isdir(sdir):
        return []
    idx = _scan_studio_assets()
    turns = []
    for fn in sorted(os.listdir(sdir)):
        if fn.startswith("turn_") and fn.endswith(".json"):
            try:
                with open(os.path.join(sdir, fn), "r", encoding="utf-8") as f:
                    t = json.load(f)
                sc = t.get("scene") or {}
                sc["stage_direction"] = normalize_stage_direction(
                    sc.get("stage_direction"),
                    emotion=sc.get("emotion", "normal"),
                    prefer_blush=bool(sc.get("prefer_blush")),
                    affection=int(sc.get("affection", 20)),
                    narration=sc.get("narration", ""),
                    dialogue=sc.get("dialogue", ""),
                    is_wedding=bool(sc.get("is_wedding_goal")),
                    turn_index=int(t.get("turn_index", 0)),
                    available_local_se=idx["local_sound_effects"],
                )
                t["scene"] = sc
                turns.append(t)
            except Exception:
                pass
    return turns


class StudioHandler(SimpleHTTPRequestHandler):
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

    def _send_file_checked(self, target_path: str, allowed_roots: List[str], default_mime: str = "application/octet-stream") -> None:
        if not target_path or not os.path.isfile(target_path):
            self.send_response(204)
            self.end_headers()
            return
        real = os.path.realpath(target_path)
        if not any(real == r or real.startswith(r + os.sep) for r in allowed_roots):
            self.send_error(403, "Forbidden")
            return
        mime, _ = mimetypes.guess_type(real)
        with open(real, "rb") as f:
            raw = f.read()
        self.send_response(200)
        self.send_header("Content-Type", mime or default_mime)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "public, max-age=300")
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        global _LAST_HEARTBEAT, _CLIENT_CONNECTED_ONCE
        _LAST_HEARTBEAT = time.time()
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path == "/api/ping":
            _CLIENT_CONNECTED_ONCE = True
            self._send_json({"ok": True, "pid": os.getpid()})
            return

        if parsed.path == "/api/bootstrap":
            _CLIENT_CONNECTED_ONCE = True
            idx = _scan_studio_assets(force=qs.get("rescan", ["0"])[0] == "1")
            self._send_json({
                "catalog": get_master_stage_catalog(),
                "characters": [
                    {"idx": i, "name": c["name"], "group": c["group"], "faces": [{"fidx": fi, "label": f["label"]} for fi, f in enumerate(c["faces"])]}
                    for i, c in enumerate(idx["characters"])
                ],
                "backgrounds": [{"idx": i, "bg_id": b["bg_id"], "name": b["name"]} for i, b in enumerate(idx["backgrounds"])],
                "local_sound_effects": [{"se_id": s["se_id"], "name": s["name"]} for s in idx["local_sound_effects"]],
                "saved_sessions": _list_saves(),
                "se_folders": [os.path.join(DOC_ROOT, "効果音"), os.path.join(RENAI_USER_DIR, "assets", "効果音")],
            })
            return

        if parsed.path == "/api/asset/portrait":
            idx = _scan_studio_assets()
            cidx = int(qs.get("cidx", ["0"])[0])
            fidx = int(qs.get("fidx", ["0"])[0])
            char_name = _norm(qs.get("char_name", [""])[0])
            emo = qs.get("emotion", ["normal"])[0]
            target = ""
            if char_name:
                for c in idx["characters"]:
                    if char_name in c["name"] or c["name"] in char_name:
                        target = c["faces"][0]["path"]
                        for f in c["faces"]:
                            if (emo == "smile" and "笑" in f["label"]) or (emo == "blush" and ("赤面" in f["label"] or "照" in f["label"])) or (emo == "angry" and "怒" in f["label"]) or (emo == "question" and ("疑問" in f["label"] or "？" in f["label"])):
                                target = f["path"]
                                break
                        break
            elif 0 <= cidx < len(idx["characters"]):
                faces = idx["characters"][cidx]["faces"]
                if 0 <= fidx < len(faces):
                    target = faces[fidx]["path"]
            self._send_file_checked(target, idx["allowed_roots"], "image/png")
            return

        if parsed.path == "/api/asset/bg":
            idx = _scan_studio_assets()
            bidx = int(qs.get("bidx", ["-1"])[0])
            bg_id = qs.get("bg_id", [""])[0]
            target = ""
            if bg_id:
                for b in idx["backgrounds"]:
                    if b["bg_id"] == bg_id:
                        target = b["path"]
                        break
            if not target and 0 <= bidx < len(idx["backgrounds"]):
                target = idx["backgrounds"][bidx]["path"]
            elif not target and idx["backgrounds"]:
                target = idx["backgrounds"][0]["path"]
            self._send_file_checked(target, idx["allowed_roots"], "image/jpeg")
            return

        if parsed.path == "/local/assets/se":
            idx = _scan_studio_assets()
            sid = qs.get("se_id", [""])[0]
            target = ""
            for s in idx["local_sound_effects"]:
                if s["se_id"] == sid:
                    target = s["path"]
                    break
            self._send_file_checked(target, idx["allowed_roots"], "audio/wav")
            return

        if parsed.path == "/api/saves/load":
            sid = qs.get("session_id", [""])[0]
            self._send_json({"session_id": sid, "turns": _load_save_session(sid)})
            return

        if parsed.path == "/api/saves/audio":
            sid = _safe_id(qs.get("session_id", [""])[0])
            fn = os.path.basename(qs.get("file", [""])[0])
            wav_p = os.path.join(SAVES_DIR, sid, fn)
            self._send_file_checked(wav_p, [os.path.realpath(SAVES_DIR)], "audio/wav")
            return

        super().do_GET()

    def do_POST(self):
        global _LAST_HEARTBEAT
        _LAST_HEARTBEAT = time.time()
        parsed = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length).decode("utf-8")) if length > 0 else {}

        if parsed.path == "/api/presets/save":
            presets = save_custom_preset(body)
            self._send_json({"ok": True, "custom_presets": presets})
            return

        if parsed.path == "/api/presets/delete":
            presets = delete_custom_preset(str(body.get("id", "")))
            self._send_json({"ok": True, "custom_presets": presets})
            return

        if parsed.path == "/api/saves/update_turn":
            sid = _safe_id(str(body.get("session_id", "")))
            tidx = int(body.get("turn_index", 0))
            tp = os.path.join(SAVES_DIR, sid, f"turn_{tidx:04d}.json")
            if not os.path.isfile(tp):
                self._send_json({"ok": False, "error": "Turn file not found"}, status=404)
                return
            with open(tp, "r", encoding="utf-8") as f:
                tdata = json.load(f)
            idx = _scan_studio_assets()
            tdata.setdefault("scene", {})["stage_direction"] = normalize_stage_direction(
                body.get("stage_direction") or {},
                available_local_se=idx["local_sound_effects"],
            )
            with open(tp, "w", encoding="utf-8") as f:
                json.dump(tdata, f, ensure_ascii=False, indent=2)
            self._send_json({"ok": True, "stage_direction": tdata["scene"]["stage_direction"]})
            return

        if parsed.path == "/api/open_se_folder":
            target = os.path.join(DOC_ROOT, "効果音")
            os.makedirs(target, exist_ok=True)
            try:
                if platform.system() == "Darwin":
                    subprocess.Popen(["open", target])
                elif platform.system() == "Windows":
                    os.startfile(target)  # type: ignore[attr-defined]
                else:
                    subprocess.Popen(["xdg-open", target])
            except Exception:
                pass
            self._send_json({"ok": True, "path": target})
            return

        self.send_error(404, "Not found")


def _find_free_port(preferred: int = 8092) -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.bind(("127.0.0.1", preferred))
            return preferred
        except OSError:
            s.bind(("127.0.0.1", 0))
            return s.getsockname()[1]


def _check_existing_instance() -> Optional[str]:
    if not os.path.isfile(INSTANCE_FILE):
        return None
    try:
        with open(INSTANCE_FILE, "r", encoding="utf-8") as f:
            info = json.load(f)
        port = int(info.get("port", 0))
        if port > 0:
            with socket.create_connection(("127.0.0.1", port), timeout=0.25):
                return f"http://127.0.0.1:{port}/index.html"
    except Exception:
        pass
    return None


def _launch_window(url: str) -> None:
    sys_name = platform.system()
    flag = "--autoplay-policy=no-user-gesture-required"
    candidates: List[List[str]] = []
    if sys_name == "Darwin":
        candidates = [["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", f"--app={url}", flag]]
    elif sys_name == "Windows":
        pf = os.environ.get("PROGRAMFILES", r"C:\Program Files")
        candidates = [[os.path.join(pf, r"Google\Chrome\Application\chrome.exe"), f"--app={url}", flag]]
    else:
        for b in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "microsoft-edge"):
            p = shutil.which(b)
            if p:
                candidates.append([p, f"--app={url}", "--window-size=1360,800", flag])

    env = os.environ.copy()
    if sys_name == "Linux" and not env.get("DISPLAY"):
        env["DISPLAY"] = ":10.0" if os.path.exists("/tmp/.X11-unix/X10") else ":0"

    for cmd in candidates:
        if os.path.exists(cmd[0]):
            try:
                subprocess.Popen(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                pass
    webbrowser.open(url)


def main() -> None:
    try:
        os.nice(15)
    except Exception:
        pass

    existing_url = _check_existing_instance()
    if existing_url and "--no-browser" not in sys.argv:
        _launch_window(existing_url)
        return

    port = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else _find_free_port(8092)
    srv = ThreadingHTTPServer(("127.0.0.1", port), StudioHandler)
    url = f"http://127.0.0.1:{port}/index.html"

    with open(INSTANCE_FILE, "w", encoding="utf-8") as f:
        json.dump({"port": port, "pid": os.getpid()}, f)

    if not _KEEP_ALIVE_DAEMON:
        def _idle_watchdog():
            while True:
                time.sleep(8.0)
                idle_sec = time.time() - _LAST_HEARTBEAT
                # クライアント接続後にウィンドウが閉じられて25秒間ハートビートが無ければ自動終了しメモリ0MBへ戻す
                if _CLIENT_CONNECTED_ONCE and idle_sec > 25.0:
                    try:
                        os.remove(INSTANCE_FILE)
                    except OSError:
                        pass
                    srv.shutdown()
                    return

        threading.Thread(target=_idle_watchdog, daemon=True).start()

    print(f"キャラステージ演出メーカー起動: {url}")
    if "--no-browser" not in sys.argv:
        threading.Timer(0.3, _launch_window, args=(url,)).start()

    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        try:
            os.remove(INSTANCE_FILE)
        except OSError:
            pass
        srv.server_close()


if __name__ == "__main__":
    main()
