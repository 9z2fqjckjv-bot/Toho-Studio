#!/usr/bin/env python3
"""
Extract lower-third telop text from a Keynote .key file and save it as CSV.

Dependencies:
    python3 -m pip install keynote-parser PyYAML

Example:
    python3 keynote_telop_to_csv.py presentation.key -o script.csv \
        --project-dir /Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML is required. Install it with: python3 -m pip install PyYAML") from exc


DEFAULT_PROJECT_DIR = Path("/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story")
TEXT_ONLY_BACKGROUND_NAMES = {"preview.jpg", "preview-web.jpg", "preview-micro.jpg"}

VOICE_ALIASES = {
    "レミリア": "れみりあ",
    "フラン": "ふらん",
    "フランドール": "ふらん",
    "男": "Singoku男",
    "女": "Singoku女",
    "ナレーション": "Singoku男",
    "咲夜": "さくや",
    "パチュリー": "ぱちゅりー",
    "霊夢": "れいむ",
    "魔理沙": "まりさ",
    "さとり": "さとり",
    "こいし": "こいし",
}

COLOR_CHARACTERS = {
    "#970E53": "レミリア",
    "#FFD932": "フラン",
    "#EE220C": "霊夢",
    "#FFF056": "魔理沙",
    "#D41876": "パチュリー",
    "#D5D5D5": "咲夜",
    "#FF95CA": "さとり",
    "#017100": "こいし",
}

EXPLICIT_TERMS = [
    "セックス",
    "性交",
    "性器",
    "精子",
    "射精",
    "膣",
    "陰茎",
    "フェラ",
    "挿入",
    "中出し",
    "孕",
    "犯され",
    "あそこ",
]


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        return yaml.safe_load(file) or {}


def walk_values(value: Any, key: str | None = None):
    if isinstance(value, dict):
        for child_key, child_value in value.items():
            yield from walk_values(child_value, child_key)
    elif isinstance(value, list):
        for child in value:
            yield from walk_values(child, key)
    else:
        yield key, value


def find_first_key(value: Any, wanted_key: str) -> Any | None:
    if isinstance(value, dict):
        if wanted_key in value:
            return value[wanted_key]
        for child in value.values():
            found = find_first_key(child, wanted_key)
            if found is not None:
                return found
    elif isinstance(value, list):
        for child in value:
            found = find_first_key(child, wanted_key)
            if found is not None:
                return found
    return None


def unpack_keynote(input_key: Path, output_dir: Path) -> None:
    command = [sys.executable, "-m", "keynote_parser.command_line", "unpack", "-o", str(output_dir), str(input_key)]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=300)
    except ModuleNotFoundError:
        result = None
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"Keynote unpack timed out: {input_key}") from exc

    if result is not None and result.returncode == 0:
        return

    executable = shutil.which("keynote-parser")
    if executable:
        result = subprocess.run(
            [executable, "unpack", "-o", str(output_dir), str(input_key)],
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode == 0:
            return

    detail = ""
    if result is not None:
        detail = (result.stderr or result.stdout).strip()
    raise RuntimeError(
        "keynote-parser is required to unpack .key files. "
        "Install it with: python3 -m pip install keynote-parser PyYAML"
        + (f"\n{detail}" if detail else "")
    )


def build_asset_map(index_dir: Path) -> dict[str, str]:
    metadata_path = index_dir / "Metadata.iwa.yaml"
    if not metadata_path.exists():
        return {}

    metadata = load_yaml(metadata_path)
    assets: dict[str, str] = {}

    def visit(node: Any) -> None:
        if isinstance(node, dict):
            identifier = node.get("identifier")
            file_name = node.get("fileName")
            if identifier and file_name:
                assets[str(identifier)] = str(file_name)
            for child in node.values():
                visit(child)
        elif isinstance(node, list):
            for child in node:
                visit(child)

    visit(metadata)
    return assets


def build_style_color_map(index_dir: Path) -> dict[str, str]:
    stylesheet_path = index_dir / "DocumentStylesheet.iwa.yaml"
    if not stylesheet_path.exists():
        return {}

    stylesheet = load_yaml(stylesheet_path)
    colors: dict[str, str] = {}
    for archive in stylesheet.get("chunks", [{}])[0].get("archives", []):
        style_id = str(archive.get("header", {}).get("identifier", ""))
        for obj in archive.get("objects", []):
            if not isinstance(obj, dict):
                continue
            color = obj.get("charProperties", {}).get("fontColor")
            if not isinstance(color, dict):
                continue
            colors[style_id] = "#{:02X}{:02X}{:02X}".format(
                round(float(color.get("r", 0)) * 255),
                round(float(color.get("g", 0)) * 255),
                round(float(color.get("b", 0)) * 255),
            )
    return colors


def slide_order(index_dir: Path) -> list[str]:
    document = load_yaml(index_dir / "Document.iwa.yaml")
    archives = document.get("chunks", [{}])[0].get("archives", [])
    wrapper_to_slide: dict[str, str] = {}
    ordered_wrappers: list[str] = []

    for archive in archives:
        archive_id = str(archive.get("header", {}).get("identifier", ""))
        for obj in archive.get("objects", []):
            if not isinstance(obj, dict):
                continue
            if obj.get("_pbtype") == "KN.ShowArchive":
                ordered_wrappers = [
                    str(item["identifier"])
                    for item in obj.get("slideTree", {}).get("slides", [])
                    if isinstance(item, dict) and "identifier" in item
                ]
            slide_ref = obj.get("slide")
            if isinstance(slide_ref, dict) and "identifier" in slide_ref:
                wrapper_to_slide[archive_id] = str(slide_ref["identifier"])

    return [wrapper_to_slide[wrapper] for wrapper in ordered_wrappers if wrapper in wrapper_to_slide]


def slide_yaml_path(index_dir: Path, slide_id: str) -> Path:
    path = index_dir / f"Slide-{slide_id}.iwa.yaml"
    if path.exists():
        return path
    fallback = index_dir / "Slide.iwa.yaml"
    if fallback.exists():
        return fallback
    raise FileNotFoundError(f"Slide YAML not found for slide id {slide_id}")


def geometry_from_shape(shape: dict[str, Any]) -> dict[str, float]:
    geometry = find_first_key(shape, "geometry")
    if not isinstance(geometry, dict):
        return {}

    position = geometry.get("position", {})
    size = geometry.get("size", {})
    if not isinstance(position, dict) or not isinstance(size, dict):
        return {}

    return {
        "x": float(position.get("x", 0)),
        "y": float(position.get("y", 0)),
        "width": float(size.get("width", 0)),
        "height": float(size.get("height", 0)),
    }


def extract_slide(index_dir: Path, slide_id: str, style_colors: dict[str, str]) -> tuple[list[dict[str, Any]], set[str]]:
    data = load_yaml(slide_yaml_path(index_dir, slide_id))
    storage_geometry: dict[str, dict[str, float]] = {}
    asset_refs: set[str] = set()

    for key, value in walk_values(data):
        if key in {"dataIdentifier", "identifier"} and isinstance(value, str) and value.isdigit():
            asset_refs.add(value)

    archives = data.get("chunks", [{}])[0].get("archives", [])
    for archive in archives:
        for obj in archive.get("objects", []):
            if not isinstance(obj, dict):
                continue
            if obj.get("_pbtype") != "TSWP.ShapeInfoArchive":
                continue
            storage = obj.get("ownedStorage") or obj.get("deprecatedStorage")
            if isinstance(storage, dict) and "identifier" in storage:
                storage_geometry[str(storage["identifier"])] = geometry_from_shape(obj)

    text_items: list[dict[str, Any]] = []
    seen: set[str] = set()
    for archive in archives:
        storage_id = str(archive.get("header", {}).get("identifier", ""))
        for obj in archive.get("objects", []):
            if not isinstance(obj, dict) or obj.get("_pbtype") != "TSWP.StorageArchive":
                continue
            raw_texts = [text for text in obj.get("text", []) if isinstance(text, str) and text != "\uFFFC"]
            if not raw_texts:
                continue
            text = re.sub(r"\s+", " ", " ".join(raw_texts)).replace("\uFFFC", "").strip()
            if not text or text in seen:
                continue
            seen.add(text)

            style_id = ""
            entries = obj.get("tableParaStyle", {}).get("entries", [])
            if entries and isinstance(entries[0].get("object"), dict):
                style_id = str(entries[0]["object"].get("identifier", ""))

            geometry = storage_geometry.get(storage_id, {})
            text_items.append(
                {
                    "text": text,
                    "style_id": style_id,
                    "text_color": style_colors.get(style_id, ""),
                    "x": geometry.get("x", ""),
                    "y": geometry.get("y", ""),
                    "width": geometry.get("width", ""),
                    "height": geometry.get("height", ""),
                }
            )

    return text_items, asset_refs


def is_body_text(text: str) -> bool:
    return "東方Project二次創作" not in text and not text.startswith("交換夫婦")


def is_telop(item: dict[str, Any], slide_height: float, threshold: float) -> bool:
    y = item.get("y")
    if isinstance(y, float):
        return y >= slide_height * threshold
    return False


def is_text_only(asset_names: list[str]) -> bool:
    image_assets = [
        name
        for name in asset_names
        if re.search(r"\.(png|jpe?g)$", name, re.IGNORECASE) and Path(name).name not in TEXT_ONLY_BACKGROUND_NAMES
    ]
    return not image_assets


def load_voice_map(voice_csv: Path | None) -> dict[str, dict[str, str]]:
    voices = {
        "Singoku男": {"voice": "中性", "speed": "100", "pitch": "115"},
        "Singoku女": {"voice": "女性1", "speed": "100", "pitch": "115"},
    }
    if voice_csv is None or not voice_csv.exists():
        return voices

    with voice_csv.open(newline="", encoding="utf-8") as file:
        for row in csv.DictReader(file):
            voices[row["キャラクター名"]] = {
                "voice": row.get("声質", ""),
                "speed": row.get("速度", ""),
                "pitch": row.get("音程", ""),
            }
    return voices


def infer_character(text: str, text_color: str, asset_names: list[str]) -> str:
    if text_color in COLOR_CHARACTERS:
        return COLOR_CHARACTERS[text_color]

    joined_assets = " ".join(asset_names)
    if re.search(r"僕|俺", text):
        return "男"
    if "だぜ" in text:
        return "魔理沙"
    if "お姉様" in text:
        return "フラン"
    if "レミリア" in joined_assets and "フランドール" not in joined_assets:
        return "レミリア"
    if "フランドール" in joined_assets and "レミリア" not in joined_assets:
        return "フラン"
    if "霊夢" in joined_assets:
        return "霊夢"
    if "魔理沙" in joined_assets:
        return "魔理沙"
    if "咲夜" in joined_assets:
        return "咲夜"
    if "パチュリー" in joined_assets:
        return "パチュリー"
    if "さとり" in joined_assets:
        return "さとり"
    if "こいし" in joined_assets:
        return "こいし"
    if "SinGyoku" in joined_assets or "Singoku" in text:
        return "男"
    return "ナレーション"


def sanitize_text(text: str, redact_explicit: bool) -> str:
    if redact_explicit and any(term in text for term in EXPLICIT_TERMS):
        return "[性的内容のため省略]"
    return text


def extract_to_csv(args: argparse.Namespace) -> int:
    input_key = Path(args.input_key).expanduser().resolve()
    output_csv = Path(args.output).expanduser().resolve()
    project_dir = Path(args.project_dir).expanduser().resolve() if args.project_dir else DEFAULT_PROJECT_DIR
    voice_csv = Path(args.voice_csv).expanduser().resolve() if args.voice_csv else project_dir / "ボイス設定.csv"

    with tempfile.TemporaryDirectory(prefix="keynote_telop_") as tmp:
        unpack_dir = Path(tmp) / "unpacked"
        unpack_keynote(input_key, unpack_dir)
        index_dir = unpack_dir / "Index"

        assets = build_asset_map(index_dir)
        style_colors = build_style_color_map(index_dir)
        voices = load_voice_map(voice_csv)
        rows: list[dict[str, Any]] = []

        for slide_num, slide_id in enumerate(slide_order(index_dir), start=1):
            text_items, refs = extract_slide(index_dir, slide_id, style_colors)
            asset_names = sorted({assets[ref] for ref in refs if ref in assets})
            if args.skip_text_only and is_text_only(asset_names):
                continue

            telop_items = [
                item
                for item in text_items
                if is_body_text(item["text"]) and (not args.telop_only or is_telop(item, args.slide_height, args.telop_y_threshold))
            ]
            if not telop_items:
                continue

            text = " ".join(item["text"] for item in telop_items).strip()
            text_color = next((item["text_color"] for item in telop_items if item["text_color"]), "")
            character = infer_character(text, text_color, asset_names)
            voice_key = VOICE_ALIASES.get(character, character)
            voice = voices.get(voice_key, {"voice": "", "speed": "", "pitch": ""})
            first_item = telop_items[0]

            rows.append(
                {
                    "slide_num": slide_num,
                    "slide_id": slide_id,
                    "character": character,
                    "text_color": text_color,
                    "text": sanitize_text(text, args.redact_explicit),
                    "voice_type": voice["voice"],
                    "speed": voice["speed"],
                    "pitch": voice["pitch"],
                    "x": first_item.get("x", ""),
                    "y": first_item.get("y", ""),
                    "width": first_item.get("width", ""),
                    "height": first_item.get("height", ""),
                    "assets": " | ".join(asset_names[: args.max_assets]),
                }
            )

    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with output_csv.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "slide_num",
                "slide_id",
                "character",
                "text_color",
                "text",
                "voice_type",
                "speed",
                "pitch",
                "x",
                "y",
                "width",
                "height",
                "assets",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {len(rows)} rows: {output_csv}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract Keynote lower-third telop text to CSV.")
    parser.add_argument("input_key", help="Path to a .key file")
    parser.add_argument("-o", "--output", default="keynote_telop.csv", help="Output CSV path")
    parser.add_argument("--project-dir", default=str(DEFAULT_PROJECT_DIR), help="Project root used for voice settings")
    parser.add_argument("--voice-csv", help="Voice settings CSV path. Defaults to PROJECT_DIR/ボイス設定.csv")
    parser.add_argument("--slide-height", type=float, default=1080.0, help="Slide height used for telop position filtering")
    parser.add_argument(
        "--telop-y-threshold",
        type=float,
        default=0.62,
        help="Keep text boxes whose y position is at or below this slide-height ratio",
    )
    parser.add_argument("--max-assets", type=int, default=8, help="Maximum referenced asset names to include")
    parser.add_argument("--include-text-only", dest="skip_text_only", action="store_false", help="Do not skip text-only slides")
    parser.add_argument("--all-text", dest="telop_only", action="store_false", help="Extract all slide text, not only bottom telops")
    parser.add_argument(
        "--no-redact-explicit",
        dest="redact_explicit",
        action="store_false",
        help="Do not redact explicit sexual terms in extracted text",
    )
    parser.set_defaults(skip_text_only=True, telop_only=True, redact_explicit=True)
    return parser.parse_args()


if __name__ == "__main__":
    raise SystemExit(extract_to_csv(parse_args()))
