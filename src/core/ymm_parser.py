"""
東方Projectムービーメーカー - Windows ゆっくりMovieMaker (YMM3/YMM4) インポートモジュール
- YMM4 プロジェクトファイル (.ymmp - JSON形式) の解析
- YMM3 プロジェクトファイル (XML/バイナリ) の解析
- セリフ、キャラクター、音声パラメータ、タイムラインアイテムの抽出・変換
"""

import os
import json
import re
from typing import List, Dict, Any, Optional

from .character_db import CHARACTERS, CHARACTER_ALIASES, get_character_info
from .tts_engine import get_tts_engine


def parse_ymm_project(file_path: str) -> List[Dict[str, Any]]:
    """YMM プロジェクトファイルを解析してシーン一覧を返す"""
    if not os.path.exists(file_path):
        return []

    ext = os.path.splitext(file_path)[1].lower()
    if ext == ".ymmp" or ext == ".json":
        return _parse_ymm4_json(file_path)
    else:
        return _parse_ymm_fallback(file_path)


def _parse_ymm4_json(file_path: str) -> List[Dict[str, Any]]:
    """YMM4 (.ymmp JSON) を解析"""
    scenes = []
    tts = get_tts_engine()

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        timeline = data.get("Timeline", {})
        items = timeline.get("Items", []) or data.get("Items", []) or []

        voice_items = []
        for it in items:
            it_type = it.get("$type", "")
            if "VoiceItem" in it_type or "TextItem" in it_type or "SerifItem" in it_type:
                voice_items.append(it)

        voice_items.sort(key=lambda x: x.get("Frame", 0))

        for idx, it in enumerate(voice_items, start=1):
            text = it.get("Serif", "") or it.get("Text", "") or it.get("Content", "")
            char_name_raw = it.get("CharacterName", "") or it.get("VoiceName", "")

            char_info = get_character_info(char_name_raw if char_name_raw else "操夢")
            char_name = char_name_raw if char_name_raw in CHARACTERS else "操夢"

            speed = int(it.get("Speed", char_info["speed"]))
            pitch = int(it.get("Pitch", char_info["pitch"]))
            voice = char_info["voice"]

            koe = it.get("Pronunciation", "") or it.get("Koe", "")
            if not koe and text:
                koe = tts.kanji2koe(text)

            scenes.append({
                "slide_index": idx,
                "text": text,
                "notes": f"YMM Layer: {it.get('Layer', 0)} / Frame: {it.get('Frame', 0)}",
                "character": char_name,
                "voice": voice,
                "speed": speed,
                "pitch": pitch,
                "phonemes": koe,
                "extra_delay": 0.0,
                "transition_delay": 0.0,
                "audio_duration": 0.0,
                "audio_file": f"slide_{idx:03d}.wav",
                "is_enabled": bool(text)
            })

    except Exception as e:
        print(f"[ERROR] Failed to parse YMM4 project: {e}")

    return scenes


def _parse_ymm_fallback(file_path: str) -> List[Dict[str, Any]]:
    """プレーンテキストまたは簡易パース"""
    scenes = []
    tts = get_tts_engine()

    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        lines = [l.strip() for l in content.splitlines() if l.strip()]
        for idx, line in enumerate(lines, start=1):
            koe = tts.kanji2koe(line)
            scenes.append({
                "slide_index": idx,
                "text": line,
                "notes": "",
                "character": "操夢",
                "voice": "imd1",
                "speed": 100,
                "pitch": 115,
                "phonemes": koe,
                "extra_delay": 0.0,
                "transition_delay": 0.0,
                "audio_duration": 0.0,
                "audio_file": f"slide_{idx:03d}.wav",
                "is_enabled": True
            })
    except Exception as e:
        print(f"[ERROR] YMM fallback parse failed: {e}")

    return scenes
