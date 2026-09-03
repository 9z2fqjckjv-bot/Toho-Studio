#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

BASE_DIR = Path(__file__).resolve().parent
VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v"}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg"}
AUDIO_EXTENSIONS = {".wav", ".mp3", ".m4a", ".aac", ".aif", ".aiff"}
PLAN_PATH = BASE_DIR / "movie_studio_plan.json"


def rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(BASE_DIR))
    except ValueError:
        return str(path)


def resolve_path(value: str | None) -> Path | None:
    if not value:
        return None
    path = Path(value).expanduser()
    return path if path.is_absolute() else BASE_DIR / path


def natural_key(path: Path | str) -> list[Any]:
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", str(path))]


def scan_assets() -> dict[str, list[str]]:
    videos: list[Path] = []
    slides: list[Path] = []
    audios: list[Path] = []
    scripts: list[Path] = []

    ignored_parts = {".git", ".venv", "__pycache__", ".build"}
    for path in BASE_DIR.rglob("*"):
        if not path.is_file() or ignored_parts.intersection(path.parts):
            continue
        suffix = path.suffix.lower()
        if suffix in VIDEO_EXTENSIONS:
            videos.append(path)
        elif suffix in IMAGE_EXTENSIONS and ("slides" in path.parts or "Movie archive" in path.parts):
            slides.append(path)
        elif suffix in AUDIO_EXTENSIONS:
            audios.append(path)
        elif suffix == ".csv":
            scripts.append(path)

    bgm = [path for path in audios if any(word in path.stem.lower() for word in ("bgm", "music", "loop"))]
    sound_effects = [path for path in audios if any(word in path.stem.lower() for word in ("se", "sfx", "effect", "効果音"))]

    return {
        "videos": [rel(path) for path in sorted(videos, key=natural_key)],
        "slides": [rel(path) for path in sorted(slides, key=natural_key)],
        "audios": [rel(path) for path in sorted(audios, key=natural_key)],
        "bgm": [rel(path) for path in sorted(bgm, key=natural_key)],
        "soundEffects": [rel(path) for path in sorted(sound_effects, key=natural_key)],
        "scripts": [rel(path) for path in sorted(scripts, key=natural_key)],
    }


def read_script_rows(script_path: Path) -> list[dict[str, str]]:
    if not script_path.exists():
        return []
    with script_path.open("r", encoding="utf-8") as file:
        return [row for row in csv.DictReader(file) if any((value or "").strip() for value in row.values())]


def slide_number(path: Path) -> int | None:
    patterns = [r"slide[_ -]?(\d+)", r"\.(\d{3})$", r"(\d+)"]
    stem = path.stem
    for pattern in patterns:
        match = re.search(pattern, stem)
        if match:
            return int(match.group(1))
    return None


def load_audio_duration(path: Path | None) -> float | None:
    if path is None or not path.exists():
        return None
    try:
        from moviepy.editor import AudioFileClip
    except ImportError:
        return None

    clip = AudioFileClip(str(path))
    try:
        return float(clip.duration)
    finally:
        clip.close()


def load_video_duration(path: Path | None) -> float | None:
    if path is None or not path.exists():
        return None
    try:
        from moviepy.editor import VideoFileClip
    except ImportError:
        return None

    clip = VideoFileClip(str(path))
    try:
        return float(clip.duration)
    finally:
        clip.close()


def indexed_slides() -> dict[int, Path]:
    slides = [resolve_path(item) for item in scan_assets()["slides"]]
    indexed: dict[int, Path] = {}
    for path in slides:
        if path is None or not path.exists():
            continue
        number = slide_number(path)
        if number is not None and number not in indexed:
            indexed[number] = path
    return indexed


def indexed_audios() -> dict[int, Path]:
    audios = [resolve_path(item) for item in scan_assets()["audios"]]
    indexed: dict[int, Path] = {}
    for path in audios:
        if path is None or not path.exists():
            continue
        number = slide_number(path)
        if number is not None and number not in indexed:
            indexed[number] = path
    return indexed


def analyze_project(args: argparse.Namespace) -> dict[str, Any]:
    script_path = resolve_path(args.script) or BASE_DIR / "script.csv"
    input_video = resolve_path(args.input)
    rows = read_script_rows(script_path)
    slides = indexed_slides()
    audios = indexed_audios()
    default_duration = float(args.extra_slide_seconds)

    script_by_slide: dict[int, dict[str, str]] = {}
    ordered_script_numbers: list[int] = []
    for index, row in enumerate(rows, start=1):
        raw_number = row.get("slide_num") or str(index)
        if not str(raw_number).strip().isdigit():
            continue
        number = int(raw_number)
        script_by_slide[number] = row
        ordered_script_numbers.append(number)

    known_video_time_by_slide: dict[int, float] = {}
    running_time = 0.0
    for number in ordered_script_numbers:
        known_video_time_by_slide[number] = running_time
        audio = audios.get(number)
        running_time += load_audio_duration(audio) or default_duration

    all_numbers = sorted(set(slides.keys()) | set(script_by_slide.keys()) | set(audios.keys()))
    scenes: list[dict[str, Any]] = []
    previous_video_time = 0.0
    missing_count = 0
    matched_count = 0

    for number in all_numbers:
        row = script_by_slide.get(number)
        slide = slides.get(number)
        audio = audios.get(number)
        in_script = row is not None
        present_in_video = in_script and audio is not None
        if present_in_video:
            matched_count += 1
            previous_video_time = known_video_time_by_slide.get(number, previous_video_time)
        else:
            missing_count += 1

        duration = load_audio_duration(audio) or default_duration
        scenes.append(
            {
                "id": f"slide-{number}",
                "slideNumber": number,
                "slide": rel(slide) if slide else "",
                "audio": rel(audio) if audio else "",
                "character": (row or {}).get("character", ""),
                "scriptText": (row or {}).get("text", ""),
                "duration": round(duration, 2),
                "at": int(round(known_video_time_by_slide.get(number, previous_video_time))),
                "inScript": in_script,
                "hasAudio": audio is not None,
                "presentInVideo": present_in_video,
                "needsInsertion": not present_in_video and slide is not None,
                "se": "",
            }
        )

    planned = [scene for scene in scenes if scene["needsInsertion"]]
    return {
        "inputVideo": rel(input_video) if input_video else "",
        "script": rel(script_path),
        "videoDuration": load_video_duration(input_video),
        "scriptSceneCount": len(ordered_script_numbers),
        "matchedSceneCount": matched_count,
        "missingSceneCount": missing_count,
        "scenes": scenes,
        "plannedExtraScenes": planned,
    }


def load_script_slide_numbers(script_path: Path) -> set[int]:
    return {scene["slideNumber"] for scene in analyze_project(argparse.Namespace(script=str(script_path), input="", extra_slide_seconds="3.0"))["scenes"] if scene["inScript"]}


def discover_extra_slides(script_path: Path) -> list[Path]:
    analysis = analyze_project(argparse.Namespace(script=str(script_path), input="", extra_slide_seconds="3.0"))
    return [path for scene in analysis["plannedExtraScenes"] if (path := resolve_path(scene["slide"]))]


def load_plan(path: Path = PLAN_PATH) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


@dataclass
class SceneSpec:
    slide: Path
    at: float | None
    duration: float
    se: Path | None


def scene_specs_from_plan(plan: dict[str, Any], default_duration: float, default_se: Path | None) -> list[SceneSpec]:
    specs: list[SceneSpec] = []
    for raw in plan.get("extra_scenes", []):
        if not isinstance(raw, dict) or raw.get("enabled") is False:
            continue
        slide = resolve_path(raw.get("slide"))
        if slide is None or not slide.exists():
            continue
        specs.append(
            SceneSpec(
                slide=slide,
                at=float(raw["at"]) if raw.get("at") not in (None, "") else None,
                duration=float(raw.get("duration", default_duration)),
                se=resolve_path(raw.get("se")) or default_se,
            )
        )
    return sorted(specs, key=lambda spec: (float(spec.at or 0), natural_key(spec.slide)))


def inferred_scene_specs(script_path: Path, input_video: Path | None, default_duration: float, default_se: Path | None) -> list[SceneSpec]:
    analysis = analyze_project(argparse.Namespace(script=str(script_path), input=str(input_video or ""), extra_slide_seconds=str(default_duration)))
    specs: list[SceneSpec] = []
    for scene in analysis["plannedExtraScenes"]:
        slide = resolve_path(scene["slide"])
        if slide is not None:
            specs.append(SceneSpec(slide=slide, at=float(scene["at"]), duration=float(scene["duration"]), se=default_se))
    return specs


def resize_image_clip(image_clip, target_size: tuple[int, int]):
    width, height = target_size
    return image_clip.resize(height=height).on_color(size=(width, height), color=(0, 0, 0), pos=("center", "center"))


def emit_progress(enabled: bool, **payload: Any) -> None:
    if enabled:
        print(json.dumps({"type": "progress", **payload}, ensure_ascii=False), flush=True)


def export_video(args: argparse.Namespace) -> None:
    try:
        from moviepy.editor import AudioFileClip, CompositeAudioClip, ImageClip, VideoFileClip, concatenate_videoclips
        from moviepy.audio.fx.all import audio_loop
    except ImportError as exc:
        raise SystemExit("moviepy が必要です。仮想環境で `python3 -m pip install moviepy` を実行してください。") from exc

    input_video = resolve_path(args.input)
    script_path = resolve_path(args.script) or BASE_DIR / "script.csv"
    output_path = resolve_path(args.output) or BASE_DIR / "studio_export.mp4"
    bgm_path = resolve_path(args.bgm)
    se_path = resolve_path(args.se)
    default_duration = float(args.extra_slide_seconds)
    progress_json = bool(getattr(args, "progress_json", False))

    if input_video is None or not input_video.exists():
        raise SystemExit(f"入力動画が見つかりません: {args.input}")

    plan_path = resolve_path(getattr(args, "plan", "")) or PLAN_PATH
    plan = load_plan(plan_path)
    if not bgm_path:
        bgm_path = resolve_path(plan.get("bgm"))
    scene_specs = scene_specs_from_plan(plan, default_duration, se_path) or inferred_scene_specs(script_path, input_video, default_duration, se_path)

    started_at = time.monotonic()
    total_scenes = len(scene_specs)
    emit_progress(
        progress_json,
        phase="準備中",
        totalScenes=total_scenes,
        completedScenes=0,
        remainingScenes=total_scenes,
        elapsedSeconds=0,
        estimatedRemainingSeconds=None,
    )

    video = VideoFileClip(str(input_video))
    target_size = tuple(video.size)
    clips = []
    scene_starts: list[tuple[SceneSpec, float]] = []
    leading_specs = [spec for spec in scene_specs if spec.at is None or spec.at <= 0]
    timed_specs = sorted(
        [spec for spec in scene_specs if spec.at is not None and spec.at > 0],
        key=lambda spec: float(spec.at or 0),
    )

    def report_scene_progress(completed: int) -> None:
        elapsed = time.monotonic() - started_at
        remaining = max(total_scenes - completed, 0)
        estimated = (elapsed / completed * remaining) if completed > 0 and remaining > 0 else None
        emit_progress(
            progress_json,
            phase="シーン準備中",
            totalScenes=total_scenes,
            completedScenes=completed,
            remainingScenes=remaining,
            elapsedSeconds=round(elapsed, 1),
            estimatedRemainingSeconds=round(estimated, 1) if estimated is not None else None,
        )

    completed_scenes = 0
    current_start = 0.0
    for spec in leading_specs:
        scene_starts.append((spec, current_start))
        clips.append(resize_image_clip(ImageClip(str(spec.slide)).set_duration(spec.duration), target_size))
        current_start += spec.duration
        completed_scenes += 1
        report_scene_progress(completed_scenes)

    source_position = 0.0
    inserted_duration = current_start
    for spec in timed_specs:
        at = min(max(float(spec.at or 0), 0), float(video.duration))
        if at > source_position:
            clips.append(video.subclip(source_position, at))
        scene_starts.append((spec, inserted_duration + at))
        clips.append(resize_image_clip(ImageClip(str(spec.slide)).set_duration(spec.duration), target_size))
        inserted_duration += spec.duration
        source_position = at
        completed_scenes += 1
        report_scene_progress(completed_scenes)

    if source_position < video.duration:
        clips.append(video.subclip(source_position, video.duration))
    final = concatenate_videoclips(clips, method="compose") if len(clips) > 1 else video

    audio_layers = []
    if final.audio is not None:
        audio_layers.append(final.audio)

    for spec, start in scene_starts:
        if spec.se and spec.se.exists():
            audio_layers.append(AudioFileClip(str(spec.se)).set_start(start))

    if bgm_path and bgm_path.exists():
        bgm = audio_loop(AudioFileClip(str(bgm_path)).volumex(float(args.bgm_volume)), duration=final.duration)
        audio_layers.append(bgm)

    if audio_layers:
        final = final.set_audio(CompositeAudioClip(audio_layers))

    emit_progress(
        progress_json,
        phase="動画を書き出し中",
        totalScenes=total_scenes,
        completedScenes=total_scenes,
        remainingScenes=0,
        elapsedSeconds=round(time.monotonic() - started_at, 1),
        estimatedRemainingSeconds=None,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    final.write_videofile(
        str(output_path),
        fps=int(args.fps),
        codec="libx264",
        audio_codec="aac",
        temp_audiofile=str(output_path.with_name("studio_temp_audio.m4a")),
        remove_temp=True,
    )
    elapsed = time.monotonic() - started_at
    emit_progress(
        progress_json,
        phase="完了",
        totalScenes=total_scenes,
        completedScenes=total_scenes,
        remainingScenes=0,
        elapsedSeconds=round(elapsed, 1),
        estimatedRemainingSeconds=0,
        output=rel(output_path),
    )
    print(f"書き出し完了: {rel(output_path)}")
    if scene_specs:
        print("挿入したスライド:")
        for spec in scene_specs:
            at_label = "先頭" if spec.at is None else f"{spec.at:.0f}s"
            print(f"- {rel(spec.slide)} ({spec.duration:.1f}s / {at_label})")
    else:
        print("挿入対象のスライドは見つかりませんでした。")


def run_existing(command: str, args: argparse.Namespace) -> None:
    env = os.environ.copy()
    env.setdefault("PYTHONUNBUFFERED", "1")
    python = BASE_DIR / ".venv/bin/python"
    executable = str(python if python.exists() else Path(sys.executable))

    if command == "aquestalk":
        subprocess.Popen([executable, "aquestalk_local_api.py"], cwd=BASE_DIR, env=env)
        print("AquesTalk API を起動しました: http://localhost:50021")
        return

    if command == "extract-script":
        key_files = sorted((BASE_DIR / "slides").rglob("*.key"), key=natural_key)
        if not key_files:
            raise SystemExit("slides/ 以下に .key ファイルが見つかりません。")
        output = resolve_path(args.script) or BASE_DIR / "script.csv"
        subprocess.run([executable, "keynote_telop_to_csv.py", str(key_files[0]), "-o", str(output)], cwd=BASE_DIR, env=env, check=True)
        return

    if command == "pipeline":
        script = resolve_path(args.script)
        if script and script.exists() and script.resolve() != (BASE_DIR / "script.csv").resolve():
            shutil.copyfile(script, BASE_DIR / "script.csv")
        subprocess.run([executable, "auto_pipeline.py"], cwd=BASE_DIR, env=env, check=True)
        return

    raise SystemExit(f"未対応のコマンドです: {command}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Toho Project Second Story movie studio helper")
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    scan = subparsers.add_parser("scan")
    scan.add_argument("--json", action="store_true")

    analyze = subparsers.add_parser("analyze")
    analyze.add_argument("--input", default="")
    analyze.add_argument("--script", default="script.csv")
    analyze.add_argument("--extra-slide-seconds", default="3.0")
    analyze.add_argument("--json", action="store_true")

    run = subparsers.add_parser("run")
    run.add_argument("command", choices=["aquestalk", "extract-script", "pipeline"])
    run.add_argument("--script", default="script.csv")

    export = subparsers.add_parser("export")
    export.add_argument("--input", required=True)
    export.add_argument("--script", default="script.csv")
    export.add_argument("--output", default="studio_export.mp4")
    export.add_argument("--bgm", default="")
    export.add_argument("--se", default="")
    export.add_argument("--plan", default="movie_studio_plan.json")
    export.add_argument("--bgm-volume", default="0.22")
    export.add_argument("--extra-slide-seconds", default="3.0")
    export.add_argument("--fps", default="24")
    export.add_argument("--progress-json", action="store_true")

    args = parser.parse_args()
    if args.subcommand == "scan":
        manifest = scan_assets()
        if args.json:
            print(json.dumps(manifest, ensure_ascii=False, indent=2))
        else:
            for key, values in manifest.items():
                print(f"[{key}]")
                for value in values:
                    print(value)
    elif args.subcommand == "analyze":
        analysis = analyze_project(args)
        if args.json:
            print(json.dumps(analysis, ensure_ascii=False, indent=2))
        else:
            print(f"台本シーン: {analysis['scriptSceneCount']}")
            print(f"照合済み: {analysis['matchedSceneCount']}")
            print(f"追加候補: {analysis['missingSceneCount']}")
            for scene in analysis["plannedExtraScenes"]:
                print(f"- {scene['slide']} at {scene['at']}s")
    elif args.subcommand == "run":
        run_existing(args.command, args)
    elif args.subcommand == "export":
        export_video(args)


if __name__ == "__main__":
    main()
