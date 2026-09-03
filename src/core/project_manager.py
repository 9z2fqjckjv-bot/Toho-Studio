"""
東方Projectムービーメーカー - プロジェクトマネージャー
- .tpmproj プロジェクトファイルの保存・読み込み (JSONベース)
- 元ファイル直接参照管理 (コピーせずストレージ圧迫を防止)
- 10分おきの自動一時バックアップ (外部ストレージ切断対策)
- 外部ストレージ切断時のデータ保護・ローカル復元機構
- ライセンス情報のプロジェクト内保持
"""

import os
import sys
import json
import time
import shutil
import datetime
import subprocess
from typing import Dict, Any, Optional, List
from .path_utils import get_series_dir, get_media_dir

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOCAL_BACKUP_DIR = os.path.expanduser("~/.toho_project_movie_maker_backups")
INTERNAL_BACKUP_DIR = os.path.join(PROJECT_ROOT, ".toho_backups")
MAX_BACKUPS_PER_PROJECT = 10  # 最大10枠 (10分おき × 10世代 = 最大100分前まで巻き戻し可能)


class ProjectManager:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(ProjectManager, cls).__new__(cls)
            cls._instance._init_manager()
        return cls._instance

    def _init_manager(self):
        try:
            os.makedirs(LOCAL_BACKUP_DIR, exist_ok=True)
        except Exception:
            pass
        os.makedirs(INTERNAL_BACKUP_DIR, exist_ok=True)
        self.current_project: Optional[Dict[str, Any]] = None
        self.current_project_path: Optional[str] = None
        self.last_saved_time: float = time.time()
        self.last_backup_time: float = time.time()

    def create_empty_project(self, project_name: str = "新規プロジェクト") -> Dict[str, Any]:
        """新規の空編集プロジェクトを作成"""
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        initial_scene = {
            "slide_index": 1,
            "text": "新しいセリフ",
            "notes": "",
            "character": "操夢",
            "voice": "imd1",
            "speed": 100,
            "pitch": 115,
            "phonemes": "アタラシイセリフ",
            "extra_delay": 0.0,
            "transition_delay": 0.0,
            "audio_duration": 1.5,
            "audio_file": "slide_001.wav",
            "image_path": None,
            "audio_path": None,
            "video_clip_path": None,
            "animation_path": None,
            "is_enabled": True
        }
        self.current_project = {
            "format_version": "1.0",
            "project_name": project_name,
            "source_type": "blank",
            "source_path": "",
            "project_file_path": os.path.join(PROJECT_ROOT, f"{project_name}.tpmproj"),
            "series_name": os.path.basename(get_series_dir(project_name)),
            "created_at": now,
            "updated_at": now,
            "license_info": {
                "usr_license_id": "",
                "user_key": "",
                "dev_license_id": "",
                "dev_key": ""
            },
            "settings": {
                "padding_delay": 0.5,
                "auto_backup_enabled": True,
                "auto_backup_interval_min": 10,
                "quality_enhance": True,
                "effect": "none"
            },
            "scenes": [initial_scene],
            "media_library": [],
            "timeline": {
                "bgm": None,
                "global_effects": []
            }
        }
        self.current_project_path = self.current_project["project_file_path"]
        self.save_temporary_backup(self.current_project)
        return self.current_project

    def create_from_scenes(
        self,
        project_name: str,
        source_type: str,
        source_path: str,
        scenes: List[Dict[str, Any]],
        media_library: Optional[List[Dict[str, Any]]] = None,
        license_info: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """抽出されたシーン一覧からプロジェクトを作成"""
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self.current_project = {
            "format_version": "1.0",
            "project_name": project_name,
            "source_type": source_type,
            "source_path": source_path,
            "project_file_path": os.path.join(PROJECT_ROOT, f"{project_name}.tpmproj"),
            "series_name": os.path.basename(get_series_dir(project_name)),
            "created_at": now,
            "updated_at": now,
            "license_info": license_info or {
                "usr_license_id": "",
                "user_key": "",
                "dev_license_id": "",
                "dev_key": ""
            },
            "settings": {
                "padding_delay": 0.5,
                "auto_backup_enabled": True,
                "auto_backup_interval_min": 10,
                "quality_enhance": True,
                "effect": "none"
            },
            "scenes": scenes,
            "media_library": media_library or [],
            "timeline": {
                "bgm": None,
                "global_effects": []
            }
        }

        # Auto-link existing audio files
        audio_dir = os.path.join(get_media_dir(project_name, "音声"), project_name)
        for idx, sc in enumerate(self.current_project["scenes"]):
            s_idx = sc.get("slide_index", idx + 1)
            if not sc.get("audio_path"):
                cand_aud = os.path.join(audio_dir, f"slide_{s_idx:03d}.wav")
                if os.path.exists(cand_aud):
                    sc["audio_path"] = cand_aud
                    try:
                        import wave
                        with wave.open(cand_aud, 'rb') as w:
                            sc["audio_duration"] = w.getnframes() / w.getframerate()
                    except:
                        pass

        self.current_project_path = self.current_project["project_file_path"]
        # 作成時に即時ローカル安全一時バックアップを実行
        self.save_temporary_backup(self.current_project)
        return self.current_project

    def _relocate_path(self, old_path: Optional[str], project_name: str, sub_dir: str = "") -> Optional[str]:
        """旧パスが存在しない場合に現在の PROJECT_ROOT を基準に自動探索・再解決"""
        if not old_path or not isinstance(old_path, str):
            return None
        if os.path.exists(old_path):
            return old_path

        base_file = os.path.basename(old_path)
        # 探索候補
        candidates = [
            os.path.join(PROJECT_ROOT, base_file),
            os.path.join(PROJECT_ROOT, sub_dir, base_file) if sub_dir else None,
            os.path.join(get_series_dir(project_name), sub_dir, base_file) if sub_dir else None,
            os.path.join(get_series_dir(project_name), project_name, base_file),
            
            
            os.path.join(PROJECT_ROOT, "動画用", sub_dir, base_file) if sub_dir else None,
        ]
        for cand in candidates:
            if cand and os.path.exists(cand) and not os.path.isdir(cand):
                return cand
        return old_path

    def _relocate_project_media(self, data: Dict[str, Any], project_file_path: str) -> Dict[str, Any]:
        """プロジェクト内のメディアファイルパスを現在の環境に合わせて自動修復"""
        p_name = data.get("project_name", os.path.splitext(os.path.basename(project_file_path))[0])
        data["project_file_path"] = project_file_path
        data["series_name"] = os.path.basename(get_series_dir(p_name))

        # source_path の再解決
        if data.get("source_path") and not os.path.exists(data["source_path"]):
            s_base = os.path.basename(data["source_path"])
            for cand_dir in [PROJECT_ROOT, get_series_dir(p_name)]:
                cand_file = os.path.join(cand_dir, s_base)
                if os.path.exists(cand_file):
                    data["source_path"] = cand_file
                    break

        # video_source の再解決
        if data.get("video_source") and not os.path.exists(data["video_source"]):
            v_base = os.path.basename(data["video_source"])
            cand_v = os.path.join(get_media_dir(p_name, "スライドムービー"), v_base)
            if os.path.exists(cand_v):
                data["video_source"] = cand_v

        # 各シーンのメディアパス再解決 & 実測尺プローブ
        slide_img_dir = os.path.join(get_media_dir(p_name, "スライド画像"), p_name)
        slide_vid_dir = os.path.join(get_media_dir(p_name, "スライド動画"), p_name)
        audio_dir = os.path.join(get_media_dir(p_name, "音声"), p_name)

        # 動画長キャッシュ (重複ffprobe回避)
        _video_dur_cache: Dict[str, float] = {}
        ffprobe_bin = "/opt/homebrew/bin/ffprobe" if os.path.exists("/opt/homebrew/bin/ffprobe") else ("/usr/local/bin/ffprobe" if os.path.exists("/usr/local/bin/ffprobe") else "ffprobe")

        def _probe_vid_dur(vpath: str) -> float:
            if not vpath or not os.path.exists(vpath):
                return 0.0
            if vpath in _video_dur_cache:
                return _video_dur_cache[vpath]
            try:
                cmd = [ffprobe_bin, "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", vpath]
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
                if res.returncode == 0 and res.stdout.strip():
                    dur = float(res.stdout.strip())
                    _video_dur_cache[vpath] = dur
                    return dur
            except Exception:
                pass
            return 0.0

        for idx, sc in enumerate(data.get("scenes", [])):
            if not isinstance(sc, dict):
                continue
            s_idx = sc.get("slide_index", idx + 1)

            # 1. スライド画像パス解決
            if not sc.get("image_path") or not os.path.exists(sc.get("image_path", "")):
                img_candidates = []
                if sc.get("image_path"):
                    img_candidates.append(os.path.join(slide_img_dir, os.path.basename(sc["image_path"])))
                for ext in [".jpeg", ".jpg", ".png"]:
                    img_candidates.append(os.path.join(slide_img_dir, f"{p_name}.{s_idx:03d}{ext}"))
                    img_candidates.append(os.path.join(slide_img_dir, f"slide_{s_idx:03d}{ext}"))
                    img_candidates.append(os.path.join(slide_img_dir, f"slide_{s_idx}{ext}"))
                for cand_img in img_candidates:
                    if os.path.exists(cand_img):
                        sc["image_path"] = cand_img
                        break

            # 2. スライド動画クリップパス解決（has_animation が True、またはノートに指示がある場合のみ探索・バインド）
            from .keynote_parser import has_animation_instruction
            is_anim = bool(sc.get("has_animation") or has_animation_instruction(sc.get("notes", ""), sc.get("text", "")))
            if is_anim:
                sc["has_animation"] = True
                if not sc.get("video_clip_path") or not os.path.exists(sc.get("video_clip_path", "")):
                    vid_candidates = []
                    if sc.get("video_clip_path"):
                        vid_candidates.append(os.path.join(slide_vid_dir, os.path.basename(sc["video_clip_path"])))
                    for ext in [".mp4", ".mov", ".webm"]:
                        vid_candidates.append(os.path.join(slide_vid_dir, f"slide_{s_idx:03d}{ext}"))
                        vid_candidates.append(os.path.join(slide_vid_dir, f"slide_{s_idx}{ext}"))
                        vid_candidates.append(os.path.join(slide_vid_dir, f"{p_name}.{s_idx:03d}{ext}"))
                    for cand_clip in vid_candidates:
                        if os.path.exists(cand_clip) and os.path.getsize(cand_clip) > 1000:
                            sc["video_clip_path"] = cand_clip
                            sc["animation_path"] = cand_clip
                            break
            else:
                sc["has_animation"] = False
                sc["video_clip_path"] = None
                sc["animation_path"] = None
                sc["video_duration"] = None
                sc["animation_duration"] = None

            # 3. 音声パス解決
            if not sc.get("audio_path") or not os.path.exists(sc.get("audio_path", "")):
                aud_candidates = []
                if sc.get("audio_path"):
                    aud_candidates.append(os.path.join(audio_dir, os.path.basename(sc["audio_path"])))
                for ext in [".wav", ".mp3", ".m4a"]:
                    aud_candidates.append(os.path.join(audio_dir, f"slide_{s_idx:03d}{ext}"))
                    aud_candidates.append(os.path.join(audio_dir, f"slide_{s_idx}{ext}"))
                    aud_candidates.append(os.path.join(audio_dir, f"{p_name}.{s_idx:03d}{ext}"))
                for cand_aud in aud_candidates:
                    if os.path.exists(cand_aud):
                        sc["audio_path"] = cand_aud
                        break

            # 4. 音声実測尺 (audio_duration) の取得・確定
            if sc.get("audio_path") and os.path.exists(sc["audio_path"]) and (not sc.get("audio_duration") or float(sc.get("audio_duration", 0)) <= 0):
                try:
                    import wave
                    with wave.open(sc["audio_path"], 'rb') as w:
                        sc["audio_duration"] = w.getnframes() / float(w.getframerate())
                except Exception:
                    pass

            # 5. スライド動画実測尺 (video_duration) の取得・確定
            if sc.get("has_animation"):
                vpath = sc.get("video_clip_path") or sc.get("animation_path")
                if vpath and os.path.exists(vpath):
                    if not sc.get("video_duration") or float(sc.get("video_duration", 0)) <= 0:
                        vdur = _probe_vid_dur(vpath)
                        if vdur > 0:
                            sc["video_duration"] = vdur
                            sc["animation_duration"] = vdur
            else:
                sc["video_duration"] = None
                sc["animation_duration"] = None

        return data

    def save_project(self, target_path: Any, project_data: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """
        プロジェクトを .tpmproj (JSON) ファイルとして保存
        - 外部ストレージ切断時にも破損しないようにアトミック書き込み (一時ファイル -> リネーム)
        """
        # 防衛的プログラミング: 引数の順序が逆 (dict, str) で渡された場合の自動補正
        if isinstance(target_path, dict):
            if isinstance(project_data, str):
                target_path, project_data = project_data, target_path
            else:
                proj_candidate = target_path
                target_path = proj_candidate.get("project_file_path") or os.path.join(
                    PROJECT_ROOT, f"{proj_candidate.get('project_name', 'untitled')}.tpmproj"
                )
                project_data = proj_candidate

        if project_data is not None and not isinstance(project_data, dict):
            return {"success": False, "error": "保存対象のプロジェクトデータが無効です。"}

        data = project_data if isinstance(project_data, dict) else (self.current_project if isinstance(self.current_project, dict) else None)
        if not data or not isinstance(data, dict):
            return {"success": False, "error": "保存対象のプロジェクトデータが無効です。"}

        data["updated_at"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # 拡張子の補正
        target_path_str = str(target_path)
        if not target_path_str.endswith(".tpmproj") and not target_path_str.endswith(".json"):
            target_path_str += ".tpmproj"

        data["project_file_path"] = target_path_str

        target_dir = os.path.dirname(os.path.abspath(target_path_str))
        os.makedirs(target_dir, exist_ok=True)

        tmp_path = target_path_str + ".tmp"
        try:
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            # 安全なアトミック置き換え
            if os.path.exists(target_path_str):
                os.replace(tmp_path, target_path_str)
            else:
                os.rename(tmp_path, target_path_str)

            self.current_project = data
            self.current_project_path = target_path_str
            self.last_saved_time = time.time()

            # ローカル安全領域にも同期バックアップ
            self.save_temporary_backup(data)

            return {
                "success": True,
                "path": target_path_str,
                "updated_at": data["updated_at"]
            }
        except Exception as e:
            if os.path.exists(tmp_path):
                try: os.unlink(tmp_path)
                except Exception: pass
            return {"success": False, "error": f"プロジェクト保存に失敗しました: {e}"}

    def load_project(self, file_path: str) -> Dict[str, Any]:
        """プロジェクトファイルを読み込み、メディアパスをスマート解決"""
        if not os.path.exists(file_path):
            return {"success": False, "error": f"指定されたプロジェクトファイルが存在しません: {file_path}"}

        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            # メディアパスをスマート再解決
            data = self._relocate_project_media(data, file_path)

            self.current_project = data
            self.current_project_path = file_path
            self.last_saved_time = time.time()

            # 読み込み時にローカル一時バックアップを更新
            self.save_temporary_backup(data)

            return {
                "success": True,
                "project": data,
                "path": file_path
            }
        except Exception as e:
            # 破損している場合はローカルバックアップからの復旧を試行
            backup_restored = self._try_recover_from_backup(file_path)
            if backup_restored:
                backup_restored = self._relocate_project_media(backup_restored, file_path)
                return {
                    "success": True,
                    "project": backup_restored,
                    "path": file_path,
                    "recovered": True,
                    "warning": "元ファイルが破損していたため、安全な自動バックアップから復元しました。"
                }

            return {"success": False, "error": f"プロジェクト読み込みに失敗しました: {e}"}

    def save_temporary_backup(self, project_data: Optional[Dict[str, Any]] = None) -> Optional[str]:
        """
        ローカル安全領域に10分おき（または随時）一時バックアップを保存 (最大10世代/100分管理)
        - 外部ストレージが抜けてもローカルPC側に最新10世代の状態が保持される
        """
        data = project_data if isinstance(project_data, dict) else (self.current_project if isinstance(self.current_project, dict) else None)
        if not data or not isinstance(data, dict):
            return None

        p_name = data.get("project_name", "untitled")
        safe_name = "".join([c if c.isalnum() or c in "._-" else "_" for c in p_name])
        now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

        backup_file = f"backup_{safe_name}_{now_str}.tpmproj"
        target_paths = [
            os.path.join(INTERNAL_BACKUP_DIR, backup_file),
            os.path.join(LOCAL_BACKUP_DIR, backup_file)
        ]

        saved_path = None
        for p in target_paths:
            try:
                os.makedirs(os.path.dirname(p), exist_ok=True)
                with open(p, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                if not saved_path:
                    saved_path = p
            except Exception:
                pass

        # 10世代ローテーション（10個を超える古いバックアップを自動クリーンアップ）
        for bdir in [INTERNAL_BACKUP_DIR, LOCAL_BACKUP_DIR]:
            try:
                if not os.path.exists(bdir):
                    continue
                matching_files = sorted([
                    f for f in os.listdir(bdir)
                    if f.startswith(f"backup_{safe_name}_") and (f.endswith(".tpmproj") or f.endswith(".json"))
                ], reverse=True)
                if len(matching_files) > MAX_BACKUPS_PER_PROJECT:
                    for old_f in matching_files[MAX_BACKUPS_PER_PROJECT:]:
                        try:
                            os.remove(os.path.join(bdir, old_f))
                        except Exception:
                            pass
            except Exception:
                pass

        self.last_backup_time = time.time()
        return saved_path

    def _try_recover_from_backup(self, original_path: str) -> Optional[Dict[str, Any]]:
        """バックアップ一覧から復元可能な最新データを検索"""
        base_name = os.path.splitext(os.path.basename(original_path))[0]
        for bdir in [INTERNAL_BACKUP_DIR, LOCAL_BACKUP_DIR]:
            try:
                if not os.path.exists(bdir):
                    continue
                candidates = sorted(
                    [f for f in os.listdir(bdir) if f.startswith("backup_") and (base_name in f or "untitled" in f)],
                    reverse=True
                )
                for c in candidates:
                    cp = os.path.join(bdir, c)
                    try:
                        with open(cp, "r", encoding="utf-8") as f:
                            data = json.load(f)
                        return data
                    except Exception:
                        continue
            except Exception:
                pass
        return None

    def list_backups(self, project_name: Optional[str] = None) -> List[Dict[str, Any]]:
        """利用可能な自動バックアップ一覧を取得 (最大10世代・経過時間付き)"""
        backups = []
        seen = set()
        now_ts = time.time()

        for bdir in [INTERNAL_BACKUP_DIR, LOCAL_BACKUP_DIR]:
            try:
                if not os.path.exists(bdir):
                    continue
                for f in sorted(os.listdir(bdir), reverse=True):
                    if f.endswith(".tpmproj") or f.endswith(".json"):
                        fp = os.path.join(bdir, f)
                        if fp in seen:
                            continue
                        seen.add(fp)
                        try:
                            mtime = os.path.getmtime(fp)
                            size = os.path.getsize(fp)
                            with open(fp, "r", encoding="utf-8") as bf:
                                d = json.load(bf)
                            
                            p_name = d.get("project_name", "不明")
                            if project_name and p_name != project_name and ("untitled" not in f and project_name not in f):
                                continue

                            diff_mins = max(0, int((now_ts - mtime) / 60))
                            time_ago_str = "たった今" if diff_mins < 1 else f"{diff_mins}分前"

                            backups.append({
                                "filename": f,
                                "path": fp,
                                "project_name": p_name,
                                "scenes_count": len(d.get("scenes", [])),
                                "updated_at": d.get("updated_at", datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")),
                                "time_ago": time_ago_str,
                                "diff_minutes": diff_mins,
                                "size_bytes": size
                            })
                        except Exception:
                            pass
            except Exception:
                pass

        # 更新日時順にソートして最大10件を返却
        backups.sort(key=lambda x: x.get("diff_minutes", 0))
        return backups[:MAX_BACKUPS_PER_PROJECT]

    def restore_backup(self, backup_path: str) -> Dict[str, Any]:
        """指定したバックアップファイルからプロジェクトを復元"""
        if not os.path.exists(backup_path):
            return {"success": False, "error": f"バックアップファイルが見つかりません: {backup_path}"}

        try:
            with open(backup_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            self.current_project = data
            return {
                "success": True,
                "project": data,
                "path": backup_path,
                "restored_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
        except Exception as e:
            return {"success": False, "error": f"バックアップの復元に失敗しました: {e}"}


def get_project_manager() -> ProjectManager:
    return ProjectManager()
