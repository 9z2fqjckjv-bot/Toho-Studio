"""
台本管理モジュール
- 台本データの保存・読み込み (JSON, 視認性の高いMarkdown, CSV)
- 漢字仮名混じり文の保持と視認性の向上
"""

import os
import json
import csv
import re
from typing import List, Dict, Any, Optional
from .path_utils import get_media_dir

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRIPT_DIR = get_media_dir("", "台本")


class ScriptManager:
    @staticmethod
    def get_script_dir(custom_dir: Optional[str] = None) -> str:
        d = custom_dir or SCRIPT_DIR
        os.makedirs(d, exist_ok=True)
        return d

    @classmethod
    def save_script(cls, episode_name: str, slides: List[Dict[str, Any]], script_dir: Optional[str] = None) -> Dict[str, str]:
        out_dir = cls.get_script_dir(script_dir)
        base_name = os.path.splitext(episode_name)[0]

        json_path = os.path.join(out_dir, f"{base_name}.json")
        md_path = os.path.join(out_dir, f"{base_name}.md")
        csv_path = os.path.join(out_dir, f"{base_name}.csv")

        data = {
            "episode": base_name,
            "total_slides": len(slides),
            "slides": slides
        }
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        md_content = cls._generate_markdown(base_name, slides)
        with open(md_path, "w", encoding="utf-8") as f:
            f.write(md_content)

        cls._save_csv(csv_path, slides)

        return {
            "json_path": json_path,
            "md_path": md_path,
            "csv_path": csv_path
        }

    @classmethod
    def _generate_markdown(cls, episode_name: str, slides: List[Dict[str, Any]]) -> str:
        lines = [
            f"# 台本：{episode_name}",
            "",
            "> 💡 **台本の見方・編集について**",
            "> - 各スライドのセリフ（漢字仮名混じり文）と音声記号列が記録されています。",
            "> - セリフを直接編集した後にアプリで再読み込み可能です。",
            "",
            "| No | キャラクター | 声種 | 話速 | セリフ (漢字仮名交じり文) | 音声記号列 | 有効 |",
            "|---|---|---|---|---|---|---|"
        ]

        for s in slides:
            idx = s.get("slide_index", 0)
            char = s.get("character", "ナレーション")
            voice = s.get("voice", "f1")
            speed = s.get("speed", 100)
            text = s.get("text", "").replace("\n", "<br>").replace("|", "｜")
            phonemes = s.get("phonemes", "").replace("\n", "<br>").replace("|", "｜")
            is_en = "✅" if s.get("is_enabled", True) else "❌"
            lines.append(f"| {idx} | **{char}** | `{voice}` | {speed}% | {text} | `{phonemes}` | {is_en} |")

        lines.append("")
        lines.append("## セリフ一覧（テキスト形式）")
        lines.append("")

        for s in slides:
            idx = s.get("slide_index", 0)
            char = s.get("character", "ナレーション")
            text = s.get("text", "").strip()
            if not text:
                continue
            lines.append(f"### [Slide {idx}] {char}")
            lines.append(f"```text\n{text}\n```")
            lines.append("")

        return "\n".join(lines)

    @classmethod
    def _save_csv(cls, csv_path: str, slides: List[Dict[str, Any]]):
        with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["スライド番号", "キャラクター", "声種", "話速", "セリフ", "音声記号列", "有効"])
            for s in slides:
                writer.writerow([
                    s.get("slide_index", 0),
                    s.get("character", "ナレーション"),
                    s.get("voice", "f1"),
                    s.get("speed", 100),
                    s.get("text", ""),
                    s.get("phonemes", ""),
                    1 if s.get("is_enabled", True) else 0
                ])

    @classmethod
    def load_script_json(cls, file_path: str) -> Optional[List[Dict[str, Any]]]:
        if not os.path.exists(file_path):
            return None
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            return data.get("slides", [])
        except Exception as e:
            print(f"[ERROR] Failed to load JSON script: {e}")
            return None

    @classmethod
    def load_script_csv(cls, file_path: str) -> Optional[List[Dict[str, Any]]]:
        if not os.path.exists(file_path):
            return None
        try:
            slides = []
            with open(file_path, "r", encoding="utf-8-sig") as f:
                reader = csv.reader(f)
                header = next(reader, None)
                for row in reader:
                    if not row or len(row) < 5:
                        continue
                    try:
                        idx = int(row[0].strip())
                    except ValueError:
                        continue
                    char = row[1].strip() if len(row) > 1 else "ナレーション"
                    voice = row[2].strip() if len(row) > 2 else "f1"
                    try:
                        speed = int(row[3].strip())
                    except (ValueError, IndexError):
                        speed = 100
                    text = row[4].strip() if len(row) > 4 else ""
                    phonemes = row[5].strip() if len(row) > 5 else ""
                    is_en = True
                    if len(row) > 6:
                        is_en = (row[6].strip() in ["1", "true", "True", "✅"])
                    slides.append({
                        "slide_index": idx,
                        "character": char,
                        "voice": voice,
                        "speed": speed,
                        "text": text,
                        "phonemes": phonemes,
                        "is_enabled": is_en,
                        "audio_file": f"slide_{idx:03d}.wav",
                        "audio_duration": 0.0
                    })
            return slides
        except Exception as e:
            print(f"[ERROR] Failed to load CSV script: {e}")
            return None
