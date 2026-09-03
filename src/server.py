"""
東方Projectムービーメーカー - 軽量ローカル HTTP & REST API サーバー
- MacBook Neo に最適化された省メモリ・高速レスポンス設計
- 新規作成・データ読み込み・編集画面の全機能API
- プロジェクト管理、元ファイル直接参照、10分おき自動バックアップ
- Keynote / PowerPoint / YMM / FCPXML インポート & エクスポート
- クラッシュログ・レポート、YouTube 非公開動画直接投稿
"""

import os
import sys
import json
import time
import urllib.parse
import mimetypes
import threading
import traceback
from http.server import HTTPServer, SimpleHTTPRequestHandler
from typing import Dict, Any, Optional

from .core.character_db import CHARACTERS, VOICE_TYPES
from .core.tts_engine import get_tts_engine
from .core.keynote_parser import list_keynote_files, extract_slides_from_keynote, export_keynote_slide_images, export_keynote_media_refresh, slice_slides_from_movie, has_animation_instruction
from .core.powerpoint_parser import extract_slides_from_pptx
from .core.ymm_parser import parse_ymm_project
from .core.project_manager import get_project_manager
from .core.audio_video_merger import AudioVideoMerger
from .core.fcpxml_exporter import FCPXMLExporter
from .core.fcpxml_parser import FCPXMLParser
from .core.youtube_uploader import YouTubeUploader
from .core.crash_reporter import get_crash_reporter
from .core.path_utils import get_series_dir, get_media_dir

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
WEB_DIR = os.path.join(os.path.dirname(__file__), "web")

def run_server(port: int = 8080, on_ready=None):
    httpd = None
    actual_port = port
    for p in range(port, port + 20):
        try:
            server_address = ("127.0.0.1", p)
            httpd = HTTPServer(server_address, AppRequestHandler)
            actual_port = p
            break
        except OSError as oe:
            if oe.errno == 48:
                continue
            raise
    if not httpd:
        raise OSError(f"利用可能なポートが見つかりませんでした (試行範囲: {port}-{port+19})")
    url = f"http://127.0.0.1:{actual_port}"
    print(f"==================================================")
    print(f" 東方Projectムービーメーカー サーバー起動")
    print(f" URL: {url}")
    print(f"==================================================")
    if on_ready:
        on_ready(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nサーバーを停止しました。")
        httpd.server_close()

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run_server(port)
