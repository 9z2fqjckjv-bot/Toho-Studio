"""
東方Projectムービーメーカー - YouTube 直接エクスポートモジュール (非公開動画投稿)
- YouTube Data API v3 を使用した動画の直接アップロード
- プライバシー設定: "private" (非公開動画) を強制
- タイトル、概要欄、タグの自動設定
- オフライン環境での安全なフォールバック
"""

import os
import sys
import json
import urllib.request
import urllib.parse
from typing import Dict, Any, Optional, List


class YouTubeUploader:
    @staticmethod
    def upload_private_video(
        video_path: str,
        title: str,
        description: str = "",
        tags: Optional[List[str]] = None,
        auth_token: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        生成された動画を YouTube に非公開（private）としてアップロードする。
        """
        if not os.path.exists(video_path):
            return {"success": False, "error": f"動画ファイルが存在しません: {video_path}"}

        if not tags:
            tags = ["東方Project", "ゆっくり", "東方Projectムービーメーカー", "二次創作"]

        if not auth_token:
            return {
                "success": False,
                "error": "YouTube API 認証トークン (OAuth2 Access Token) が設定されていません。",
                "guide": "YouTube Studio から直接アップロードするか、設定画面でアクセストークンを入力してください。"
            }

        try:
            metadata = {
                "snippet": {
                    "title": title,
                    "description": description or f"東方Projectムービーメーカーにて作成\n{title}",
                    "tags": tags,
                    "categoryId": "24"
                },
                "status": {
                    "privacyStatus": "private",
                    "selfDeclaredMadeForKids": False
                }
            }

            upload_url = "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=multipart&part=snippet,status"
            boundary = "----TohoProjectMovieMakerBoundary"
            
            meta_json = json.dumps(metadata, ensure_ascii=False)
            
            with open(video_path, "rb") as vf:
                video_data = vf.read()

            body = bytearray()
            body.extend(f"--{boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n{meta_json}\r\n".encode("utf-8"))
            body.extend(f"--{boundary}\r\nContent-Type: video/mp4\r\n\r\n".encode("utf-8"))
            body.extend(video_data)
            body.extend(f"\r\n--{boundary}--\r\n".encode("utf-8"))

            req = urllib.request.Request(upload_url, data=body, method="POST")
            req.add_header("Authorization", f"Bearer {auth_token}")
            req.add_header("Content-Type", f"multipart/related; boundary={boundary}")
            req.add_header("Content-Length", str(len(body)))

            with urllib.request.urlopen(req, timeout=300) as response:
                res_data = json.loads(response.read().decode("utf-8"))
                video_id = res_data.get("id")
                return {
                    "success": True,
                    "video_id": video_id,
                    "video_url": f"https://youtu.be/{video_id}",
                    "privacy_status": "private",
                    "message": f"YouTubeへの非公開投稿が完了しました: https://youtu.be/{video_id}"
                }

        except urllib.error.HTTPError as he:
            err_body = he.read().decode("utf-8", errors="ignore")
            return {"success": False, "error": f"YouTube API エラー ({he.code}): {err_body}"}
        except Exception as e:
            return {"success": False, "error": f"YouTube アップロード失敗: {e}"}
