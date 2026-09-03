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

from src.core.crash_reporter import get_crash_reporter
from src.core.project_manager import get_project_manager
from src.core.tts_engine import get_tts_engine
from src.server import run_server

PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))


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


def launch_native_window(url: str):
    time.sleep(0.8)
    chrome_paths = [
        "/Applications/Google Chrome.app",
        "/Applications/Brave Browser.app",
        "/Applications/Microsoft Edge.app"
    ]
    for app in chrome_paths:
        if os.path.exists(app):
            try:
                subprocess.Popen(["open", "-n", "-a", app, "--args", f"--app={url}", "--window-size=1440,900"])
                return
            except Exception:
                pass
    webbrowser.open(url)


def main():
    reporter = get_crash_reporter()
    reporter.log_activity("Application Startup", {"args": sys.argv})

    parser = argparse.ArgumentParser(description="東方Projectムービーメーカー (Mac版)")
    parser.add_argument("--port", type=int, default=8080, help="サーバーのポート番号 (デフォルト: 8080)")
    parser.add_argument("--no-browser", action="store_true", help="起動時にウィンドウを自動で開かない")
    parser.add_argument("--backup-interval", type=int, default=600, help="自動バックアップ間隔(秒, デフォルト600秒=10分)")

    args = parser.parse_args()
    start_auto_backup_timer(args.backup_interval)
    get_tts_engine()

    port = args.port
    url = f"http://localhost:{port}"

    if not args.no_browser:
        threading.Thread(target=launch_native_window, args=(url,), daemon=True).start()

    try:
        run_server(port)
    except Exception as e:
        reporter.generate_report("Fatal Server Exception", str(e), {"port": port})
        raise


if __name__ == "__main__":
    main()
