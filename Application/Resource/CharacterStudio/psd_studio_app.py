#!/usr/bin/env python3
"""
東方Project キャラクタースタジオ (Mac用ソフト)
メインエントリーポイント
- macOS ネイティブアプリモード (Chrome Appモード / Safari) で独立ウィンドウ起動
- 東方キャラクターPSD（180+ファイル）の色彩・表情変換
- JPG, PNG, PXD, PSD エクスポート対応
"""

import os
import sys
import time
import socket
import argparse
import webbrowser
import subprocess
import threading

PROJECT_ROOT = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, PROJECT_ROOT)

from src.psd_studio_server import run_psd_server


def find_free_port(start_port: int = 8088) -> int:
    """利用可能な空きポートを検索"""
    for port in range(start_port, start_port + 50):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("", port))
                return port
            except OSError:
                continue
    return start_port


def launch_native_window(url: str):
    """
    Mac 上でブラウザのアドレスバー等を非表示にし、
    独立したネイティブアプリウィンドウとして起動
    """
    time.sleep(0.8)
    
    # 1. Chrome / Brave / Edge の App モード (独立ネイティブウィンドウ)
    browsers = [
        "/Applications/Google Chrome.app",
        "/Applications/Brave Browser.app",
        "/Applications/Microsoft Edge.app"
    ]
    for app in browsers:
        if os.path.exists(app):
            try:
                subprocess.Popen([
                    "open", "-n", "-a", app,
                    "--args", f"--app={url}", "--window-size=1440,920"
                ])
                print(f"[UI] ネイティブウィンドウ起動成功 ({app})")
                return
            except Exception as e:
                print(f"[WARN] ネイティブ起動フォールバック: {e}")

    # 2. Safari / デフォルトブラウザ (フォールバック)
    print(f"[UI] ブラウザで起動: {url}")
    webbrowser.open(url)


def main():
    parser = argparse.ArgumentParser(description="東方Project キャラクタースタジオ (Mac版)")
    parser.add_argument("--port", type=int, default=8088, help="サーバーのポート番号 (デフォルト: 8088)")
    parser.add_argument("--no-browser", action="store_true", help="起動時にウィンドウを自動で開かない")
    args = parser.parse_args()

    port = find_free_port(args.port)
    url = f"http://localhost:{port}"

    print("=" * 60)
    print("🌸 東方Project キャラクタースタジオ (Toho Character PSD Studio)")
    print(f"   URL: {url}")
    print("=" * 60)

    if not args.no_browser:
        threading.Thread(target=launch_native_window, args=(url,), daemon=True).start()

    try:
        run_psd_server(port)
    except KeyboardInterrupt:
        print("\n[INFO] キャラクタースタジオを終了しました。")


if __name__ == "__main__":
    main()
