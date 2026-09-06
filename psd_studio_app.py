#!/usr/bin/env python3
"""東方Project キャラクタースタジオ (Mac用ソフト)"""
import os, sys, time, socket, argparse, webbrowser, subprocess, threading
PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, PROJECT_ROOT)
from src.psd_studio_server import run_psd_server
try:
    from src.core.path_utils import ensure_app_layout
except Exception:
    ensure_app_layout = None

def find_free_port(start_port: int = 8088) -> int:
    for port in range(start_port, start_port + 50):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("", port))
                return port
            except OSError:
                continue
    return start_port

def launch_native_window(url: str):
    time.sleep(0.8)
    for app in ["/Applications/Google Chrome.app", "/Applications/Brave Browser.app", "/Applications/Microsoft Edge.app"]:
        if os.path.exists(app):
            try:
                subprocess.Popen(["open", "-n", "-a", app, "--args", f"--app={url}", "--window-size=1440,920"])
                print(f"[UI] ネイティブウィンドウ起動成功 ({app})")
                return
            except Exception as e:
                print(f"[WARN] {e}")
    webbrowser.open(url)

def main():
    parser = argparse.ArgumentParser(description="東方Project キャラクタースタジオ (Mac版)")
    parser.add_argument("--port", type=int, default=8088)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    if ensure_app_layout:
        try:
            ensure_app_layout(PROJECT_ROOT)
        except Exception as e:
            print(f"[WARN] ensure_app_layout: {e}")
    port = find_free_port(args.port)
    url = f"http://localhost:{port}"
    print("=" * 60)
    print("🌸 東方Project キャラクタースタジオ")
    print(f"   URL: {url}")
    print("=" * 60)
    if not args.no_browser:
        threading.Thread(target=launch_native_window, args=(url,), daemon=True).start()
    try:
        run_psd_server(port)
    except KeyboardInterrupt:
        print("\n[INFO] 終了しました。")

if __name__ == "__main__":
    main()
