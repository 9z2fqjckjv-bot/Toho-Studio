#!/bin/bash
# ==============================================================================
# TohoStudio: Local Linux VM Daemon Upgrade Script
# Adds Colab GPU Bridge routing (Text -> Gemma 2, Media -> Colab L4 GPU)
# ==============================================================================

set -euo pipefail

echo ">>> [1/3] Creating media directories..."
mkdir -p /opt/tohostudio-server/data/media

echo ">>> [2/3] Updating llm_server_daemon.py with Colab GPU Bridge..."
cat << "EOF" > /opt/tohostudio-server/llm_server_daemon.py
import os, time, json, re, base64, requests
from datetime import datetime
from typing import Optional, Dict, Any
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="TohoStudio Hybrid Autonomous Daemon (Gemma 2 + Colab L4 GPU)", version="3.0.0")

DATA_DIR = "/opt/tohostudio-server/data"
MEDIA_DIR = os.path.join(DATA_DIR, "media")
CONFIG_FILE = os.path.join(DATA_DIR, "colab_config.json")
USERS_FILE = os.path.join(DATA_DIR, "users_quota.json")
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

os.makedirs(MEDIA_DIR, exist_ok=True)
app.mount("/media", StaticFiles(directory=MEDIA_DIR), name="media")

# --- Colab GPU 設定管理 ---
DEFAULT_COLAB_URL = "https://luis-oakland-commented-absolute.trycloudflare.com"
COLAB_NOTEBOOK_URL = "https://colab.research.google.com/drive/1lnh3dQi3ZRyF1Oq8qvzsSrGiHi72_hQP?usp=sharing"

def load_colab_config() -> Dict[str, Any]:
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"colab_url": DEFAULT_COLAB_URL, "notebook_url": COLAB_NOTEBOOK_URL, "status": "UNKNOWN"}

def save_colab_config(config: Dict[str, Any]):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)

def check_colab_health(url: str) -> Dict[str, Any]:
    if not url:
        return {"status": "OFFLINE", "message": "Colab URL が設定されていません"}
    try:
        clean_url = url.rstrip("/")
        res = requests.get(f"{clean_url}/health", timeout=5)
        if res.status_code == 200:
            data = res.json()
            data["online"] = True
            data["endpoint"] = clean_url
            return data
    except Exception as e:
        return {"status": "OFFLINE", "online": False, "error": str(e), "endpoint": url}
    return {"status": "OFFLINE", "online": False, "endpoint": url}

# --- ヘルスチェック API ---
@app.get("/health")
def health_check():
    cfg = load_colab_config()
    colab_status = check_colab_health(cfg.get("colab_url", ""))
    
    return {
        "status": "OPERATIONAL",
        "server_time": datetime.utcnow().isoformat() + "Z",
        "machine_type": "VirtualBuddy VM (Apple A18 Pro, 4GB RAM + 8GB Swap)",
        "zone": "mac-local-virtualization",
        "local_llm": "Google Gemma 2 (2B) via Ollama",
        "colab_gpu_bridge": {
            "notebook_url": COLAB_NOTEBOOK_URL,
            "endpoint": cfg.get("colab_url", ""),
            "online": colab_status.get("online", False),
            "gpu": colab_status.get("gpu", "None"),
            "vram_free_gb": colab_status.get("vram_free_gb", 0),
            "capabilities": colab_status.get("capabilities", [])
        },
        "credit_budget_usd": 0.0,
        "credit_used_usd": 0.0
    }

# --- Colab エンドポイント設定更新 API ---
class ColabEndpointRequest(BaseModel):
    colab_url: str

@app.post("/v1/colab/endpoint")
def set_colab_endpoint(req: ColabEndpointRequest):
    clean_url = req.colab_url.strip().rstrip("/")
    status = check_colab_health(clean_url)
    cfg = load_colab_config()
    cfg["colab_url"] = clean_url
    cfg["status"] = "ONLINE" if status.get("online") else "OFFLINE"
    save_colab_config(cfg)
    return {"success": True, "colab_url": clean_url, "health": status}

# --- 知的ルーター（プロンプト解析） ---
class PromptRequest(BaseModel):
    user_id: str
    user_prompt: str
    system_prompt: Optional[str] = "あなたは東方Projectの二次創作支援AIです。"
    model: Optional[str] = "gemma2:2b"

@app.post("/v1/chat/completions")
def handle_chat_completion(req: PromptRequest):
    prompt_text = req.user_prompt.strip()
    cfg = load_colab_config()
    colab_url = cfg.get("colab_url", "").rstrip("/")
    
    # 意図判定（Intent Detection: プロンプト翻訳リクエスト時は除外）
    media_type = None
    if req.user_id != "tohostudio-prompt-translator":
        is_video = any(k in prompt_text for k in ["動画", "アニメ", "動かして", "ループ動画", "video", "movie", "animation"])
        is_image = any(k in prompt_text for k in ["画像", "イラスト", "絵", "描いて", "立ち絵", "picture", "image", "draw"])
        is_bgm = any(k in prompt_text for k in ["BGM", "音楽", "曲", "作曲", "テーマ曲", "bgm", "music", "song"])
        is_se = any(k in prompt_text for k in ["効果音", "SE", "音鳴らして", "爆発音", "レーザー音", "発動音", "sound effect", "sfx"])

        if is_video:
            media_type = "video"
        elif is_image:
            media_type = "image"
        elif is_se:
            media_type = "se"
        elif is_bgm:
            media_type = "bgm"
        
    # --- メディア生成リクエストの場合（Colab GPU へ中継） ---
    if media_type is not None:
        colab_health = check_colab_health(colab_url)
        if not colab_health.get("online"):
            return {
                "response": f"【通知】{media_type.upper()}の生成リクエストを受け付けましたが、現在 Google Colab GPU がオフラインです。\n以下の Colab ノートブックを起動して接続してください：\n{COLAB_NOTEBOOK_URL}",
                "media_type": media_type,
                "media_url": None,
                "colab_online": False,
                "remaining_prompts": 99999
            }
            
        timestamp = int(time.time())
        ext_map = {"image": "png", "video": "mp4", "bgm": "wav", "se": "wav"}
        filename = f"{media_type}_{timestamp}.{ext_map[media_type]}"
        save_path = os.path.join(MEDIA_DIR, filename)
        
        target_endpoint = f"{colab_url}/v1/generate/{media_type}"
        payload = {"prompt": prompt_text, "duration_seconds": 6 if media_type == "bgm" else 2}
        
        try:
            res = requests.post(target_endpoint, json=payload, timeout=120)
            if res.status_code == 200:
                with open(save_path, "wb") as f:
                    f.write(res.content)
                    
                media_link = f"http://192.168.64.3:8080/media/{filename}"
                return {
                    "response": f"【Colab L4 GPU 生成完了】『{prompt_text[:40]}...』に基づく {media_type.upper()} を高画質/高音質で正常生成しました！",
                    "media_type": media_type,
                    "media_url": media_link,
                    "local_filename": filename,
                    "colab_online": True,
                    "remaining_prompts": 99999
                }
            else:
                return {
                    "response": f"【Colab GPU エラー】生成処理中にエラーが発生しました（ステータスコード: {res.status_code}）",
                    "media_type": media_type,
                    "media_url": None,
                    "colab_online": True
                }
        except Exception as e:
            return {
                "response": f"【通信エラー】Colab GPU との通信に失敗しました: {str(e)}",
                "media_type": media_type,
                "media_url": None,
                "colab_online": False
            }

    # --- 通常のテキスト会話の場合（ローカル Linux 内の Google Gemma 2 2B で即座に推論） ---
    payload = {
        "model": req.model,
        "prompt": f"{req.system_prompt}\n\nユーザー: {prompt_text}\nAI:",
        "stream": False
    }
    
    try:
        res = requests.post(OLLAMA_URL, json=payload, timeout=60)
        ai_response = res.json().get("response", "生成結果を取得できませんでした。")
    except Exception as e:
        ai_response = f"【ローカル生成フォールバック】「{prompt_text[:30]}...」に対する応答処理（エラー: {str(e)}）"
        
    return {
        "response": ai_response,
        "media_type": "text",
        "media_url": None,
        "colab_online": True,
        "remaining_prompts": 99999
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
EOF

echo ">>> [3/3] Restarting tohostudio-llm.service..."
systemctl restart tohostudio-llm.service
sleep 2

echo ">>> Verifying health check..."
curl -s http://localhost:8080/health | jq . || curl -s http://localhost:8080/health
echo ""
echo "=========================================================="
echo "🎉 TohoStudio ハイブリッドデーモンの更新が完了しました！"
echo "=========================================================="
