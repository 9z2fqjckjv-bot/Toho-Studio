#!/usr/bin/env python3
"""
東方Projectムービーメーカー (Mac版)
- bind 成功後にブラウザを自動オープン (auto-open-after-bind)
- 東方ムービーメーカ / 東方キャラ立ち絵スタジオ データフォルダ確保
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
from src import server as server_mod
from src.server import run_server

try:
    from src.core.path_utils import ensure_app_layout
except Exception:
    ensure_app_layout = None

PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))

CHROME_BINARIES = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
]


def start_auto_backup_timer(interval_sec: int = 600):
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
    threading.Thread(target=_backup_loop, daemon=True).start()


def wait_until_ready(url: str, timeout: float = 15.0) -> bool:
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
    if not wait_until_ready(url):
        print(f"[WARN] サーバ起動確認タイムアウト: {url}")
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


def install_open_after_bind():
    """run_server が bind に成功したあと、実際のポートでウィンドウを開く。"""
    OrigHTTPServer = server_mod.HTTPServer
    opened = {"done": False}

    class BindThenOpenServer(OrigHTTPServer):
        def server_activate(self):
            super().server_activate()
            if opened["done"]:
                return
            opened["done"] = True
            _host, port = self.server_address[:2]
            url = f"http://127.0.0.1:{port}"
            threading.Thread(target=launch_native_window, args=(url,), daemon=True).start()

    server_mod.HTTPServer = BindThenOpenServer


def main():
    reporter = get_crash_reporter()
    reporter.log_activity("Application Startup", {"args": sys.argv})

    if ensure_app_layout:
        try:
            ensure_app_layout(PROJECT_ROOT)
        except Exception as e:
            print(f"[WARN] ensure_app_layout: {e}")

    parser = argparse.ArgumentParser(description="東方Projectムービーメーカー (Mac版)")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--backup-interval", type=int, default=600)
    args = parser.parse_args()

    start_auto_backup_timer(args.backup_interval)
    get_tts_engine()

    if not args.no_browser:
        install_open_after_bind()

    try:
        run_server(args.port)
    except Exception as e:
        reporter.generate_report("Fatal Server Exception", str(e), {"port": args.port})
        raise


if __name__ == "__main__":
    main()
