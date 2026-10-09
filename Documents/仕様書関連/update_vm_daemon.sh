#!/bin/bash
# ==============================================================================
# TohoStudio: Local Linux VM Daemon Upgrade Script
# Adds Colab GPU Bridge routing + Basic Pitch & LilyPond Automatic Music Transcription
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo ">>> [1/5] Installing system packages (LilyPond & FFmpeg)..."
echo "=========================================================="
sudo apt-get update -y
sudo apt-get install -y lilypond ffmpeg

echo "=========================================================="
echo ">>> [2/5] Creating media directories..."
echo "=========================================================="
mkdir -p /opt/tohostudio-server/data/media

echo "=========================================================="
echo ">>> [3/5] Updating requirements.txt & Installing Python packages..."
echo "=========================================================="
cat << "EOF" > /opt/tohostudio-server/requirements.txt
fastapi>=0.100.0
uvicorn>=0.23.0
pydantic>=2.0.0
requests>=2.31.0
python-multipart>=0.0.9
basic-pitch>=0.2.0
music21>=9.1.0
pydub>=0.25.1
EOF

if [ ! -d /opt/tohostudio-server/venv ]; then
    python3 -m venv /opt/tohostudio-server/venv
fi
/opt/tohostudio-server/venv/bin/pip install -r /opt/tohostudio-server/requirements.txt

echo "=========================================================="
echo ">>> [4/5] Updating llm_server_daemon.py with Music Transcription..."
echo "=========================================================="
cat << "EOF" > /opt/tohostudio-server/llm_server_daemon.py
import os, time, json, re, base64, shutil, tempfile, requests
from datetime import datetime
from typing import Optional, Dict, Any
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import Response, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import uvicorn

# Basic Pitch & music21 setup
try:
    from basic_pitch.inference import predict
    from basic_pitch import ICASSP_2022_MODEL_PATH
    import music21
    for ly_cand in ['/usr/bin/lilypond', '/usr/local/bin/lilypond']:
        if os.path.exists(ly_cand):
            music21.environment.set('lilypondPath', ly_cand)
            break
    HAS_BASIC_PITCH = True
except Exception as e:
    HAS_BASIC_PITCH = False
    BASIC_PITCH_ERROR = str(e)

app = FastAPI(title="TohoStudio Hybrid Autonomous Daemon (Gemma 2 + Colab L4 GPU + Sheet Transcription)", version="3.1.0")

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

# --- MIDI -> PDF 楽譜変換 ---
def convert_midi_to_pdf(midi_path: str, output_pdf_path: str):
    import music21
    score = music21.converter.parse(midi_path)
    score.quantize(quarterLengthDivisors=(4,), processOffsets=True, processDurations=True)
    try:
        key = score.analyze('key')
        score.insert(0, key)
    except Exception:
        pass

    temp_ly_dir = tempfile.mkdtemp()
    temp_target = os.path.join(temp_ly_dir, "score.pdf")
    try:
        written_path = score.write('lily.pdf', fp=temp_target)
        if os.path.exists(written_path):
            shutil.copyfile(written_path, output_pdf_path)
        elif os.path.exists(temp_target):
            shutil.copyfile(temp_target, output_pdf_path)
        else:
            candidates = [f for f in os.listdir(temp_ly_dir) if f.endswith(".pdf")]
            if candidates:
                shutil.copyfile(os.path.join(temp_ly_dir, candidates[0]), output_pdf_path)
            else:
                raise RuntimeError("LilyPond failed to generate PDF output.")
    finally:
        shutil.rmtree(temp_ly_dir, ignore_errors=True)

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
        "music_transcription": {
            "supported": HAS_BASIC_PITCH,
            "engine": "Spotify Basic Pitch + music21 + LilyPond",
            "endpoint": "/v1/audio/transcribe-to-sheet"
        },
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

# --- 音楽メディア自動採譜・PDF楽譜生成エンドポイント ---
ALLOWED_AUDIO_EXTS = {".wav", ".mp3", ".m4a", ".flac", ".ogg"}

@app.post("/v1/audio/transcribe-to-sheet")
async def transcribe_to_sheet(file: UploadFile = File(...)):
    if not HAS_BASIC_PITCH:
        raise HTTPException(
            status_code=500,
            detail=f"Basic Pitch / music21 がサーバーにインストールされていません: {BASIC_PITCH_ERROR if 'BASIC_PITCH_ERROR' in globals() else 'モジュール初期化エラー'}"
        )

    filename = file.filename or "audio.wav"
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_AUDIO_EXTS:
        raise HTTPException(
            status_code=400,
            detail=f"非対応の音声フォーマットです: {ext}。対応形式: {', '.join(sorted(ALLOWED_AUDIO_EXTS))}"
        )

    with tempfile.TemporaryDirectory() as tmpdir:
        input_audio_path = os.path.join(tmpdir, f"input{ext}")
        with open(input_audio_path, "wb") as f_out:
            shutil.copyfileobj(file.file, f_out)

        # 音声フォーマットを WAV 形式へ変換（Basic Pitch 入力用）
        target_wav_path = os.path.join(tmpdir, "input.wav")
        try:
            from pydub import AudioSegment
            audio = AudioSegment.from_file(input_audio_path)
            audio.export(target_wav_path, format="wav")
        except Exception:
            target_wav_path = input_audio_path

        # Basic Pitch 推論 (発音開始時刻 onset_threshold=0.5, ピッチ抽出)
        try:
            model_output, midi_data, note_events = predict(
                target_wav_path,
                onset_threshold=0.5
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Basic Pitch 音声解析に失敗しました: {str(e)}")

        midi_path = os.path.join(tmpdir, "extracted.mid")
        midi_data.write(midi_path)

        # LilyPond 経由で五線譜 PDF にコンパイル
        pdf_path = os.path.join(tmpdir, "transcription.pdf")
        try:
            convert_midi_to_pdf(midi_path, pdf_path)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"LilyPond 楽譜PDF組版に失敗しました: {str(e)}")

        if not os.path.exists(pdf_path) or os.path.getsize(pdf_path) == 0:
            raise HTTPException(status_code=500, detail="生成された楽譜PDFファイルが空または存在しません。")

        base_name = os.path.splitext(os.path.basename(filename))[0]
        out_filename = f"score_{int(time.time())}_{base_name}.pdf"
        cached_pdf_path = os.path.join(MEDIA_DIR, out_filename)
        shutil.copyfile(pdf_path, cached_pdf_path)

        return FileResponse(
            path=cached_pdf_path,
            media_type="application/pdf",
            filename=out_filename
        )

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

echo "=========================================================="
echo ">>> [5/5] Restarting tohostudio-llm.service..."
echo "=========================================================="
if systemctl is-active --quiet tohostudio-llm.service 2>/dev/null; then
    systemctl restart tohostudio-llm.service
    sleep 2
    echo ">>> Verifying health check..."
    curl -s http://localhost:8080/health | jq . || curl -s http://localhost:8080/health
fi

echo ""
echo "=========================================================="
echo "🎉 TohoStudio 自動採譜・PDF楽譜生成対応デーモンの更新が完了しました！"
echo "=========================================================="
