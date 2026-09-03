#!/usr/bin/env python3
"""
東方Projectムービーメーカー (Mac版)
メインエントリーポイント
- macOS ネイティブ動画編集アプリモード / ブラウザモード
- クラッシュ検出 & レポート自動保存 (要件14)
- 10分おき自動バックアップタイマー (要件7)
- Keynote / PowerPoint / YMM4 / Final Cut Pro 連携
"""

import os
import sys
import argparse
import webbrowser
import threading
import time
import subprocess
import urllib.error
import urllib.request

from src.core.crash_reporter import get_crash_reporter
from src.core.project_manager import get_project_manager
from src.core.tts_engine import get_tts_engine
from src.server import run_server

PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))

CHROME_BINARIES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
]


def start_auto_backup_timer(interval_sec: int = 600):
    """10分おきに安全なローカル一時バックアップをバックグラウンド実行 (要件7)"""
    def _backup_loop():
        pm = get_project_manager()
        while True:
            time.sleep(interval_sec)
            try:
                if pm.current_project:
                    saved_path = pm.save_temporary_backup()
                    if saved_path:
                        print(f"[AUTO-BACKUP] 10分定期バックアップ保存完了: {os.path.basename(saved_path)}")
            except Exception as e:
                print(f"[WARN] Auto backup error: {e}")

    t = threading.Thread(target=_backup_loop, daemon=True)
    t.start()


def wait_until_ready(url: str, timeout: float = 15.0) -> bool:
    """HTTP 応答が返るまで待つ。TCP だけだと serve_forever 前に Chrome が空応答になる。"""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(url, timeout=0.5)
            return True
        except urllib.error.HTTPError:
            return True
        except (OSError, urllib.error.URLError):
            time.sleep(0.1)
    return False


def launch_native_window(url: str):
    """
    Mac 上でブラウザのアドレスバー等を非表示にし、
    独立したネイティブアプリウィンドウとして起動。
    Chrome 系はバイナリを直接呼び、open --args がフラグを落とす問題を避ける。
    """
    if not wait_until_ready(url):
        print(f"[WARN] サーバの起動確認がタイムアウトしました。手動で開いてください: {url}")

    for binary in CHROME_BINARIES:
        if os.path.isfile(binary):
            try:
                subprocess.Popen(
                    [binary, f"--app={url}", "--window-size=1440,900"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                return
            except Exception:
                pass

    webbrowser.open(url)


def main():
    # 1. クラッシュレポーターの初期化 (要件14)
    reporter = get_crash_reporter()
    reporter.log_activity("Application Startup", {"args": sys.argv})

    parser = argparse.ArgumentParser(description="東方Projectムービーメーカー (Mac版)")
    parser.add_argument("--port", type=int, default=8080, help="サーバーのポート番号 (デフォルト: 8080)")
    parser.add_argument("--no-browser", action="store_true", help="起動時にウィンドウを自動で開かない")
    parser.add_argument("--backup-interval", type=int, default=600, help="自動バックアップ間隔(秒, デフォルト600秒=10分)")

    args = parser.parse_args()

    # 2. 自動バックアップタイマーの開始 (要件7)
    start_auto_backup_timer(args.backup_interval)

    # 3. 音声合成エンジンのプリロード
    get_tts_engine()

    def on_ready(url: str):
        if not args.no_browser:
            threading.Thread(target=launch_native_window, args=(url,), daemon=True).start()

    # 4. サーバー開始（bind 成功後に on_ready でウィンドウを開く）
    try:
        run_server(args.port, on_ready=on_ready)
    except Exception as e:
        reporter.generate_report("Fatal Server Exception", str(e), {"port": args.port})
        raise


if __name__ == "__main__":
    main()
