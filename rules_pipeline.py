#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import auto_pipeline
import toho_movie_studio

BASE_DIR = Path(__file__).resolve().parent
SCRIPT_PATH = BASE_DIR / "script.csv"
OUTPUT_DIR = BASE_DIR / "exports"
AQUESTALK1_UNSUPPORTED_CHARS = re.compile(r"[一-龯々〆ヵヶ「」『』（）()［］\[\]【】…]")
MASK_PATTERN = re.compile(r"[〇○●伏せ字]")
REDACTED_TEXT = "[性的内容のため省略]"
DIAL_UP_SOUND_NAME = "Dial_Up_Connection01-1.mp3"


@dataclass
class RuleIssue:
    level: str
    message: str
    slide_num: int | None = None

    def as_dict(self) -> dict[str, Any]:
        return {"level": self.level, "slide_num": self.slide_num, "message": self.message}


def natural_key(path: Path | str) -> list[Any]:
    return toho_movie_studio.natural_key(path)


def rel(path: Path) -> str:
    return toho_movie_studio.rel(path)


def resolve_path(value: str | None) -> Path | None:
    return toho_movie_studio.resolve_path(value)


def find_keynote_file(explicit_path: str | None) -> Path:
    if explicit_path:
        path = resolve_path(explicit_path)
        if path and path.exists():
            return path
        raise SystemExit(f"Keynoteファイルが見つかりません: {explicit_path}")

    keynotes = sorted((BASE_DIR / "slides").rglob("*.key"), key=natural_key)
    if not keynotes:
        raise SystemExit("slides/ 以下に .key ファイルが見つかりません。")
    if len(keynotes) > 1:
        print("複数のKeynoteファイルが見つかりました。最初の候補を使います:", file=sys.stderr)
        for path in keynotes:
            print(f"- {rel(path)}", file=sys.stderr)
    return keynotes[0]


def extract_script_from_keynote(keynote_path: Path, output_csv: Path) -> None:
    command = [
        sys.executable,
        "keynote_telop_to_csv.py",
        str(keynote_path),
        "-o",
        str(output_csv),
        "--project-dir",
        str(BASE_DIR),
        "--no-redact-explicit",
    ]
    subprocess.run(command, cwd=BASE_DIR, check=True)


def read_script_rows(script_path: Path) -> list[dict[str, str]]:
    if not script_path.exists():
        raise SystemExit(f"台本CSVが見つかりません: {rel(script_path)}")
    with script_path.open("r", encoding="utf-8", newline="") as file:
        return [row for row in csv.DictReader(file) if any((value or "").strip() for value in row.values())]


def slide_num_for_row(row: dict[str, str], index: int) -> int:
    raw = (row.get("slide_num") or "").strip()
    return int(raw) if raw.isdecimal() else index


def synthesis_text(row: dict[str, str]) -> str:
    phoneme = (row.get("phoneme_sequence") or "").strip()
    text = phoneme or (row.get("text") or "").strip()
    return re.sub(r"\s+", "", text)


def detect_rule_issues(
    rows: list[dict[str, str]],
    has_highlight_choice: bool = False,
) -> tuple[list[RuleIssue], set[int]]:
    issues: list[RuleIssue] = []
    skipped_repeated: set[int] = set()
    seen_texts: dict[str, int] = {}

    for index, row in enumerate(rows, start=1):
        slide_num = slide_num_for_row(row, index)
        text = (row.get("text") or "").strip()
        voice_text = synthesis_text(row)
        normalized_text = re.sub(r"\s+", "", text)

        if normalized_text:
            previous_slide = seen_texts.get(normalized_text)
            if previous_slide is not None:
                skipped_repeated.add(slide_num)
                issues.append(RuleIssue("info", f"繰り返しのセリフとして除外します。初出: slide {previous_slide}", slide_num))
            else:
                seen_texts[normalized_text] = slide_num

        if not voice_text:
            issues.append(RuleIssue("error", "AquesTalk1で読む音声記号列が空です。", slide_num))
        elif AQUESTALK1_UNSUPPORTED_CHARS.search(voice_text):
            issues.append(RuleIssue("error", "AquesTalk1用の音声記号列ではない文字が残っています。読み方を確認して phoneme_sequence を設定してください。", slide_num))

        if REDACTED_TEXT in text or REDACTED_TEXT in voice_text:
            issues.append(RuleIssue("error", "省略済みの台本があります。ルール上、省略せず実語句を台本に入れてください。", slide_num))

        if MASK_PATTERN.search(text) or MASK_PATTERN.search(voice_text):
            issues.append(RuleIssue("error", "伏せ字が残っています。入る語句をユーザーに確認してから台本へ反映してください。", slide_num))

    sample_videos = sorted((BASE_DIR / "Movie archive" / "sample").glob("*.mov"), key=natural_key)
    if sample_videos and not has_highlight_choice:
        issues.append(RuleIssue("question", "迷シーン候補は sample 動画を基準にユーザー選択が必要です。--highlight-slide または --highlight-at を指定してください。"))

    return issues, skipped_repeated


def find_audio_by_keywords(keywords: tuple[str, ...]) -> Path | None:
    candidates = []
    for path in BASE_DIR.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in toho_movie_studio.AUDIO_EXTENSIONS:
            continue
        name = path.name.lower()
        if any(keyword.lower() in name for keyword in keywords):
            candidates.append(path)
    return sorted(candidates, key=natural_key)[0] if candidates else None


def check_required_effects(rows: list[dict[str, str]]) -> list[RuleIssue]:
    issues: list[RuleIssue] = []
    joined_text = "\n".join(row.get("text", "") for row in rows)

    if MASK_PATTERN.search(joined_text) and not find_audio_by_keywords(("自主規制", "censor", "beep", "ピー")):
        issues.append(RuleIssue("error", "伏せ字用の自主規制効果音がリポジトリ内に見つかりません。"))
    if "キーボード" in joined_text and not find_audio_by_keywords(("keyboard", "キーボード")):
        issues.append(RuleIssue("error", "キーボード打鍵音がリポジトリ内に見つかりません。"))
    if "ポケベル" in joined_text and not (BASE_DIR / DIAL_UP_SOUND_NAME).exists() and not find_audio_by_keywords((DIAL_UP_SOUND_NAME, "Dial_Up_Connection01-1")):
        issues.append(RuleIssue("error", f"{DIAL_UP_SOUND_NAME} が見つかりません。"))

    return issues


def print_issues(issues: list[RuleIssue], json_output: bool = False) -> None:
    if json_output:
        print(json.dumps([issue.as_dict() for issue in issues], ensure_ascii=False, indent=2))
        return
    for issue in issues:
        prefix = issue.level.upper()
        slide = f" slide {issue.slide_num}:" if issue.slide_num is not None else ":"
        print(f"[{prefix}]{slide} {issue.message}")


def ensure_no_blocking_issues(rows: list[dict[str, str]], allow_questions: bool, has_highlight_choice: bool) -> set[int]:
    issues, skipped_repeated = detect_rule_issues(rows, has_highlight_choice=has_highlight_choice)
    issues.extend(check_required_effects(rows))
    blocking = [issue for issue in issues if issue.level == "error" or (issue.level == "question" and not allow_questions)]
    print_issues(issues)
    if blocking:
        raise SystemExit("未確認または修正が必要な項目があるため停止しました。")
    return skipped_repeated


def generate_audio_rows(rows: list[dict[str, str]], skipped_slides: set[int]) -> None:
    rows_to_synthesize = [row for index, row in enumerate(rows, start=1) if slide_num_for_row(row, index) not in skipped_slides]
    auto_pipeline.generate_audios_from_rows(rows_to_synthesize)


def render_from_available_assets(rows: list[dict[str, str]], skipped_slides: set[int], output: Path, include_unscripted_slides: bool) -> Path:
    try:
        from moviepy.editor import AudioFileClip, ImageClip, VideoFileClip, concatenate_videoclips
    except ImportError as exc:
        raise SystemExit("moviepy が必要です。仮想環境で `python3 -m pip install moviepy` を実行してください。") from exc

    slides = toho_movie_studio.indexed_slides()
    audios = toho_movie_studio.indexed_audios()
    script_numbers = [slide_num_for_row(row, index) for index, row in enumerate(rows, start=1)]
    numbers = sorted(set(script_numbers) | (set(slides) if include_unscripted_slides else set()), key=int)
    clips = []

    for number in numbers:
        if number in skipped_slides:
            continue
        slide = slides.get(number) or auto_pipeline._slide_image_path(number)
        if slide is None or not slide.exists():
            print(f"warning: slide {number} の画像が見つからないためスキップします。", file=sys.stderr)
            continue

        audio = audios.get(number) or (auto_pipeline.AUDIO_DIR / f"slide_{number}.wav")
        slide_mov = next((path for path in slide.parent.glob("*.mov") if toho_movie_studio.slide_number(path) == number), None)

        if slide_mov and slide_mov.exists():
            video_clip = VideoFileClip(str(slide_mov))
            duration = float(video_clip.duration)
            if audio and audio.exists():
                audio_clip = AudioFileClip(str(audio))
                duration = max(duration, float(audio_clip.duration))
                video_clip = video_clip.set_duration(duration).set_audio(audio_clip)
            clips.append(video_clip)
        elif audio and audio.exists():
            audio_clip = AudioFileClip(str(audio))
            clips.append(ImageClip(str(slide)).set_duration(audio_clip.duration).set_audio(audio_clip))
        elif include_unscripted_slides:
            clips.append(ImageClip(str(slide)).set_duration(3.0))

    if not clips:
        raise SystemExit("動画化できる素材がありません。slides/ と audios/ を確認してください。")

    output.parent.mkdir(parents=True, exist_ok=True)
    final = concatenate_videoclips(clips, method="compose")
    final.write_videofile(str(output), fps=24, codec="libx264", audio_codec="aac", temp_audiofile=str(output.with_name("rules_temp_audio.m4a")), remove_temp=True)
    return output


def run_all(args: argparse.Namespace) -> None:
    script_path = resolve_path(args.script) or SCRIPT_PATH
    if args.extract:
        keynote = find_keynote_file(args.keynote)
        extract_script_from_keynote(keynote, script_path)

    rows = read_script_rows(script_path)
    skipped_slides = ensure_no_blocking_issues(
        rows,
        allow_questions=args.allow_questions,
        has_highlight_choice=args.highlight_slide is not None or args.highlight_at is not None,
    )

    if not args.skip_audio:
        generate_audio_rows(rows, skipped_slides)

    output = resolve_path(args.output) or OUTPUT_DIR / "rules_output.mp4"
    result = render_from_available_assets(rows, skipped_slides, output, include_unscripted_slides=True)
    print(f"ルール準拠パイプライン完了: {rel(result)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="rules.html に沿って台本、音声、動画作成を一括実行します。")
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    check = subparsers.add_parser("check")
    check.add_argument("--script", default="script.csv")
    check.add_argument("--highlight-slide", type=int)
    check.add_argument("--highlight-at", type=float)
    check.add_argument("--json", action="store_true")

    extract = subparsers.add_parser("extract-script")
    extract.add_argument("--keynote", default="")
    extract.add_argument("--script", default="script.csv")

    run = subparsers.add_parser("all")
    run.add_argument("--keynote", default="")
    run.add_argument("--script", default="script.csv")
    run.add_argument("--output", default="exports/rules_output.mp4")
    run.add_argument("--extract", action="store_true", help="Keynoteからscript.csvを作り直します。rules.html/motoscript.csvは変更しません。")
    run.add_argument("--skip-audio", action="store_true")
    run.add_argument("--allow-questions", action="store_true", help="迷シーン候補などユーザー選択が必要な項目を警告扱いにします。")
    run.add_argument("--highlight-slide", type=int, help="ユーザーが選んだ迷シーンのスライド番号です。")
    run.add_argument("--highlight-at", type=float, help="ユーザーが選んだ迷シーンの開始秒です。")

    args = parser.parse_args()
    if args.subcommand == "check":
        rows = read_script_rows(resolve_path(args.script) or SCRIPT_PATH)
        issues, _skipped = detect_rule_issues(
            rows,
            has_highlight_choice=args.highlight_slide is not None or args.highlight_at is not None,
        )
        issues.extend(check_required_effects(rows))
        print_issues(issues, json_output=args.json)
        if any(issue.level == "error" for issue in issues):
            raise SystemExit(1)
    elif args.subcommand == "extract-script":
        extract_script_from_keynote(find_keynote_file(args.keynote), resolve_path(args.script) or SCRIPT_PATH)
    elif args.subcommand == "all":
        run_all(args)


if __name__ == "__main__":
    main()
