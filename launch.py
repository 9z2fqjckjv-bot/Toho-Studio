#!/usr/bin/env python3
"""Start app.py and psd_studio_app.py from Terminal on this Mac.

The project files live in a Drive-synced folder (often not fully pushed to git).
Override the project root with --project or TOHO_PROJECT_ROOT.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_NAME = "Toho-Project-Second-Story"
RELATIVE_HINT = Path("ZSSD") / "GitHub" / "repository" / REPO_NAME
TARGETS = ("app.py", "psd_studio_app.py")


def _looks_like_project(root: Path) -> bool:
    return (root / "app.py").is_file() or (root / "psd_studio_app.py").is_file()


def resolve_project_root(explicit: str | None) -> Path:
    if explicit:
        root = Path(explicit).expanduser().resolve()
        if not root.is_dir():
            raise SystemExit(f"指定したフォルダがありません: {root}")
        return root

    env = os.environ.get("TOHO_PROJECT_ROOT")
    if env:
        root = Path(env).expanduser().resolve()
        if not root.is_dir():
            raise SystemExit(f"TOHO_PROJECT_ROOT がありません: {root}")
        return root

    here = Path(__file__).resolve().parent
    for candidate in (here, Path.cwd().resolve()):
        if _looks_like_project(candidate):
            return candidate

    home = Path.home()
    guessed = (home / RELATIVE_HINT).resolve()
    if guessed.is_dir() and _looks_like_project(guessed):
        return guessed

    cloud = home / "Library" / "CloudStorage"
    if cloud.is_dir():
        matches = [
            p
            for p in cloud.glob(f"*/{RELATIVE_HINT.as_posix()}")
            if p.is_dir() and _looks_like_project(p)
        ]
        if len(matches) == 1:
            return matches[0]
        if len(matches) > 1:
            listing = "\n".join(f"  {m}" for m in matches)
            raise SystemExit(
                "候補が複数あります。--project で指定してください:\n" + listing
            )

    raise SystemExit(
        "プロジェクトフォルダが見つかりませんでした。\n"
        f"  --project /path/to/{REPO_NAME}\n"
        "  または環境変数 TOHO_PROJECT_ROOT を設定してください。\n"
        f"想定パスの例: ~/{RELATIVE_HINT.as_posix()}"
    )


def pick_python(project_root: Path) -> str:
    venv_py = project_root / ".venv" / "bin" / "python"
    if venv_py.is_file():
        return str(venv_py)
    found = shutil.which("python3") or shutil.which("python")
    if not found:
        raise SystemExit("python3 が見つかりません。")
    return found


def find_script(project_root: Path, name: str) -> Path | None:
    direct = project_root / name
    if direct.is_file():
        return direct
    for sub in ("src", "apps", "scripts", "python"):
        nested = project_root / sub / name
        if nested.is_file():
            return nested
    return None


def start(python: str, script: Path, project_root: Path) -> subprocess.Popen:
    print(f"起動: {script.name}  ({script})")
    return subprocess.Popen(
        [python, str(script)],
        cwd=str(project_root),
        start_new_session=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Mac のターミナルから app.py と psd_studio_app.py を起動する"
    )
    parser.add_argument(
        "--project",
        help=f"{REPO_NAME} フォルダのパス（省略時は自動検出）",
    )
    args = parser.parse_args()

    root = resolve_project_root(args.project)
    python = pick_python(root)
    print(f"プロジェクト: {root}")
    print(f"Python: {python}")

    started = []
    missing = []
    for name in TARGETS:
        path = find_script(root, name)
        if path is None:
            missing.append(name)
            print(f"見つからない: {name}（{root} とその直下 src/apps/scripts/python）")
            continue
        proc = start(python, path, root)
        started.append((name, proc.pid))
        print(f"  PID {proc.pid}")

    if not started:
        print("起動できたプログラムがありません。", file=sys.stderr)
        return 1

    print("\n起動済み:")
    for name, pid in started:
        print(f"  {name}  pid={pid}")
    if missing:
        print("未起動:")
        for name in missing:
            print(f"  {name}")
        print("ファイルをプロジェクト直下に置いてから再実行してください。")
    print("止めるとき: kill " + " ".join(str(pid) for _, pid in started))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
