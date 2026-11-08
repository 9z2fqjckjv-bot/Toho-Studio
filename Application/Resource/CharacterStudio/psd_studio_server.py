#!/usr/bin/env python3
"""
東方Project キャラクタースタジオ - ローカル HTTP & REST API サーバー
- 内蔵キャラクターPSD素材（200+ファイル）のスキャン・提供
- PSDバイナリの高速ストリーミング
- PNG / JPG / PXD / PSD エクスポートファイルのローカル直接保存
- Webフロントエンド（HTML/CSS/JS/Vendor）の配信
"""

import os
import sys
import json
import base64
import urllib.parse
import mimetypes
from http.server import HTTPServer, SimpleHTTPRequestHandler
from typing import Dict, Any, List

SCRIPT_DIR = os.path.abspath(os.path.dirname(__file__))
WEB_PSD_DIR = os.path.join(SCRIPT_DIR, "web_psd")

# 候補ディレクトリを探索
CHARACTERS_CANDIDATES = [
    "/Volumes/ZSSD/動画用/キャラクター",
    "/Volumes/ZSSD/GitHub/repository/TohoStudio/New/Application/Documents/参考資料/動画用/キャラクター",
    os.path.abspath(os.path.join(SCRIPT_DIR, "../../../New/Application/Documents/参考資料/動画用/キャラクター")),
    os.path.abspath(os.path.join(SCRIPT_DIR, "../../動画用/キャラクター")),
]

EXPORT_CANDIDATES = [
    "/Volumes/ZSSD/動画用/手作り素材/立絵スタジオ",
    "/Volumes/ZSSD/GitHub/repository/TohoStudio/New/Application/Documents/参考資料/動画用/手作り素材/立絵スタジオ",
    os.path.abspath(os.path.join(SCRIPT_DIR, "../../../New/Application/Documents/参考資料/動画用/手作り素材/立絵スタジオ")),
]

def get_characters_dir() -> str:
    for c in CHARACTERS_CANDIDATES:
        if os.path.exists(c):
            return c
    return CHARACTERS_CANDIDATES[0]

def get_export_dir() -> str:
    for e in EXPORT_CANDIDATES:
        if os.path.exists(e):
            return e
    target = EXPORT_CANDIDATES[0]
    os.makedirs(target, exist_ok=True)
    return target

CHARACTERS_DIR = get_characters_dir()
EXPORT_DIR = get_export_dir()


def scan_character_psds() -> List[Dict[str, Any]]:
    """
    動画用/キャラクター 配下の全PSDファイルを走査し、
    キャラクター名・衣装/差分・ファイル情報の一覧を生成
    """
    if not os.path.exists(CHARACTERS_DIR):
        return []

    characters_list = []
    
    for root, dirs, files in os.walk(CHARACTERS_DIR):
        for file in files:
            if file.lower().endswith(".psd"):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, CHARACTERS_DIR)
                parts = rel_path.split(os.sep)
                
                # カテゴリフォルダの判定
                category_dirs = {"主人公たち", "古明地姉妹", "紅魔館", "永遠亭", "河童", "妖精・妖怪", "冥界・白玉楼", "守矢神社", "地霊殿", "月・輝夜"}
                
                if len(parts) >= 3 and parts[0] in category_dirs:
                    category = parts[0]
                    char_name = parts[1]
                    variation_parts = parts[2:-1]
                    filename_no_ext = os.path.splitext(file)[0]
                elif len(parts) >= 2:
                    category = "東方Project"
                    char_name = parts[0]
                    variation_parts = parts[1:-1]
                    filename_no_ext = os.path.splitext(file)[0]
                else:
                    category = "その他"
                    char_name = os.path.splitext(file)[0]
                    variation_parts = []
                    filename_no_ext = char_name

                # バリエーション名の整形
                var_name = "通常"
                if variation_parts:
                    clean_vars = [p for p in variation_parts if p != char_name]
                    if clean_vars:
                        var_name = " / ".join(clean_vars)
                    elif filename_no_ext != char_name and filename_no_ext:
                        var_name = filename_no_ext
                elif filename_no_ext != char_name and filename_no_ext:
                    var_name = filename_no_ext

                try:
                    file_size = os.path.getsize(full_path)
                except OSError:
                    file_size = 0

                characters_list.append({
                    "category": category,
                    "name": char_name,
                    "variation": var_name,
                    "filename": file,
                    "rel_path": rel_path,
                    "full_path": full_path,
                    "size": file_size,
                    "size_str": f"{file_size / (1024 * 1024):.1f} MB" if file_size >= 1024 * 1024 else f"{file_size / 1024:.0f} KB"
                })

    characters_list.sort(key=lambda x: (x["name"], x["variation"]))
    return characters_list


class PSDStudioRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_PSD_DIR, **kwargs)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def _send_json(self, data: Any, status: int = 200):
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def _send_error(self, message: str, status: int = 400):
        self._send_json({"success": False, "error": message}, status=status)

    def _read_body_json(self) -> Dict[str, Any]:
        content_len = int(self.headers.get("Content-Length", 0))
        if content_len == 0:
            return {}
        body_bytes = self.rfile.read(content_len)
        return json.loads(body_bytes.decode("utf-8"))

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        # 1. API: キャラクター一覧取得
        if path == "/api/characters":
            try:
                characters = scan_character_psds()
                self._send_json({
                    "success": True,
                    "count": len(characters),
                    "characters": characters,
                    "characters_dir": CHARACTERS_DIR,
                    "export_dir": EXPORT_DIR
                })
            except Exception as e:
                self._send_error(f"Failed to scan characters: {str(e)}", status=500)
            return

        # 2. API: 指定されたPSDファイルをバイナリ配信
        elif path == "/api/psd_file":
            rel_path = query.get("path", [""])[0]
            if not rel_path:
                self._send_error("Missing 'path' parameter", status=400)
                return

            full_path = os.path.abspath(os.path.join(CHARACTERS_DIR, rel_path))
            if not os.path.exists(full_path):
                # full_path 直接指定のフォールバック
                if os.path.exists(rel_path):
                    full_path = rel_path
                else:
                    self._send_error(f"PSD file not found: {rel_path}", status=404)
                    return

            try:
                with open(full_path, "rb") as f:
                    content = f.read()

                self.send_response(200)
                self.send_header("Content-Type", "image/vnd.adobe.photoshop")
                self.send_header("Content-Length", str(len(content)))
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Cache-Control", "public, max-age=3600")
                self.end_headers()
                self.wfile.write(content)
            except Exception as e:
                self._send_error(f"Failed to read PSD: {str(e)}", status=500)
            return

        # 3. 静的ファイルの配信
        super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        # API: エクスポートファイルのローカル直接保存
        if path == "/api/save_export":
            try:
                body = self._read_body_json()
                filename = body.get("filename", "export.png")
                data_base64 = body.get("data", "")
                subfolder = body.get("subfolder", "")

                if not data_base64:
                    self._send_error("Missing 'data' parameter", status=400)
                    return

                if "," in data_base64:
                    data_base64 = data_base64.split(",", 1)[1]

                raw_bytes = base64.b64decode(data_base64)

                target_dir = EXPORT_DIR
                if subfolder:
                    # サブフォルダ名サニタイズ
                    safe_subfolder = "".join(c for c in subfolder if c not in ("/", "\\", ":", "*", "?", "\"", "<", ">", "|")).strip()
                    if safe_subfolder:
                        target_dir = os.path.join(EXPORT_DIR, safe_subfolder)

                os.makedirs(target_dir, exist_ok=True)
                target_path = os.path.join(target_dir, filename)

                with open(target_path, "wb") as f:
                    f.write(raw_bytes)

                self._send_json({
                    "success": True,
                    "saved_path": target_path,
                    "filename": filename,
                    "size": len(raw_bytes)
                })
            except Exception as e:
                self._send_error(f"Failed to save export file: {str(e)}", status=500)
            return

        self._send_error("Not found", status=404)


def run_psd_server(port: int = 8088):
    server_address = ("", port)
    httpd = HTTPServer(server_address, PSDStudioRequestHandler)
    print(f"🌸 東方キャラ立絵スタジオ サーバー起動: http://localhost:{port}")
    httpd.serve_forever()


if __name__ == "__main__":
    port = 8088
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    run_psd_server(port)
