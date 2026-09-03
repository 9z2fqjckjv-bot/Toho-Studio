"""
東方Projectムービーメーカー - 軽量ローカル HTTP & REST API サーバー
- MacBook Neo に最適化された省メモリ・高速レスポンス設計
- 新規作成・データ読み込み・編集画面の全機能API
- プロジェクト管理、元ファイル直接参照、10分おき自動バックアップ
- Keynote / PowerPoint / YMM / FCPXML インポート & エクスポート
- クラッシュログ・レポート、YouTube 非公開動画直接投稿
"""

import os
import sys
import json
import time
import urllib.parse
import mimetypes
import threading
import traceback
from http.server import HTTPServer, SimpleHTTPRequestHandler
from typing import Dict, Any, Optional

from .core.character_db import CHARACTERS, VOICE_TYPES
from .core.tts_engine import get_tts_engine
from .core.keynote_parser import list_keynote_files, extract_slides_from_keynote, export_keynote_slide_images, export_keynote_media_refresh, slice_slides_from_movie, has_animation_instruction
from .core.powerpoint_parser import extract_slides_from_pptx
from .core.ymm_parser import parse_ymm_project
from .core.project_manager import get_project_manager
from .core.audio_video_merger import AudioVideoMerger
from .core.fcpxml_exporter import FCPXMLExporter
from .core.fcpxml_parser import FCPXMLParser
from .core.youtube_uploader import YouTubeUploader
from .core.crash_reporter import get_crash_reporter
from .core.path_utils import get_series_dir, get_media_dir

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WEB_DIR = os.path.join(os.path.dirname(__file__), "web")
# AUDIO_OUTPUT_DIR is now resolved dynamically
# VIDEO_OUTPUT_DIR is now resolved dynamically

# 書き出しステータス管理
_export_status = {
    "is_exporting": False,
    "progress_percent": 0,
    "current_stage": "",
    "processed_size": "0 MB",
    "total_size": "0 MB",
    "elapsed_sec": 0,
    "estimated_remain_sec": 0,
    "completed_at": "",
    "output_file": "",
    "error": None
}


class AppRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _send_json(self, data: Any, status: int = 200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def _send_error(self, message: str, status: int = 400):
        self._send_json({"success": False, "error": message}, status=status)

    def _read_body_json(self) -> Dict[str, Any]:
        content_len = int(self.headers.get("Content-Length", 0))
        if content_len == 0:
            return {}
        body_bytes = self.rfile.read(content_len)
        return json.loads(body_bytes.decode("utf-8"))

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        reporter = get_crash_reporter()
        reporter.log_activity(f"GET {path}")

        # 1. API エンドポイント
        if path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return

        elif path == "/api/config":
            tts = get_tts_engine()
            pm = get_project_manager()
            self._send_json({
                "app_name": "東方Projectムービーメーカー",
                "version": "2.0.0",
                "characters": CHARACTERS,
                "voice_types": VOICE_TYPES,
                "project_root": PROJECT_ROOT,
                "license_info": tts.get_license_info(),
                "current_project": pm.current_project,
                "current_project_path": pm.current_project_path
            })
            return

        elif path == "/api/files/browse":
            target_dir = query.get("dir", [PROJECT_ROOT])[0]
            if not os.path.exists(target_dir):
                target_dir = PROJECT_ROOT

            filter_exts = query.get("exts", [""])[0].split(",") if query.get("exts") else []
            filter_exts = [e.strip().lower() for e in filter_exts if e.strip()]

            items = []
            try:
                for entry in sorted(os.listdir(target_dir)):
                    # .DS_Store, ._ などのシステムファイルを除外 (要件8)
                    if entry.startswith("._") or entry == ".DS_Store" or entry == ".DS_Lite" or entry == ".git":
                        continue
                    full_p = os.path.join(target_dir, entry)
                    is_dir = os.path.isdir(full_p)
                    size = os.path.getsize(full_p) if not is_dir else 0
                    ext = os.path.splitext(entry)[1].lower() if not is_dir else ""
                    
                    is_matched = True
                    if filter_exts and not is_dir:
                        is_matched = (ext in filter_exts)

                    items.append({
                        "name": entry,
                        "path": full_p,
                        "is_dir": is_dir,
                        "size": size,
                        "extension": ext,
                        "is_matched": is_matched
                    })
            except Exception as e:
                self._send_error(f"Directory browse failed: {e}")
                return

            home_dir = os.path.expanduser("~")
            quick_locations = [
                {"name": "🏠 プロジェクトルート", "path": PROJECT_ROOT},
                {"name": "📁 交換夫婦", "path": get_series_dir("") if os.path.exists(get_series_dir("")) else PROJECT_ROOT},
                {"name": "📁 幼き日の夢", "path": os.path.join(PROJECT_ROOT, "幼き日の夢") if os.path.exists(os.path.join(PROJECT_ROOT, "幼き日の夢")) else PROJECT_ROOT},
                {"name": "🎬 動画用", "path": os.path.join(PROJECT_ROOT, "動画用") if os.path.exists(os.path.join(PROJECT_ROOT, "動画用")) else PROJECT_ROOT},
                {"name": "🖥️ デスクトップ", "path": os.path.join(home_dir, "Desktop") if os.path.exists(os.path.join(home_dir, "Desktop")) else home_dir},
            ]

            self._send_json({
                "success": True,
                "current_dir": target_dir,
                "parent_dir": os.path.dirname(target_dir) if target_dir != "/" else "/",
                "quick_locations": quick_locations,
                "items": items
            })
            return

        elif path == "/api/keynote_files":
            episodes = list_keynote_files()
            self._send_json({"success": True, "episodes": episodes})
            return

        elif path == "/api/project/backups":
            pm = get_project_manager()
            p_name = query.get("project_name", [None])[0]
            backups = pm.list_backups(p_name)
            self._send_json({"success": True, "backups": backups, "max_slots": 10})
            return

        elif path == "/api/crash_reports":
            reporter = get_crash_reporter()
            reports = reporter.list_reports()
            self._send_json({"success": True, "reports": reports})
            return

        elif path == "/api/export/status":
            global _export_status
            self._send_json({"success": True, "status": _export_status})
            return

        elif path == "/api/sound_effects":
            effects = AudioVideoMerger.list_sound_effects()
            self._send_json({"success": True, "effects": effects})
            return

        elif path.startswith("/media/"):
            rel_path = urllib.parse.unquote(path[len("/media/"):])
            full_p = None

            # 探索候補の順次チェック
            candidates = [
                rel_path,
                "/" + rel_path.lstrip("/"),
                os.path.join(PROJECT_ROOT, rel_path.lstrip("/")),
                os.path.join("/tmp", rel_path.lstrip("/"))
            ]
            for cand in candidates:
                if cand and os.path.exists(cand) and not os.path.isdir(cand):
                    full_p = cand
                    break

            if not full_p:
                self.send_error(404, f"File not found: {rel_path}")
                return

            mime_type, _ = mimetypes.guess_type(full_p)
            if not mime_type:
                if full_p.endswith(".mp4"):
                    mime_type = "video/mp4"
                elif full_p.endswith(".mov"):
                    mime_type = "video/quicktime"
                elif full_p.endswith(".wav"):
                    mime_type = "audio/wav"
                elif full_p.endswith(".mp3"):
                    mime_type = "audio/mpeg"
                else:
                    mime_type = "application/octet-stream"

            file_size = os.path.getsize(full_p)
            range_header = self.headers.get("Range")

            if range_header and range_header.startswith("bytes="):
                # HTTP 206 Partial Content (動画ストリーミング・シーク必須)
                ranges = range_header[6:].split("-")
                start = int(ranges[0]) if ranges[0] else 0
                end = int(ranges[1]) if len(ranges) > 1 and ranges[1] else (file_size - 1)
                start = max(0, min(start, file_size - 1))
                end = max(start, min(end, file_size - 1))
                content_length = end - start + 1

                self.send_response(206)
                self.send_header("Content-Type", mime_type)
                self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
                self.send_header("Content-Length", str(content_length))
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()

                with open(full_p, "rb") as f:
                    f.seek(start)
                    chunk_size = 64 * 1024
                    remaining = content_length
                    while remaining > 0:
                        read_bytes = min(chunk_size, remaining)
                        data = f.read(read_bytes)
                        if not data:
                            break
                        try:
                            self.wfile.write(data)
                        except (BrokenPipeError, ConnectionResetError):
                            break
                        remaining -= len(data)
                return
            else:
                self.send_response(200)
                self.send_header("Content-Type", mime_type)
                self.send_header("Content-Length", str(file_size))
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                with open(full_p, "rb") as f:
                    chunk_size = 64 * 1024
                    while True:
                        data = f.read(chunk_size)
                        if not data:
                            break
                        try:
                            self.wfile.write(data)
                        except (BrokenPipeError, ConnectionResetError):
                            break
                return

        # 2. 静的ファイルの配信 (Web UI)
        return super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        reporter = get_crash_reporter()
        reporter.log_activity(f"POST {path}")

        try:
            req_data = self._read_body_json()
            pm = get_project_manager()
            tts = get_tts_engine()

            # 1. 新規プロジェクト作成 (空)
            if path == "/api/project/create":
                p_name = req_data.get("project_name", "新規プロジェクト")
                proj = pm.create_empty_project(p_name)
                self._send_json({"success": True, "project": proj})
                return

            # 2. プロジェクト保存 (.tpmproj)
            elif path == "/api/project/save":
                target_path = req_data.get("target_path")
                proj_data = req_data.get("project")
                if not target_path:
                    # デフォルトパス
                    p_name = proj_data.get("project_name", "untitled") if proj_data else "untitled"
                    target_path = os.path.join(PROJECT_ROOT, f"{p_name}.tpmproj")

                res = pm.save_project(target_path, proj_data)
                self._send_json(res)
                return

            # 3. プロジェクト読み込み (.tpmproj / .json)
            elif path == "/api/project/load":
                file_path = req_data.get("file_path")
                if not file_path or not os.path.exists(file_path):
                    self._send_error("プロジェクトファイルが見つかりません。")
                    return
                res = pm.load_project(file_path)
                if res.get("success") and res.get("project"):
                    proj = res["project"]
                    p_name = proj.get("project_name", "")
                    movie_dir = get_media_dir(p_name, "スライドムービー")
                    cand_movie = os.path.join(movie_dir, f"{p_name}.mov")
                    if not proj.get("video_source") and os.path.exists(cand_movie) and os.path.getsize(cand_movie) > 10000:
                        proj["video_source"] = cand_movie

                    # ライセンスキーがあれば適用
                    lic = proj.get("license_info", {})
                    if lic:
                        tts.set_license_keys(
                            usr_license_id=lic.get("usr_license_id", lic.get("user_license_id", lic.get("license_id", ""))),
                            usr_key=lic.get("user_key", lic.get("usr_key", "")),
                            dev_license_id=lic.get("dev_license_id", lic.get("license_id", "")),
                            dev_key=lic.get("dev_key", "")
                        )
                self._send_json(res)
                return

            # 4. バックアップから復元
            elif path == "/api/project/restore_backup":
                backup_path = req_data.get("backup_path")
                if not backup_path or not os.path.exists(backup_path):
                    self._send_error("バックアップファイルが見つかりません。")
                    return
                res = pm.load_project(backup_path)
                self._send_json(res)
                return

            # 4.5 バックアップ即時手動保存
            elif path == "/api/project/backup_now":
                proj_data = req_data.get("project")
                saved_p = pm.save_temporary_backup(proj_data)
                self._send_json({"success": bool(saved_p), "path": saved_p})
                return

            # 5. Keynote インポート & 台本抽出
            elif path == "/api/import/keynote":
                keynote_path = req_data.get("file_path")
                if not keynote_path or not os.path.exists(keynote_path):
                    self._send_error("Keynoteファイルが見つかりません。")
                    return

                slides = extract_slides_from_keynote(keynote_path)
                p_name = os.path.splitext(os.path.basename(keynote_path))[0]
                if not slides:
                    slides = [{
                        "slide_index": 1,
                        "text": p_name,
                        "notes": "",
                        "character": "操夢",
                        "voice": "imd1",
                        "speed": 100,
                        "pitch": 115,
                        "phonemes": tts.kanji2koe(p_name),
                        "extra_delay": 0.0,
                        "transition_delay": 0.0,
                        "audio_duration": 1.5,
                        "is_enabled": True
                    }]

                proj = pm.create_from_scenes(
                    project_name=p_name,
                    source_type="keynote",
                    source_path=keynote_path,
                    scenes=slides,
                    media_library=[{
                        "name": os.path.basename(keynote_path),
                        "path": keynote_path,
                        "type": "keynote"
                    }]
                )
                target_movie_path = os.path.join(get_media_dir(p_name, "スライドムービー"), f"{p_name}.mov")
                if os.path.exists(target_movie_path) and os.path.getsize(target_movie_path) > 10000:
                    proj["video_source"] = target_movie_path

                self._send_json({
                    "success": True,
                    "project": proj,
                    "slides_count": len(slides)
                })
                return

            # 6. PowerPoint (.pptx) インポート
            elif path == "/api/import/pptx":
                pptx_path = req_data.get("file_path")
                if not pptx_path or not os.path.exists(pptx_path):
                    self._send_error("PowerPointファイルが見つかりません。")
                    return

                slides = extract_slides_from_pptx(pptx_path)
                p_name = os.path.splitext(os.path.basename(pptx_path))[0]
                if not slides:
                    slides = [{
                        "slide_index": 1,
                        "text": p_name,
                        "notes": "",
                        "character": "操夢",
                        "voice": "imd1",
                        "speed": 100,
                        "pitch": 115,
                        "phonemes": tts.kanji2koe(p_name),
                        "extra_delay": 0.0,
                        "transition_delay": 0.0,
                        "audio_duration": 1.5,
                        "is_enabled": True
                    }]

                proj = pm.create_from_scenes(
                    project_name=p_name,
                    source_type="powerpoint",
                    source_path=pptx_path,
                    scenes=slides,
                    media_library=[{
                        "name": os.path.basename(pptx_path),
                        "path": pptx_path,
                        "type": "powerpoint"
                    }]
                )
                self._send_json({
                    "success": True,
                    "project": proj,
                    "slides_count": len(slides)
                })
                return

            # 7. YMM (.ymmp) インポート
            elif path == "/api/import/ymm":
                ymm_path = req_data.get("file_path")
                if not ymm_path or not os.path.exists(ymm_path):
                    self._send_error("YMMファイルが見つかりません。")
                    return

                scenes = parse_ymm_project(ymm_path)
                p_name = os.path.splitext(os.path.basename(ymm_path))[0]
                if not scenes:
                    scenes = [{
                        "slide_index": 1,
                        "text": p_name,
                        "notes": "",
                        "character": "操夢",
                        "voice": "imd1",
                        "speed": 100,
                        "pitch": 115,
                        "phonemes": tts.kanji2koe(p_name),
                        "extra_delay": 0.0,
                        "transition_delay": 0.0,
                        "audio_duration": 1.5,
                        "is_enabled": True
                    }]

                proj = pm.create_from_scenes(
                    project_name=p_name,
                    source_type="ymm",
                    source_path=ymm_path,
                    scenes=scenes,
                    media_library=[{
                        "name": os.path.basename(ymm_path),
                        "path": ymm_path,
                        "type": "ymm"
                    }]
                )
                self._send_json({
                    "success": True,
                    "project": proj,
                    "slides_count": len(scenes)
                })
                return

            # 8. Final Cut Pro (.fcpxml) インポート
            elif path == "/api/import/fcpxml":
                fcpxml_path = req_data.get("file_path")
                if not fcpxml_path or not os.path.exists(fcpxml_path):
                    self._send_error("Final Cut Pro XML ファイルが見つかりません。")
                    return

                res = FCPXMLParser.parse_fcpxml(fcpxml_path)
                if not res.get("success"):
                    self._send_error(res.get("error", "FCPXMLの読み込みに失敗しました。"))
                    return

                parsed_proj = res["project"]
                p_name = parsed_proj.get("project_name", os.path.splitext(os.path.basename(fcpxml_path))[0])
                scenes = parsed_proj.get("scenes", [])

                proj = pm.create_from_scenes(
                    project_name=p_name,
                    source_type="fcpxml",
                    source_path=fcpxml_path,
                    scenes=scenes,
                    media_library=[{
                        "name": os.path.basename(fcpxml_path),
                        "path": fcpxml_path,
                        "type": "fcpxml"
                    }]
                )
                self._send_json({
                    "success": True,
                    "project": proj,
                    "slides_count": len(scenes)
                })
                return

            # 9. ライセンスキー設定 (要件18)
            elif path == "/api/tts/license":
                usr_lic_id = req_data.get("usr_license_id", req_data.get("user_license_id", req_data.get("license_id", "")))
                dev_lic_id = req_data.get("dev_license_id", req_data.get("license_id", ""))
                usr_key = req_data.get("user_key", req_data.get("usr_key", ""))
                dev_key = req_data.get("dev_key", "")

                tts.set_license_keys(
                    usr_license_id=usr_lic_id,
                    usr_key=usr_key,
                    dev_license_id=dev_lic_id,
                    dev_key=dev_key
                )

                # 現在のプロジェクトにも保存
                if pm.current_project:
                    pm.current_project["license_info"] = {
                        "usr_license_id": usr_lic_id,
                        "user_license_id": usr_lic_id,
                        "user_key": usr_key,
                        "dev_license_id": dev_lic_id,
                        "dev_key": dev_key
                    }

                self._send_json({
                    "success": True,
                    "license_info": tts.get_license_info()
                })
                return

            # 9. 漢字仮名交じり文 -> 音声記号列 変換
            elif path == "/api/kanji2koe":
                text = req_data.get("text", "")
                flat = bool(req_data.get("flat", False))
                koe = tts.kanji2koe(text, flat=flat)
                self._send_json({"success": True, "phonemes": koe})
                return

            # 10. 単一セリフのリアルタイム試聴
            elif path == "/api/tts/preview":
                phonemes = req_data.get("phonemes", "")
                text = req_data.get("text", "")
                voice = req_data.get("voice", "f1")
                speed = int(req_data.get("speed", 100))
                pitch = int(req_data.get("pitch", 100))
                quality_enhance = bool(req_data.get("quality_enhance", True))
                effect = req_data.get("effect", "none")
                sound_effect = req_data.get("sound_effect", None)
                se_offset = float(req_data.get("se_offset", 0.0))

                if not text and not phonemes:
                    self._send_error("発声するセリフまたは音声記号列が空です。")
                    return

                # セリフと音声が一致するまで自動再生成を試行
                wav_bytes, dur, report = tts.synthesize_with_auto_retry(
                    text=text,
                    phonemes=phonemes,
                    voice=voice,
                    speed=speed,
                    pitch=pitch,
                    quality_enhance=quality_enhance,
                    effect=effect,
                    sound_effect=sound_effect,
                    se_offset=se_offset
                )
                if not wav_bytes:
                    self._send_error(f"音声合成に失敗しました ({report})。記号列や声種設定をご確認ください。")
                    return

                import base64
                b64_audio = base64.b64encode(wav_bytes).decode("ascii")
                data_uri = f"data:audio/wav;base64,{b64_audio}"

                import uuid
                preview_tmp = f"/tmp/toho_preview_{uuid.uuid4().hex}.wav"
                with open(preview_tmp, "wb") as f:
                    f.write(wav_bytes)

                self._send_json({
                    "success": True,
                    "duration": dur,
                    "report": report,
                    "audio_data_url": data_uri,
                    "preview_url": f"/media{preview_tmp}?t={os.path.getmtime(preview_tmp)}"
                })
                return

            # 11. 単一セリフの音声再生成・保存
            elif path == "/api/tts/generate_single":
                scene = req_data.get("scene")
                if not isinstance(scene, dict):
                    scene = {}
                project_name = req_data.get("project_name", "default")
                s_idx = scene.get("slide_index", 1)
                text = scene.get("text", "")
                koe = scene.get("phonemes", "")
                voice = scene.get("voice", "f1")
                speed = int(scene.get("speed", 100))
                pitch = int(scene.get("pitch", 100))
                quality_enhance = bool(scene.get("quality_enhance", req_data.get("quality_enhance", True)))
                effect = scene.get("effect", req_data.get("effect", "none"))
                sound_effect = scene.get("sound_effect", req_data.get("sound_effect", None))
                se_offset = float(scene.get("se_offset", req_data.get("se_offset", 0.0)))

                ep_audio_dir = os.path.join(get_media_dir(project_name, "音声"), project_name)
                os.makedirs(ep_audio_dir, exist_ok=True)
                wav_filename = f"slide_{s_idx:03d}.wav"
                out_wav = os.path.join(ep_audio_dir, wav_filename)

                # セリフと音声が一致するまで自動再生成を試行して保存
                ok, dur = tts.synthesize_to_file(
                    koe, out_wav, voice=voice, speed=speed, pitch=pitch,
                    quality_enhance=quality_enhance, effect=effect,
                    sound_effect=sound_effect, se_offset=se_offset,
                    text=text
                )

                if ok:
                    scene["audio_duration"] = dur
                    scene["audio_file"] = wav_filename
                    scene["audio_path"] = out_wav

                    # アニメーション指定の有無を判定 (ビルド・トランジション含む)
                    notes_str = str(scene.get("notes") or "")
                    text_str = str(scene.get("text") or "")
                    s_builds = scene.get("builds", [])
                    s_has_auto = bool(scene.get("transition_automatic") and float(scene.get("transition_delay") or 0.0) > 0)
                    is_anim = bool(scene.get("has_animation") or has_animation_instruction(notes_str, text_str, builds=s_builds, has_transition=s_has_auto))

                    if is_anim:
                        # 目標総表示時間 (target_duration) が指定されている場合、余白 (extra_delay) を自動拡張
                        target_dur = scene.get("target_duration")
                        if target_dur and target_dur > dur:
                            scene["extra_delay"] = round(target_dur - dur, 2)
                    else:
                        # 単純なセリフシーン: シーン長を音声長に完全一致（余白ゼロ）
                        scene["extra_delay"] = 0.0
                        scene["target_duration"] = None
                        scene["video_clip_path"] = None
                        scene["animation_path"] = None
                        scene["video_duration"] = None
                        scene["animation_duration"] = None
                        scene["has_animation"] = False

                    self._send_json({"success": True, "scene": scene, "audio_url": f"/media{out_wav}?t={time.time()}"})
                else:
                    self._send_error("セリフに一致する音声の生成に失敗しました。")
                return

            # 12. 音声一括生成
            elif path == "/api/tts/generate_all":
                scenes = req_data.get("scenes", [])
                if not isinstance(scenes, list):
                    scenes = []
                project_name = req_data.get("project_name", "default")
                quality_enhance = bool(req_data.get("quality_enhance", True))
                effect = req_data.get("effect", "none")

                ep_audio_dir = os.path.join(get_media_dir(project_name, "音声"), project_name)
                os.makedirs(ep_audio_dir, exist_ok=True)

                updated_scenes = []
                for s in scenes:
                    if not isinstance(s, dict):
                        continue
                    s_idx = s.get("slide_index", 1)
                    text = s.get("text", "")
                    koe = s.get("phonemes", "")
                    voice = s.get("voice", "f1")
                    speed = int(s.get("speed", 100))
                    pitch = int(s.get("pitch", 100))
                    is_no_voice = bool(s.get("no_voice", False) or s.get("is_skipped", False) or s.get("is_enabled") is False)
                    s_eff = s.get("effect", effect)
                    s_qual = s.get("quality_enhance", quality_enhance)
                    s_se = s.get("sound_effect", None)
                    s_offset = float(s.get("se_offset", 0.0))

                    wav_filename = f"slide_{s_idx:03d}.wav"
                    out_wav = os.path.join(ep_audio_dir, wav_filename)

                    dur = 0.0
                    if not is_no_voice and (text or koe):
                        ok, dur = tts.synthesize_to_file(
                            koe, out_wav, voice=voice, speed=speed, pitch=pitch,
                            quality_enhance=s_qual, effect=s_eff,
                            sound_effect=s_se, se_offset=s_offset,
                            text=text
                        )
                        if ok:
                            s["audio_duration"] = dur
                            s["audio_file"] = wav_filename
                            s["audio_path"] = out_wav

                            # アニメーション指定の有無を判定 (ビルド・トランジション含む)
                            s_notes = str(s.get("notes") or "")
                            s_text = str(s.get("text") or "")
                            s_builds = s.get("builds", [])
                            s_has_auto = bool(s.get("transition_automatic") and float(s.get("transition_delay") or 0.0) > 0)
                            s_is_anim = bool(s.get("has_animation") or has_animation_instruction(s_notes, s_text, builds=s_builds, has_transition=s_has_auto))

                            if s_is_anim:
                                # 目標総表示時間 (target_duration) が指定されている場合、余白 (extra_delay) を自動拡張
                                target_dur = s.get("target_duration")
                                if target_dur and target_dur > dur:
                                    s["extra_delay"] = round(target_dur - dur, 2)
                            else:
                                # 単純なセリフシーン: シーン長を音声長に完全一致（余白ゼロ）
                                s["extra_delay"] = 0.0
                                s["target_duration"] = None
                                s["video_clip_path"] = None
                                s["animation_path"] = None
                                s["video_duration"] = None
                                s["animation_duration"] = None
                                s["has_animation"] = False
                        else:
                            s["audio_duration"] = 0.0
                    else:
                        s["audio_duration"] = 0.0
                        s["audio_path"] = None

                    updated_scenes.append(s)

                self._send_json({
                    "success": True,
                    "scenes": updated_scenes,
                    "audio_dir": ep_audio_dir
                })
                return

            # 13. 動画エクスポート (MOV / MP4)
            elif path == "/api/export/video":
                global _export_status
                project_name = req_data.get("project_name", "untitled")
                format_type = req_data.get("format", "mp4").lower() # "mp4" or "mov"
                scenes = req_data.get("scenes", [])
                video_source = req_data.get("video_source")
                padding_delay = float(req_data.get("padding_delay", 0.5))
                effects = list(req_data.get("effects", []))
                timeline_data = req_data.get("timeline", {})
                bgm_info = req_data.get("bgm_info") or timeline_data.get("bgm")

                # ステータス初期化
                _export_status = {
                    "is_exporting": True,
                    "progress_percent": 10,
                    "current_stage": "オーディオタイムラインを結合中...",
                    "processed_size": "10 MB",
                    "total_size": "100 MB",
                    "elapsed_sec": 0,
                    "estimated_remain_sec": 15,
                    "completed_at": "",
                    "output_file": "",
                    "error": None
                }

                def run_export_bg():
                    global _export_status
                    try:
                        ep_audio_dir = os.path.join(get_media_dir(project_name, "音声"), project_name)
                        slides_audio_info = []
                        slide_start_times = {}
                        current_timeline_time = 0.0

                        for s in scenes:
                            s_idx = s.get("slide_index") or (len(slides_audio_info) + 1)
                            a_path = s.get("audio_path") or os.path.join(ep_audio_dir, f"slide_{s_idx:03d}.wav")
                            dur = s.get("audio_duration", 0.0)
                            if dur == 0 and os.path.exists(a_path):
                                dur = get_tts_engine().get_wav_duration_file(a_path)

                            s_notes = str(s.get("notes") or "")
                            s_text = str(s.get("text") or "")
                            s_builds = s.get("builds", [])
                            s_has_auto = bool(s.get("transition_automatic") and float(s.get("transition_delay") or 0.0) > 0)
                            s_is_anim = bool(s.get("has_animation") or has_animation_instruction(s_notes, s_text, builds=s_builds, has_transition=s_has_auto))
                            extra_del = float(s.get("extra_delay", 0.0) or 0.0) if s_is_anim else 0.0
                            slide_start_times[s_idx] = current_timeline_time

                            slides_audio_info.append({
                                "slide_index": s_idx,
                                "audio_path": a_path,
                                "duration": dur,
                                "extra_delay": extra_del,
                                "is_enabled": s.get("is_enabled", True)
                            })

                            if s.get("is_enabled", True):
                                current_timeline_time += (dur + extra_del)

                        # 重複するすべての効果音 (SE) を集約
                        # 1. タイムライン上の複数区間連続SE (timeline.sound_effects)
                        tl_ses = timeline_data.get("sound_effects", [])
                        for tse in tl_ses:
                            st_idx = tse.get("start_scene_index", 1)
                            t_offset = slide_start_times.get(st_idx, 0.0)
                            effects.append({
                                "name": tse.get("name", "SE"),
                                "audio_path": tse.get("audio_path"),
                                "time_offset": t_offset,
                                "volume": tse.get("volume", 1.0),
                                "speed": tse.get("speed", 1.0),
                                "reverse": tse.get("reverse", False),
                                "loop": tse.get("loop", False)
                            })

                        # 2. 各シーン内の個別効果音 (scene.sound_effects または scene.sound_effect)
                        for s in scenes:
                            s_idx = s.get("slide_index") or 1
                            s_start = slide_start_times.get(s_idx, 0.0)

                            # 複数SE配列 (scene.sound_effects)
                            s_se_list = s.get("sound_effects", [])
                            if not s_se_list and s.get("sound_effect"):
                                s_se_list = [{
                                    "sound_effect": s.get("sound_effect"),
                                    "se_offset": s.get("se_offset", 0.0),
                                    "volume": s.get("se_volume", 1.0),
                                    "speed": s.get("se_speed", 1.0),
                                    "se_reverse": s.get("se_reverse", False)
                                }]

                            for se_item in s_se_list:
                                se_path = se_item.get("sound_effect") or se_item.get("audio_path")
                                if se_path:
                                    if not os.path.isabs(se_path):
                                        se_path = os.path.join(PROJECT_ROOT, se_path)
                                    se_off = float(se_item.get("se_offset", 0.0))
                                    effects.append({
                                        "name": os.path.basename(se_path),
                                        "audio_path": se_path,
                                        "time_offset": s_start + se_off,
                                        "volume": float(se_item.get("volume", 1.0)),
                                        "speed": float(se_item.get("speed", 1.0)),
                                        "reverse": bool(se_item.get("se_reverse", False))
                                    })

                        merged_wav = os.path.join(ep_audio_dir, "timeline_master.wav")
                        _export_status["progress_percent"] = 40
                        _export_status["current_stage"] = "効果音とBGMをミックス中..."

                        audio_res = AudioVideoMerger.build_timeline_audio(
                            slides_audio_info=slides_audio_info,
                            padding_delay=padding_delay,
                            effects=effects,
                            bgm_info=bgm_info,
                            out_wav_path=merged_wav
                        )

                        if not audio_res.get("success"):
                            _export_status["is_exporting"] = False
                            _export_status["error"] = audio_res.get("error")
                            return

                        _export_status["progress_percent"] = 70
                        _export_status["current_stage"] = f"動画をエンコード・書き出し中 ({format_type.upper()})..."

                        vid_out = get_media_dir(project_name, "完成動画")
                        os.makedirs(vid_out, exist_ok=True)
                        out_ext = ".mov" if format_type == "mov" else ".mp4"
                        out_video_path = os.path.join(vid_out, f"{project_name}_完成版{out_ext}")
                        current_video_source = video_source
                        if not current_video_source:
                            # プロジェクト名やスライドムービーから自動探索
                            movie_candidates = [
                                os.path.join(get_media_dir(project_name, "スライドムービー"), f"{project_name}.mov"),
                                os.path.join(get_media_dir(project_name, "スライドムービー"), f"{project_name}.mp4"),
                            ]
                            for mc in movie_candidates:
                                if os.path.exists(mc) and os.path.getsize(mc) > 10000:
                                    current_video_source = mc
                                    break

                        # 各スライドのアニメーション動画/スライド画像と音声を繋ぎ合わせて動画レンダリング
                        # (発表者ノートの時間指示・音声長に合わせて完全同期)
                        v_res = AudioVideoMerger.render_slides_to_video(
                            scenes=scenes,
                            output_video_path=out_video_path,
                            effects=effects,
                            bgm_info=bgm_info,
                            video_source=current_video_source
                        )

                        if not v_res.get("success"):
                            _export_status["is_exporting"] = False
                            _export_status["error"] = v_res.get("error", "動画のレンダリングに失敗しました。")
                            return

                        _export_status["is_exporting"] = False
                        _export_status["progress_percent"] = 100
                        _export_status["current_stage"] = "書き出し完了"
                        _export_status["completed_at"] = time.strftime("%H:%M:%S")
                        _export_status["output_file"] = out_video_path

                    except Exception as e:
                        _export_status["is_exporting"] = False
                        _export_status["error"] = str(e)

                threading.Thread(target=run_export_bg, daemon=True).start()
                self._send_json({"success": True, "message": "Export started in background"})
                return

            # 14. Final Cut Pro (FCPXML) 書き出し
            elif path == "/api/export/fcpxml":
                project_name = req_data.get("project_name", "untitled")
                scenes = req_data.get("scenes", [])
                sound_effects = req_data.get("sound_effects", req_data.get("timeline", {}).get("sound_effects", []))
                bgm = req_data.get("bgm", req_data.get("timeline", {}).get("bgm"))
                out_xml = os.path.join(PROJECT_ROOT, f"{project_name}.fcpxml")

                res = FCPXMLExporter.generate_fcpxml(
                    project_name=project_name,
                    scenes=scenes,
                    output_xml_path=out_xml,
                    sound_effects=sound_effects,
                    bgm=bgm
                )
                self._send_json(res)
                return

            # 15. YouTube 非公開直接投稿 (要件16)
            elif path == "/api/export/youtube":
                video_path = req_data.get("video_path")
                title = req_data.get("title", "東方Project動画")
                desc = req_data.get("description", "")
                tags = req_data.get("tags", [])
                auth_token = req_data.get("auth_token", "")

                res = YouTubeUploader.upload_private_video(
                    video_path=video_path,
                    title=title,
                    description=desc,
                    tags=tags,
                    auth_token=auth_token
                )
                self._send_json(res)
                return

            # 16. 既存の台本・音声設定を保持したままスライド画像のみ一括上書き
            elif path == "/api/project/update_slide_images":
                scenes = req_data.get("scenes", [])
                source_path = req_data.get("source_path", "")

                if not scenes:
                    self._send_error("プロジェクトのシーン情報が空です。")
                    return

                if not source_path or not os.path.exists(source_path):
                    self._send_error("指定されたファイルまたはフォルダが見つかりません。")
                    return

                images = []
                if source_path.endswith(".key"):
                    images = export_keynote_slide_images(source_path, force=True)
                elif os.path.isdir(source_path):
                    images = sorted([
                        os.path.join(source_path, f)
                        for f in os.listdir(source_path)
                        if f.lower().endswith(('.jpeg', '.jpg', '.png')) and not f.startswith('.')
                    ])
                elif source_path.lower().endswith(('.jpeg', '.jpg', '.png')):
                    parent_dir = os.path.dirname(source_path)
                    images = sorted([
                        os.path.join(parent_dir, f)
                        for f in os.listdir(parent_dir)
                        if f.lower().endswith(('.jpeg', '.jpg', '.png')) and not f.startswith('.')
                    ])

                if not images:
                    self._send_error("画像ファイルが見つかりませんでした。")
                    return

                updated_count = 0
                for idx, s in enumerate(scenes):
                    if not isinstance(s, dict):
                        continue
                    s_idx = s.get("slide_index", idx + 1)
                    matched_img = None
                    # 番号一致の探索 (例: .001.jpeg, _001.png, 1.jpg)
                    for img_p in images:
                        fn = os.path.basename(img_p)
                        if f".{s_idx:03d}." in fn or f"_{s_idx:03d}." in fn or f".{s_idx}." in fn or f"_{s_idx}." in fn or f"{s_idx:03d}" in fn:
                            matched_img = img_p
                            break

                    # インデックス順フォールバック
                    if not matched_img and idx < len(images):
                        matched_img = images[idx]

                    if matched_img:
                        s["image_path"] = matched_img
                        updated_count += 1

                self._send_json({
                    "success": True,
                    "scenes": scenes,
                    "updated_count": updated_count,
                    "total_images": len(images)
                })
                return

            # 17. 既存の台本・音声記号列・音声・SE/BGMを完全保持したままスライド画像 & スライドムービーを一括再生成
            elif path == "/api/project/refresh_media":
                raw_proj = req_data.get("project")
                proj_data = {}
                pm = get_project_manager()

                if isinstance(raw_proj, dict):
                    proj_data = raw_proj
                elif isinstance(raw_proj, str) and raw_proj.strip():
                    p_res = pm.load_project(raw_proj) if os.path.exists(raw_proj) else None
                    if p_res and p_res.get("success") and isinstance(p_res.get("project"), dict):
                        proj_data = p_res["project"]
                    elif isinstance(pm.current_project, dict):
                        proj_data = pm.current_project
                    else:
                        proj_data = {"project_name": raw_proj}
                elif isinstance(pm.current_project, dict):
                    proj_data = pm.current_project

                scenes = proj_data.get("scenes") if isinstance(proj_data, dict) else None
                if not isinstance(scenes, list):
                    scenes = req_data.get("scenes") if isinstance(req_data.get("scenes"), list) else []

                source_path = req_data.get("source_path") or (proj_data.get("source_path") if isinstance(proj_data, dict) else None)
                project_name = (proj_data.get("project_name") if isinstance(proj_data, dict) else None) or req_data.get("project_name", "")

                if not source_path:
                    # Keynoteファイルの自動探索
                    candidates = [
                        os.path.join(get_series_dir(project_name), f"{project_name}.key"),
                        os.path.join(get_series_dir(project_name), f"{project_name}.keynote"),
                    ]
                    for cand in candidates:
                        if os.path.exists(cand):
                            source_path = cand
                            break

                if not source_path or not os.path.exists(source_path):
                    self._send_error("元Keynoteファイルが見つかりません。")
                    return

                # Keynote から最新スライドメタデータ（アニメーション判定・画像・トランジション設定）を再取得
                new_slides = extract_slides_from_keynote(source_path)
                if not isinstance(new_slides, list):
                    new_slides = []
                p_name = project_name or os.path.splitext(os.path.basename(source_path))[0]
                video_source = os.path.join(get_media_dir(p_name, "スライドムービー"), f"{p_name}.mov")

                if os.path.exists(video_source) and isinstance(proj_data, dict):
                    proj_data["video_source"] = video_source

                # 既存のセリフ本文・音声設定・SE/BGMを完全保持しながら、全オブジェクトのメディア情報とアニメーション設定のみを最新同期
                updated_count = 0
                anim_count = 0
                obj_anim_counts = {"background": 0, "character": 0, "telop_frame": 0, "text": 0, "presenter_notes": 0}

                # slide_index ベースで最新メタデータをマップ
                new_slides_map = {s.get("slide_index"): s for s in new_slides if isinstance(s, dict)}

                for idx, s in enumerate(scenes):
                    if not isinstance(s, dict):
                        continue
                    s_idx = s.get("slide_index", idx + 1)
                    new_meta = new_slides_map.get(s_idx)

                    # 既存の音声ファイルが存在して未リンクの場合は自動バインド
                    if not s.get("audio_path"):
                        cand_aud = os.path.join(get_media_dir(p_name, "音声"), p_name, f"slide_{s_idx:03d}.wav")
                        if os.path.exists(cand_aud):
                            s["audio_path"] = cand_aud
                            try:
                                import wave
                                with wave.open(cand_aud, 'rb') as w:
                                    s["audio_duration"] = w.getnframes() / w.getframerate()
                            except:
                                pass

                    if isinstance(new_meta, dict):
                        if new_meta.get("image_path"):
                            s["image_path"] = new_meta["image_path"]
                            updated_count += 1

                        # アニメーション指定の有無を包括判定 (ビルド・トランジション含む)
                        notes_str = str(new_meta.get("notes") or s.get("notes") or "")
                        text_str = str(new_meta.get("text") or s.get("text") or "")
                        s_builds = new_meta.get("builds", [])
                        s_auto = bool(new_meta.get("transition_automatic") and float(new_meta.get("transition_delay") or 0.0) > 0)
                        has_anim = bool(new_meta.get("has_animation", False) or has_animation_instruction(notes_str, text_str, builds=s_builds, has_transition=s_auto))
                        s["has_animation"] = has_anim
                        s["builds"] = s_builds
                        s["transition_automatic"] = new_meta.get("transition_automatic", False)

                        if has_anim:
                            if new_meta.get("video_clip_path"):
                                s["video_clip_path"] = new_meta["video_clip_path"]
                                s["animation_path"] = new_meta.get("animation_path", new_meta["video_clip_path"])
                            if "video_start_time" in new_meta:
                                s["video_start_time"] = new_meta["video_start_time"]
                            if "video_duration" in new_meta:
                                s["video_duration"] = new_meta["video_duration"]
                                s["animation_duration"] = new_meta.get("animation_duration", new_meta["video_duration"])
                            s["target_duration"] = new_meta.get("target_duration")
                            s["is_animation_sync"] = new_meta.get("is_animation_sync", False)
                            s["extra_delay"] = new_meta.get("extra_delay", 0.0)
                        else:
                            s["video_clip_path"] = None
                            s["animation_path"] = None
                            s["video_duration"] = None
                            s["animation_duration"] = None
                            s["video_start_time"] = 0.0
                            s["target_duration"] = None
                            s["is_animation_sync"] = False
                            s["extra_delay"] = 0.0

                        s["animated_objects"] = new_meta.get("animated_objects", [])
                        s["animation_details"] = new_meta.get("animation_details", {})
                        s["character_images"] = new_meta.get("character_images", "")
                        s["bg_images"] = new_meta.get("bg_images", [])
                        s["telop_frame_detected"] = new_meta.get("telop_frame_detected", False)
                        s["transition_delay"] = new_meta.get("transition_delay", 0.0)
                        s["transition_duration"] = new_meta.get("transition_duration", 0.0)
                        s["transition_effect"] = new_meta.get("transition_effect", "no transition effect")
                        if s.get("has_animation"):
                            anim_count += 1
                            for obj_type in s.get("animated_objects", []):
                                if isinstance(obj_type, str) and obj_type in obj_anim_counts:
                                    obj_anim_counts[obj_type] += 1

                # アニメーションありと判定されたスライドのみ正確なタイムスタンプで動画クリップを切り出し
                if os.path.exists(video_source) and os.path.getsize(video_source) > 10000:
                    scenes = slice_slides_from_movie(video_source, scenes, p_name)

                if isinstance(proj_data, dict):
                    proj_data["scenes"] = scenes
                    save_target = proj_data.get("project_file_path")
                    if not save_target and project_name:
                        save_target = os.path.join(PROJECT_ROOT, f"{project_name}.tpmproj")
                    if save_target:
                        pm.save_project(save_target, proj_data)

                self._send_json({
                    "success": True,
                    "project": proj_data,
                    "scenes": scenes,
                    "video_source": video_source,
                    "updated_count": updated_count,
                    "anim_count": anim_count,
                    "obj_anim_counts": obj_anim_counts,
                    "total_slides": len(scenes)
                })
                return

            # 18. ディスク上のファイルからシーンの実測尺(duration)を再計算・同期
            elif path == "/api/project/sync_durations":
                scenes = req_data.get("scenes", [])
                project_name = req_data.get("project_name", "")

                updated_count = 0
                import wave
                import subprocess

                # プロジェクト名から暗黙パスのベースディレクトリを解決
                base_dir = os.path.dirname(os.path.abspath(__file__))
                repo_root = os.path.dirname(base_dir)
                project_video_dir = None
                project_audio_dir = None
                if project_name:
                    # スライド動画ディレクトリを探索
                    vid_base = os.path.join(get_series_dir(project_name), "スライド動画")
                    for sub in os.listdir(vid_base) if os.path.isdir(vid_base) else []:
                        if project_name in sub:
                            project_video_dir = os.path.join(vid_base, sub)
                            break
                    aud_base = os.path.join(get_series_dir(project_name), "音声")
                    for sub in os.listdir(aud_base) if os.path.isdir(aud_base) else []:
                        if project_name in sub:
                            project_audio_dir = os.path.join(aud_base, sub)
                            break

                for s in scenes:
                    if not isinstance(s, dict):
                        continue

                    changed = False
                    slide_idx = s.get("slide_index", 0)
                    snum = f"{int(slide_idx):03d}" if slide_idx else None

                    # --- 音声の実測時間同期 ---
                    audio_path = s.get("audio_path")
                    # 暗黙パスフォールバック
                    if not audio_path and snum and project_audio_dir:
                        implicit_a = os.path.join(project_audio_dir, f"slide_{snum}.wav")
                        if os.path.exists(implicit_a):
                            audio_path = implicit_a

                    if audio_path and os.path.exists(audio_path):
                        try:
                            with wave.open(audio_path, 'rb') as w:
                                frames = w.getnframes()
                                rate = w.getframerate()
                                dur = frames / float(rate)
                                if abs(s.get("audio_duration", 0) - dur) > 0.001:
                                    s["audio_duration"] = dur
                                    changed = True
                        except Exception:
                            pass

                    # --- 動画(アニメーション)の実測時間同期 (アニメーション演出があるシーンのみ) ---
                    notes_str = str(s.get("notes") or "")
                    text_str = str(s.get("text") or "")
                    s_builds = s.get("builds", [])
                    s_has_auto = bool(s.get("transition_automatic") and float(s.get("transition_delay") or 0.0) > 0)
                    is_anim = bool(s.get("has_animation") or has_animation_instruction(notes_str, text_str, builds=s_builds, has_transition=s_has_auto))

                    if is_anim:
                        vid_path = s.get("video_clip_path") or s.get("animation_path")
                        if not vid_path and snum and project_video_dir:
                            implicit_v = os.path.join(project_video_dir, f"slide_{snum}.mp4")
                            if os.path.exists(implicit_v):
                                vid_path = implicit_v

                        if vid_path and os.path.exists(vid_path):
                            try:
                                cmd_p = ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                                         "-of", "default=noprint_wrappers=1:nokey=1", vid_path]
                                r_p = subprocess.run(cmd_p, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=5)
                                if r_p.returncode == 0 and r_p.stdout.strip():
                                    vid_dur = float(r_p.stdout.strip())
                                    old_vid_dur = s.get("video_duration", 0) or 0
                                    if abs(old_vid_dur - vid_dur) > 0.01:
                                        s["video_duration"] = vid_dur
                                        s["animation_duration"] = vid_dur
                                        s["has_animation"] = True
                                        audio_dur = s.get("audio_duration") or 0
                                        if audio_dur > 0 and vid_dur > audio_dur:
                                            s["extra_delay"] = round(vid_dur - audio_dur, 4)
                                        changed = True
                            except Exception:
                                pass
                    else:
                        # アニメーション指示のないスライドは確実に画像モード・余白ゼロ（音声長に完全同期）
                        if s.get("video_clip_path") or s.get("has_animation") or s.get("video_duration") or s.get("extra_delay") or s.get("target_duration"):
                            s["video_clip_path"] = None
                            s["animation_path"] = None
                            s["video_duration"] = None
                            s["animation_duration"] = None
                            s["target_duration"] = None
                            s["extra_delay"] = 0.0
                            s["has_animation"] = False
                            changed = True

                    if changed:
                        updated_count += 1

                self._send_json({
                    "success": True,
                    "scenes": scenes,
                    "updated_count": updated_count
                })
                return

            else:
                self._send_error("API Endpoint not found", status=404)

        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as e:
            tb_str = traceback.format_exc()
            reporter = get_crash_reporter()
            rep_path = reporter.generate_report(f"Server API Exception: {e}", tb_str, {"path": path})
            try:
                self._send_error(f"Internal server error: {e} (Report: {os.path.basename(rep_path)})", status=500)
            except Exception:
                pass


def run_server(port: int = 8080):
    httpd = None
    actual_port = port
    for p in range(port, port + 20):
        try:
            server_address = ("127.0.0.1", p)
            httpd = HTTPServer(server_address, AppRequestHandler)
            actual_port = p
            break
        except OSError as oe:
            if oe.errno == 48:  # Address already in use
                continue
            raise

    if not httpd:
        raise OSError(f"利用可能なポートが見つかりませんでした (試行範囲: {port}-{port+19})")

    print(f"==================================================")
    print(f" 東方Projectムービーメーカー サーバー起動")
    print(f" URL: http://localhost:{actual_port}")
    print(f"==================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nサーバーを停止しました。")
        httpd.server_close()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run_server(port)
