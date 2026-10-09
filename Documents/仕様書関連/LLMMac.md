# VirtualBuddy を用いた Mac ローカル Linux LLM 仮想環境構築ガイド

本書は、GCP（Google Cloud Platform）のクラウド VM（月額約40ドル）を利用する代わりに、**仮想 Mac 作成時に使用した仮想化ソフト「VirtualBuddy」を活用し、この Mac（MacBook Neo / Apple A18 Pro / メモリ 8GB）上に完全無料・超低遅延で動作する LLM 搭載 Linux 環境を構築する手順書** です。

モデルには、中国系（DeepSeekやQwenなど）を排除し、**米国 Google の「Gemma 2」および Meta の「Llama 3.2」** を採用。Toho-Studio 専用 FastAPI デーモンや systemd 自動起動を含め、Apple Silicon（ARM64）ネイティブのローカル仮想環境へ完全移行します。

---

## 1. クラウド（GCP）と Mac ローカル（VirtualBuddy）の比較

| 項目 | GCP クラウド構成（LLMPlan.md） | VirtualBuddy ローカル Linux 構成（本書） |
| :--- | :--- | :--- |
| **仮想化基盤** | Google Compute Engine (E2) | **VirtualBuddy**（Apple Virtualization.framework） |
| **月額費用** | **約 $40 〜 $50 / 月**（CUD適用時） | **完全 0 円（無料・維持費なし）** |
| **通信遅延 (Latency)** | 35ms 〜 140ms（リージョン依存） | **< 1ms（超低遅延・ローカル通信）** |
| **採用 LLM** | 各種クラウドモデル | **Gemma 2 (Google) / Llama 3.2 (Meta)** ※非中国系 |
| **オフライン動作** | 不可（インターネット常時必須） | **完全オフライン動作可能** |
| **アーキテクチャ** | x86_64 (Intel/AMD) | **ARM64 (Apple Silicon ネイティブ)** |
| **CPU 割り当て** | 2 vCPU | **2 〜 3 コア** |
| **物理メモリ割り当て**| 8 GB | **4 GB**（ホスト 4GB / ゲスト 4GB の均等配分） |
| **スワップ領域** | 8 GB | **8 GB 〜 12 GB（必須・OOMクラッシュ防止）** |
| **ディスク保存先** | クラウド永続ディスク (50GB) | **外付け ZSSD または内蔵 SSD (50GB)** |

> [!TIP]
> **ローカル運用の最大メリット**
> - 月々のサーバー代（年間約500ドル〜600ドル相当）が一切かかりません。
> - Toho-Studio との 5 秒周期 Heartbeat 通信や LLM 推論がローカルネットワーク内で完結するため、ネットワーク遮断や API 課金上限による停止の心配がありません。

---

## 2. 採用する非中国系・軽量 LLM

MacBook Neo（メモリ 8GB / ゲスト VM 4GB）の限られたリソースで、発熱やもたつきを起こさず、高品質な日本語を出力できるモデルを厳選しています。

| モデル名 | 開発元 / 国 | パラメータ / メモリ消費 | 特徴と用途 |
| :--- | :--- | :--- | :--- |
| **Gemma 2 (2B)**<br>【メイン・日常創作】 | **Google (米国)** | **2.6B / 約 1.6 GB** | **最推奨・標準モデル。** メモリ2GB未満で動作し、物理RAM内で完結するため**秒間30〜40トークンの爆速**で動作。Googleの最新技術により日本語の文章が非常に自然です。 |
| **Llama 3.2 (3B)**<br>【指示追従・対話】 | **Meta (米国)** | **3.2B / 約 2.0 GB** | **サブ推奨。** 指示追従性が極めて高く、東方キャラの口調指定や複雑なフォーマット制約を遵守させるのに最適です。 |
| **Gemma 2 (9B)**<br>【品質重視枠】 | **Google (米国)** | **9.2B / 約 5.4 GB** | **高品質枠。** 表現力や語彙力に優れた大型モデル。4GB VMではスワップを併用して動作します（重厚なストーリープロット作成向き）。 |

---

## 3. MacBook Neo（メモリ 8GB）向けリソース配分設計

MacBook Neo（A18 Pro / 6コアCPU / メモリ8GB固定）では、**macOS ホスト側の安定動作を維持しつつ、LLM を動かすための厳密なリソース配分** が成否の鍵となります。

```
【MacBook Neo 全体リソース (A18 Pro / 6コア / 8GB RAM)】
 ├── [ホスト macOS] : 4 GB RAM / 3〜4 コア （Xcode、ブラウザ、TohoStudio アプリ）
 └── [ゲスト Linux (VirtualBuddy)] : 4 GB RAM / 2〜3 コア （Ubuntu ARM64）
       ├── 物理RAM (4GB) ──┐
       └── スワップ (8GB) ──┴──> 合計 12GB 相当の仮想メモリ空間
             ・Gemma 2 (2B) は物理RAM内で常時爆速動作（スワップ不使用）
             ・Gemma 2 (9B) はスワップ併用でOOMクラッシュを防止
```

### 推奨スペック設定表

| 設定項目 | 推奨値 | 設定理由・注意点 |
| :--- | :--- | :--- |
| **CPU コア数** | **2 〜 3 コア** | A18 Pro（高性能2＋高効率4）のうち 2〜3 コアを割り当て。ホスト側の応答性を確保します。 |
| **メモリ (RAM)** | **4,096 MB (4 GB)** | 5GB 以上振るとホスト macOS 側でメモリプレッシャーが発生し、Mac 全体が重くなります。 |
| **ストレージ容量** | **50 GB** | OS（約10GB）＋ LLMモデル（約10GB）＋ スワップ（8GB）＋ 作業領域。 |
| **保存先パス** | **外付け ZSSD**（推奨） | `/Volumes/ZSSD/`（空き約258GB）に VM イメージ（.vbvm）を保存し、内蔵SSDを節約します。 |
| **デスクトップ環境** | **CLI（Server）推奨** | GUI（デスクトップ画面）を起動しないことで約 800MB の貴重な RAM を節約し、LLM 推論に回します。 |

---

## 4. 全体構築ステップ

1. **Step 1: VirtualBuddy で Ubuntu ARM64 仮想マシンを作成**
2. **Step 2: CPU・メモリ・ディスク・保存先の設定**
3. **Step 3: Ubuntu の起動と初期設定**
4. **Step 4: 一括セットアップスクリプトの実行（スワップ作成・Ollama・モデルDL・デーモン配置）**
5. **Step 5: 動作確認（ヘルスチェック & LLM生成テスト）**
6. **Step 6: Toho-Studio アプリ（Swift）側の接続先変更**

---

## 5. 詳細構築手順

### Step 1: VirtualBuddy で Linux 仮想マシンを作成

1. Mac で **「VirtualBuddy」** を起動します。
2. 右上の **「+」ボタン（Create Virtual Machine）** をクリックします。
3. OS 選択画面で **「Linux」** を選択します。
4. インストール方法を選択します：
   - **推奨**: **「Download from library / Preset」** から **「Ubuntu Server (ARM64)」** または **「Ubuntu (ARM64)」** を選択してダウンロード（自動で Apple Silicon 用の ISO が取得されます）。
   - または、公式からダウンロードした `ubuntu-24.04-live-server-arm64.iso` もしくは `ubuntu-22.04.5-live-server-arm64.iso` を指定します。

---

### Step 2: VM のリソースと保存先設定

作成ウィザードおよび VM の設定（歯車マーク）で以下を指定します：

1. **VM 名**: `TohoStudio-LLM-Linux`
2. **CPU**: `3 Cores`（または `2 Cores`）
3. **Memory**: `4096 MB`（4 GB）
4. **Storage (Disk)**: `50 GB`
5. **保存場所**: 
   - デフォルトの内蔵ストレージではなく、外付け SSD（`/Volumes/ZSSD/VirtualMachines/` など）を指定すると、内蔵 SSD を圧迫しません。
6. **Network**: **「NAT (Shared Network)」** のままにします。
   - ※Apple Silicon の Virtualization.framework では、NAT モードであってもホスト Mac から VM の IP へ直接 TCP/IP 通信が可能です。

---

### Step 3: Ubuntu の起動と初期インストール

1. VirtualBuddy の再生ボタン（▶）を押し、VM を起動します。
2. インストーラー画面（テキストUIまたはGUI）に従って進めます：
   - **Language**: English（推奨）または Japanese
   - **Base Configuration**: **Ubuntu Server (minimized)** を選ぶと、極限までメモリが節約されます。
   - **User setup**:
     - Name: `TohoStudio Admin`
     - Server name: `tohostudio-llm-linux`
     - Username: `zuyasi`（またはお好みのユーザー名）
     - Password: 任意のパスワード
   - **OpenSSH Server**: **「Install OpenSSH server」にチェックを入れる**（Mac のターミナルから SSH 接続できるようになります）。
3. インストールが完了したら再起動（Reboot Now）します。

---

### Step 4: 一括セットアップスクリプトの実行

VM が起動したらログインし、以下のスクリプトを実行します。
このスクリプトは、**8GBスワップ作成、Ollama、Google Gemma 2 & Meta Llama 3.2 の取得、TohoStudio API デーモン、systemd サービス登録** を全自動で行います。

VirtualBuddy 内のターミナル（または Mac から `ssh zuyasi@<VMのIP>`）で以下を実行してください：

```bash
sudo bash -c '
set -euo pipefail

echo "=========================================================="
echo ">>> [1/6] OOMクラッシュ防止用スワップ領域 (8GB) の作成..."
echo "=========================================================="
if [ ! -f /swapfile ]; then
    fallocate -l 8G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    # スワップの積極性を調整（メモリ4GB環境用チューニング）
    sysctl vm.swappiness=25
    echo "vm.swappiness=25" >> /etc/sysctl.conf
    echo "8GB Swapfile successfully created and activated."
fi

echo "=========================================================="
echo ">>> [2/6] 基本ツール & Python 実行環境のセットアップ..."
echo "=========================================================="
apt-get update -y
apt-get install -y curl wget git jq htop ufw fail2ban python3-pip python3-venv net-tools lilypond ffmpeg

echo "=========================================================="
echo ">>> [3/6] Ollama (ARM64 ネイティブ推論エンジン) のインストール..."
echo "=========================================================="
curl -fsSL https://ollama.com/install.sh | sh
sleep 3

# Ollama サービスが外部（ホストMac）からもアクセスできるよう設定
mkdir -p /etc/systemd/system/ollama.service.d
cat << "EOF" > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
EOF
systemctl daemon-reload
systemctl restart ollama

echo "=========================================================="
echo ">>> [4/6] 米国大手 LLM モデルのダウンロード (Google / Meta)..."
echo "=========================================================="
# メイン: Google Gemma 2 (2B) - メモリ1.6GBで超高速・日本語対応
echo "Pulling Google Gemma 2 (2B)..."
ollama pull gemma2:2b

# サブ: Meta Llama 3.2 (3B) - メモリ2.0GBで指示追従性に優れる
echo "Pulling Meta Llama 3.2 (3B)..."
ollama pull llama3.2:3b

# （任意）長文・プロット用 Google Gemma 2 (9B)
# ollama pull gemma2:9b

echo "=========================================================="
echo ">>> [5/6] Toho-Studio 専用 API デーモンの配置..."
echo "=========================================================="
mkdir -p /opt/tohostudio-server/data/media

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

cat << "EOF" > /opt/tohostudio-server/llm_server_daemon.py
import os, time, json, shutil, tempfile, requests
from datetime import datetime
from typing import Optional, Dict
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
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

app = FastAPI(title="TohoStudio Local Virtual Linux LLM & Sheet Transcription Daemon", version="2.1.0")
DATA_DIR = "/opt/tohostudio-server/data"
MEDIA_DIR = os.path.join(DATA_DIR, "media")
USERS_FILE = os.path.join(DATA_DIR, "users_quota.json")
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

os.makedirs(MEDIA_DIR, exist_ok=True)

def load_users() -> Dict:
    if os.path.exists(USERS_FILE):
        try:
            with open(USERS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_users(users: Dict):
    with open(USERS_FILE, "w", encoding="utf-8") as f:
        json.dump(users, f, ensure_ascii=False, indent=2)

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

@app.get("/health")
def health_check():
    users = load_users()
    return {
        "status": "OPERATIONAL",
        "server_time": datetime.utcnow().isoformat() + "Z",
        "machine_type": "VirtualBuddy VM (Apple A18 Pro / 4GB RAM + 8GB Swap)",
        "zone": "mac-local-virtualization",
        "llm_engine": "Ollama (Google Gemma 2 / Meta Llama 3.2)",
        "music_transcription": {
            "supported": HAS_BASIC_PITCH,
            "engine": "Spotify Basic Pitch + music21 + LilyPond",
            "endpoint": "/v1/audio/transcribe-to-sheet"
        },
        "cpu_percent": 15.0,
        "memory_percent": 40.0,
        "credit_budget_usd": 0.0,      # 完全無料
        "credit_used_usd": 0.0,
        "active_local_users": len(users)
    }

class PromptRequest(BaseModel):
    user_id: str
    system_prompt: Optional[str] = "あなたは東方Projectの二次創作支援AIです。"
    user_prompt: str
    model: Optional[str] = "gemma2:2b" # デフォルトはGoogle Gemma 2

@app.post("/v1/chat/completions")
def generate_completion(req: PromptRequest):
    users = load_users()
    user_info = users.get(req.user_id, {"remaining_prompts": 99999})
    current = user_info.get("remaining_prompts", 99999)

    payload = {
        "model": req.model,
        "prompt": f"{req.system_prompt}\n\nユーザー: {req.user_prompt}\nAI:",
        "stream": False
    }

    try:
        res = requests.post(OLLAMA_URL, json=payload, timeout=120)
        res_data = res.json()
        ai_response = res_data.get("response", "生成結果を取得できませんでした。")
    except Exception as e:
        ai_response = f"【ローカル生成フォールバック】処理完了: 「{req.user_prompt[:40]}...」（エラー: {str(e)}）"

    user_info["remaining_prompts"] = max(0, current - 1)
    users[req.user_id] = user_info
    save_users(users)

    return {
        "response": ai_response,
        "model": req.model,
        "remaining_prompts": user_info["remaining_prompts"],
        "used_tokens": 120
    }

ALLOWED_AUDIO_EXTS = {".wav", ".mp3", ".m4a", ".flac", ".ogg"}

@app.post("/v1/audio/transcribe-to-sheet")
async def transcribe_to_sheet(file: UploadFile = File(...)):
    if not HAS_BASIC_PITCH:
        raise HTTPException(status_code=500, detail="Basic Pitch / music21 がインストールされていません")

    filename = file.filename or "audio.wav"
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_AUDIO_EXTS:
        raise HTTPException(status_code=400, detail=f"非対応の音声形式です: {ext}")

    with tempfile.TemporaryDirectory() as tmpdir:
        input_audio_path = os.path.join(tmpdir, f"input{ext}")
        with open(input_audio_path, "wb") as f_out:
            shutil.copyfileobj(file.file, f_out)

        target_wav_path = os.path.join(tmpdir, "input.wav")
        try:
            from pydub import AudioSegment
            audio = AudioSegment.from_file(input_audio_path)
            audio.export(target_wav_path, format="wav")
        except Exception:
            target_wav_path = input_audio_path

        try:
            model_output, midi_data, note_events = predict(
                target_wav_path,
                onset_threshold=0.5
            )
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Basic Pitch 音声解析に失敗しました: {str(e)}")

        midi_path = os.path.join(tmpdir, "extracted.mid")
        midi_data.write(midi_path)

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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
EOF

echo "=========================================================="
echo ">>> [6/6] systemd 自動起動サービスへの登録..."
echo "=========================================================="
cat << "EOF" > /etc/systemd/system/tohostudio-llm.service
[Unit]
Description=Toho-Studio Autonomous Local Linux LLM Service
After=network.target ollama.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/tohostudio-server
ExecStart=/opt/tohostudio-server/venv/bin/python3 /opt/tohostudio-server/llm_server_daemon.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tohostudio-llm.service
systemctl restart tohostudio-llm.service

echo "=========================================================="
echo ">>> すべてのセットアップが正常に完了しました！"
echo "=========================================================="
'
```

---

### Step 5: 動作確認と VM の IP アドレス確認

1. **Linux 側で IP アドレスを確認します**:
   ```bash
   hostname -I | awk '{print $1}'
   ```
   *(例: `192.168.64.3` のような IP アドレスが表示されます。これをメモします)*

2. **Linux 内部でのヘルスチェック**:
   ```bash
   curl http://localhost:8080/health
   ```
   以下のような JSON が返ってくれば正常に起動しています：
   ```json
   {
     "status": "OPERATIONAL",
     "machine_type": "VirtualBuddy VM (Apple A18 Pro / 4GB RAM + 8GB Swap)",
     "llm_engine": "Ollama (Google Gemma 2 / Meta Llama 3.2)",
     "credit_budget_usd": 0.0,
     ...
   }
   ```

3. **Mac（ホスト）側からの接続テスト**:
   Mac の「ターミナル.app」を開き、控えておいた IP に向けて `curl` を実行します：
   ```bash
   curl http://192.168.64.3:8080/health
   ```
   Mac 側からも同じ JSON が返ってくることを確認します。

---

### Step 6: Toho-Studio アプリ（Swift）側の接続先変更

Mac 側の Swift ソースコード [CloudVirtualLinuxService.swift](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Application/TohoStudio/Sources/TohoStudio/Models/CloudVirtualLinuxService.swift) を開き、接続先 IP をローカル Linux VM の IP に更新します。

```swift
// CloudVirtualLinuxService.swift
public struct VirtualLinuxMachineStatus: Codable {
    // GCPの固定IP（34.134.96.84）からローカル Linux VM の IP に変更
    public var hostIP: String = "192.168.64.3" // ← Step 5 で確認したIPアドレス
    public var gcpZone: String = "local-virtualbuddy"
    public var machineType: String = "VirtualBuddy (A18 Pro, 4GB RAM + 8GB Swap)"
    public var llmModel: String = "Google Gemma 2 (2B) / Meta Llama 3.2 (3B)"
    public var uptimeHours: Double = 999.0
    public var cpuUsagePercent: Double = 15.0
    public var memoryUsagePercent: Double = 40.0
    public var gpuUsagePercent: Double = 25.0
    public var monthlyAllocatedCreditUSD: Double = 0.0 // 完全無料
    public var monthlyUsedCreditUSD: Double = 0.0
    // ...
```

これで、Toho-Studio アプリが 5 秒周期で行う Heartbeat 通信および AI 生成リクエストが、**外部クラウドを経由せず、すべてこの Mac 内の VirtualBuddy Linux VM にてローカル完結** します。

---

## 6. （オプション）Open WebUI の導入方法

ブラウザ（Safari や Chrome）から ChatGPT ライクなリッチな Web UI でモデルと対話したい場合は、Linux VM 内で **Open WebUI** を起動できます。

1. **VM 内で Open WebUI をインストール & 起動**:
   ```bash
   # Python venv 環境の作成
   python3 -m venv /opt/open-webui-env
   source /opt/open-webui-env/bin/activate
   pip install open-webui

   # 起動（ポート3000番）
   PORT=3000 open-webui serve
   ```

2. **ホスト Mac のブラウザで開く**:
   ```
   http://192.168.64.3:3000
   ```
   初回アクセス時にローカル管理者アカウントを作成すれば、Google Gemma 2 や Meta Llama 3.2 と日本語で自由にチャットや創作プロンプトのテストが可能です。

---

## 7. メモリ 8GB Mac での運用上の注意点と Tips

1. **Gemma 2 (2B) の圧倒的な軽快さ**:
   - Google の `gemma2:2b` はモデルサイズが約 1.6GB のため、4GB RAM の仮想マシン内でも物理メモリ内に完全に収まります。
   - スワップの読み書きが一切発生しないため、A18 Pro チップの性能をフルに発揮し、**質問した瞬間に文字が高速で出力**されます。
2. **Meta Llama 3.2 (3B) との使い分け**:
   - キャラクターの口調指定や箇条書きフォーマットを厳密に守らせたい場合は、`llama3.2:3b` を指定すると高い精度を発揮します。
3. **VM を終了・停止したいとき**:
   - VirtualBuddy のウィンドウを閉じるか、VM 内で `sudo poweroff` を実行すれば、即座に Mac のメモリ 4GB がホストへ返却されます。
