"""
東方Projectムービーメーカー - Final Cut Pro (FCPXML) インポート・解析モジュール
- FCPXML (1.9 / 1.10 / DTD規格) からスライド画像、音声、テロップ、タイムライン構造を復元
- プロジェクトデータ (scenes) へ変換して編集画面にロード可能にする
"""

import os
import re
import urllib.parse
import xml.etree.ElementTree as ET
from typing import List, Dict, Any, Optional
from .character_db import CHARACTERS, CHARACTER_ALIASES
from .tts_engine import get_tts_engine


class FCPXMLParser:
    @staticmethod
    def parse_fcpxml(file_path: str) -> Dict[str, Any]:
        """
        FCPXMLファイルを解析し、プロジェクト情報とシーンリストを生成する。
        """
        if not os.path.exists(file_path):
            return {"success": False, "error": f"FCPXMLファイルが見つかりません: {file_path}"}

        try:
            tree = ET.parse(file_path)
            root = tree.getroot()
        except Exception as e:
            return {"success": False, "error": f"FCPXMLのXML解析に失敗しました: {e}"}

        # 1. アセットマップの構築 (id -> {src, name, hasAudio, hasVideo})
        asset_map = {}
        resources = root.find("resources")
        if resources is not None:
            for asset in resources.findall("asset"):
                aid = asset.get("id")
                name = asset.get("name", "")
                has_audio = asset.get("hasAudio") == "1"
                has_video = asset.get("hasVideo") == "1"
                
                # media-rep からファイルパスを取得
                media_rep = asset.find("media-rep")
                file_src = ""
                if media_rep is not None:
                    src_uri = media_rep.get("src", "")
                    if src_uri.startswith("file://"):
                        file_src = urllib.parse.unquote(src_uri[len("file://"):])
                    else:
                        file_src = src_uri
                elif "src" in asset.attrib:
                    src_uri = asset.get("src", "")
                    if src_uri.startswith("file://"):
                        file_src = urllib.parse.unquote(src_uri[len("file://"):])
                    else:
                        file_src = src_uri

                asset_map[aid] = {
                    "id": aid,
                    "name": name,
                    "src": file_src,
                    "has_audio": has_audio,
                    "has_video": has_video
                }

        # 2. プロジェクト名
        project_name = os.path.splitext(os.path.basename(file_path))[0]
        project_elem = root.find(".//project")
        if project_elem is not None and project_elem.get("name"):
            project_name = project_elem.get("name")

        # 3. シーケンス / spine の探索
        spine = root.find(".//spine")
        if spine is None:
            spine = root.find(".//sequence")

        scenes = []
        slide_counter = 1
        tts = get_tts_engine()

        if spine is not None:
            for child in spine:
                tag = child.tag
                if tag in ["video", "gap", "clip", "asset-clip", "ref-clip"]:
                    img_path = None
                    ref_id = child.get("ref")
                    if ref_id and ref_id in asset_map:
                        cand_src = asset_map[ref_id]["src"]
                        if cand_src and os.path.exists(cand_src):
                            img_path = cand_src
                    elif tag in ["video", "asset-clip"]:
                        for sub in child.iter("media-rep"):
                            s_uri = sub.get("src", "")
                            if s_uri.startswith("file://"):
                                p = urllib.parse.unquote(s_uri[7:])
                                if os.path.exists(p):
                                    img_path = p
                                    break

                    dur_str = child.get("duration", "3s")
                    dur_sec = _parse_time_str(dur_str)

                    audio_path = None
                    audio_dur = 0.0
                    for a_elem in child.iter("audio"):
                        a_ref = a_elem.get("ref")
                        if a_ref and a_ref in asset_map:
                            a_src = asset_map[a_ref]["src"]
                            if a_src and os.path.exists(a_src):
                                audio_path = a_src
                                audio_dur = _parse_time_str(a_elem.get("duration", "0s"))
                                break

                    text = ""
                    character = "操夢"
                    title_elem = child.find(".//title")
                    if title_elem is not None:
                        t_name = title_elem.get("name", "")
                        if "テロップ:" in t_name:
                            character = t_name.replace("テロップ:", "").strip() or "操夢"

                        text_elem = title_elem.find(".//text")
                        if text_elem is not None:
                            t_style = text_elem.find("text-style")
                            if t_style is not None and t_style.text:
                                text = t_style.text.strip()
                            elif text_elem.text:
                                text = text_elem.text.strip()

                    if text and ":" in text:
                        parts = text.split(":", 1)
                        c_cand = parts[0].strip()
                        if c_cand in CHARACTERS or c_cand in CHARACTER_ALIASES:
                            character = CHARACTER_ALIASES.get(c_cand, c_cand)
                            text = parts[1].strip()

                    char_info = CHARACTERS.get(character, CHARACTERS["操夢"])
                    voice = char_info.get("voice", "f1")
                    speed = char_info.get("speed", 100)
                    pitch = char_info.get("pitch", 100)

                    phonemes = tts.kanji2koe(text) if text else ""
                    is_no_voice = (audio_path is None and not text)

                    scenes.append({
                        "slide_index": slide_counter,
                        "character": character,
                        "voice": voice,
                        "speed": speed,
                        "pitch": pitch,
                        "text": text,
                        "phonemes": phonemes,
                        "image_path": img_path,
                        "audio_path": audio_path,
                        "audio_duration": audio_dur if audio_dur > 0 else max(0.0, dur_sec),
                        "extra_delay": 0.0,
                        "quality_enhance": True,
                        "effect": "none",
                        "sound_effect": None,
                        "se_offset": 0.0,
                        "no_voice": is_no_voice,
                        "is_skipped": is_no_voice,
                        "is_enabled": True
                    })
                    slide_counter += 1

        if not scenes:
            scenes.append({
                "slide_index": 1,
                "character": "操夢",
                "voice": "f1",
                "speed": 100,
                "pitch": 100,
                "text": "Final Cut Pro からインポートされたプロジェクトです。",
                "phonemes": "ファイナルカットプロカラインポートサレタプロジェクトデス。",
                "image_path": None,
                "audio_path": None,
                "audio_duration": 0.0,
                "extra_delay": 2.0,
                "quality_enhance": True,
                "effect": "none",
                "no_voice": True,
                "is_skipped": True,
                "is_enabled": True
            })

        project_data = {
            "project_name": project_name,
            "scenes": scenes,
            "created_at": None,
            "source_type": "fcpxml",
            "source_file": file_path
        }

        return {
            "success": True,
            "project": project_data,
            "total_scenes": len(scenes)
        }


def _parse_time_str(time_str: str) -> float:
    """FCPXML の時間文字列 (例: '1000/100s', '3.5s', '10s') を秒数 (float) に変換"""
    if not time_str:
        return 0.0
    time_str = time_str.rstrip("s").strip()
    if "/" in time_str:
        parts = time_str.split("/")
        try:
            num = float(parts[0])
            den = float(parts[1])
            return num / den if den != 0 else 0.0
        except Exception:
            return 0.0
    else:
        try:
            return float(time_str)
        except Exception:
            return 0.0
