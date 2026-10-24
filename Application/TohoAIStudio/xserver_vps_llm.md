# TohoStudio 最小限LLMバックエンド実装指示書 (Xserver VPS 向け)

本書は、Xserver VPS（Ubuntu 24.04/22.04 LTS x86_64、4GBメモリ / 4コア環境）において、**「AIチャット機能」「テキスト・シナリオ編集機能」「プロンプト残数管理（クォータ）」** の3機能に絞り込んだ最小構成を実装・運用するための完全手順書です。

音声解析（Basic Pitch / LilyPond）、ログ監視、有料ライセンス決済管理は既存環境およびColab側へ分離するため、本環境からは除外してメモリとCPU推論速度を最大限に最適化します。

---

## 1. 構成概要とリソース配分

```
[クライアント端末 (macOS TohoStudio)]
       │
       │ HTTP POST (JSON)
       ▼
[Xserver VPS (Ubuntu 24.04 LTS, 4GB RAM / 4vCPU)]
  ├── Nginx リバースプロキシ (:80 -> :8080)
  ├── TohoStudio Minimal Daemon (FastAPI :8080)
  │     ├── /health (死活監視・稼働状態)
  │     ├── /v1/chat/completions (チャット・シナリオ編集・残数デクリメント)
  │     └── /v1/user/prompts (プロンプト照会・広告視聴後のチャージ)
  ├── users_quota.json (ユーザー残数DB)
  └── Ollama 推論エンジン (:11434)
        └── Qwen 2.5 (3B) [RAM消費: 約1.9GB]
```

* **OS**: Ubuntu 24.04 LTS または 22.04 LTS 64bit
* **RAM消費見込み**:
  * OS基本機能 + FastAPI: 約 400MB
  * Ollama + Qwen 2.5 (3B): 約 1.9GB
  * 合計消費: 約 2.3GB（物理RAM 4GB 内に完全常駐、スワップ不使用で高速動作）
* **スワップ領域**: 4GB（一時的な突発バーストによるOOM強制終了を防止）

---

## 2. サーバーサイド実装手順 (Xserver VPS)

VPSにSSHログインし、以下のステップを順に実行します。

### Step 1: スワップ作成と基本パッケージの導入

```bash
sudo bash -c '
set -euo pipefail

# 1. 4GBスワップ作成
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    sysctl vm.swappiness=20
    echo "vm.swappiness=20" >> /etc/sysctl.conf
fi

# 2. パッケージ導入
apt-get update -y
apt-get install -y curl jq ufw python3-pip python3-venv nginx
'
```

---

### Step 2: Ollama の導入と Qwen 2.5 (3B) の取得

```bash
# Ollama インストール
curl -fsSL https://ollama.com/install.sh | sh

# ローカルホスト固定 (外部へ直接ポート露出させない)
mkdir -p /etc/systemd/system/ollama.service.d
cat << "EOF" > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_ORIGINS=*"
EOF

systemctl daemon-reload
systemctl restart ollama
systemctl enable ollama

# 日本語処理・推論速度に優れた Qwen 2.5 (3B) を取得
ollama pull qwen2.5:3b
```

---

### Step 3: Python バックエンドデーモンの構築

専用ディレクトリ `/opt/tohostudio-llm` を作成し、FastAPIアプリケーションを配備します。

```bash
mkdir -p /opt/tohostudio-llm
cd /opt/tohostudio-llm

# 仮想環境作成
python3 -m venv /opt/tohostudio-llm/venv

# 依存ライブラリ定義
cat << "EOF" > /opt/tohostudio-llm/requirements.txt
fastapi>=0.110.0
uvicorn>=0.28.0
pydantic>=2.6.0
requests>=2.31.0
EOF

/opt/tohostudio-llm/venv/bin/pip install --upgrade pip
/opt/tohostudio-llm/venv/bin/pip install -r /opt/tohostudio-llm/requirements.txt
```

#### アプリケーション本体 (`/opt/tohostudio-llm/main.py`) の作成

```python
import os
import json
import requests
from typing import Optional, Dict
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="TohoStudio Minimal LLM Engine", version="3.0.0")

DATA_FILE = "/opt/tohostudio-llm/users_quota.json"
OLLAMA_URL = "http://127.0.0.1:11434/api/generate"

def load_quotas() -> Dict:
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_quotas(data: Dict):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

@app.get("/health")
def health():
    return {
        "status": "OPERATIONAL",
        "engine": "Ollama (Qwen 2.5 3B)",
        "features": ["chat", "edit", "prompt_quota"]
    }

class CompletionRequest(BaseModel):
    user_id: str
    system_prompt: Optional[str] = "あなたは東方Projectの二次創作支援AIです。"
    user_prompt: str
    model: Optional[str] = "qwen2.5:3b"

@app.post("/v1/chat/completions")
def chat_or_edit(req: CompletionRequest):
    quotas = load_quotas()
    user_info = quotas.get(req.user_id, {"remaining_prompts": 1000})  # 初期枠: 1000
    current_prompts = user_info.get("remaining_prompts", 1000)

    # 1. プロンプト残数チェック
    if current_prompts <= 0:
        raise HTTPException(
            status_code=403,
            detail="利用可能プロンプト残数が0です。広告視聴またはチャージが必要です。"
        )

    # 2. Ollama への推論リクエスト
    payload = {
        "model": req.model,
        "prompt": f"{req.system_prompt}\n\nユーザー: {req.user_prompt}\nAI:",
        "stream": False
    }

    try:
        res = requests.post(OLLAMA_URL, json=payload, timeout=120)
        res_data = res.json()
        ai_response = res_data.get("response", "")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"LLM推論エラー: {str(e)}")

    # 3. プロンプト残数を 1 減算
    user_info["remaining_prompts"] = current_prompts - 1
    quotas[req.user_id] = user_info
    save_quotas(quotas)

    return {
        "response": ai_response,
        "model": req.model,
        "remaining_prompts": user_info["remaining_prompts"]
    }

class QuotaUpdateRequest(BaseModel):
    user_id: str
    add_prompts: int

@app.post("/v1/user/prompts")
def add_user_prompts(req: QuotaUpdateRequest):
    quotas = load_quotas()
    user_info = quotas.get(req.user_id, {"remaining_prompts": 0})
    user_info["remaining_prompts"] = user_info.get("remaining_prompts", 0) + req.add_prompts
    quotas[req.user_id] = user_info
    save_quotas(quotas)

    return {
        "user_id": req.user_id,
        "remaining_prompts": user_info["remaining_prompts"]
    }

@app.get("/v1/user/prompts/{user_id}")
def get_user_prompts(user_id: str):
    quotas = load_quotas()
    user_info = quotas.get(user_id, {"remaining_prompts": 1000})
    return {
        "user_id": user_id,
        "remaining_prompts": user_info.get("remaining_prompts", 1000)
    }

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8080)
```

---

### Step 4: systemd サービス登録

```bash
cat << "EOF" > /etc/systemd/system/tohostudio-llm.service
[Unit]
Description=TohoStudio Minimal LLM Engine
After=network.target ollama.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/tohostudio-llm
ExecStart=/opt/tohostudio-llm/venv/bin/python3 /opt/tohostudio-llm/main.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tohostudio-llm.service
systemctl restart tohostudio-llm.service
```

---

### Step 5: Nginx リバースプロキシとファイアウォール

ポート8080を直接開けず、標準のHTTP(80) / HTTPS(443)を経由してアクセスさせます。

```bash
cat << "EOF" > /etc/nginx/sites-available/tohostudio
server {
    listen 80;
    server_name _;

    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 180s;
    }
}
EOF

ln -sf /etc/nginx/sites-available/tohostudio /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# ファイアウォール許可 (SSH + Web)
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable
```

---

## 3. クライアントサイド実装手順 (TohoStudio / Swift)

TohoStudioアプリ側の通信クライアントコードを本サーバーへ接続するように実装します。

### `CloudVirtualLinuxService.swift` の実装例

```swift
import Foundation

public class CloudVirtualLinuxService: ObservableObject {
    public static let shared = CloudVirtualLinuxService()
    
    // Xserver VPS の IP アドレスまたは設定したドメインを指定
    @Published public var serverBaseURL: String = "http://<XSERVER_VPS_IP>"
    @Published public var currentUserId: String = "local_user_default"
    @Published public var remainingPrompts: Int = 1000
    @Published public var isConnected: Bool = false

    private init() {}

    /// サーバーのヘルスチェック
    public func checkHealth(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(serverBaseURL)/health") else {
            completion(false)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    self.isConnected = true
                    completion(true)
                } else {
                    self.isConnected = false
                    completion(false)
                }
            }
        }.resume()
    }

    /// AIチャットおよびテキスト編集リクエスト
    public func requestCompletion(
        userPrompt: String,
        systemPrompt: String = "あなたは東方Projectの二次創作支援AIです。",
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(serverBaseURL)/v1/chat/completions") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "user_id": currentUserId,
            "system_prompt": systemPrompt,
            "user_prompt": userPrompt,
            "model": "qwen2.5:3b"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpRes = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(URLError(.badServerResponse))) }
                return
            }

            if httpRes.statusCode == 403 {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "TohoStudio", code: 403, userInfo: [
                        NSLocalizedDescriptionKey: "プロンプト残数が不足しています。広告視聴等でチャージしてください。"
                    ])))
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion(.failure(URLError(.cannotParseResponse))) }
                return
            }

            let responseText = json["response"] as? String ?? ""
            let updatedPrompts = json["remaining_prompts"] as? Int ?? self.remainingPrompts

            DispatchQueue.main.async {
                self.remainingPrompts = updatedPrompts
                completion(.success(responseText))
            }
        }.resume()
    }

    /// 広告視聴完了時などのプロンプト加算処理
    public func addPrompts(count: Int, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(serverBaseURL)/v1/user/prompts") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": currentUserId,
            "add_prompts": count
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
                   let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newPrompts = json["remaining_prompts"] as? Int {
                    self.remainingPrompts = newPrompts
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}
```

---

## 4. 疎通・動作確認テスト手順

VPS側のセットアップ完了後、クライアント（Macのターミナルなど）から以下のコマンドで動作を検証します。

### ① ヘルスチェック
```bash
curl http://<XSERVER_VPS_IP>/health
```
**期待されるレスポンス**:
```json
{"status":"OPERATIONAL","engine":"Ollama (Qwen 2.5 3B)","features":["chat","edit","prompt_quota"]}
```

### ② AIチャット・文章編集テスト
```bash
curl -X POST http://<XSERVER_VPS_IP>/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_01",
    "system_prompt": "入力されたセリフを博麗霊夢風の口調に書き直してください。",
    "user_prompt": "おはようございます。今日も一日がんばりましょう。"
  }'
```
**期待されるレスポンス**:
```json
{
  "response": "「おはよう。今日も一日、異変が起きないようしっかりやりなさいよね。」",
  "model": "qwen2.5:3b",
  "remaining_prompts": 999
}
```

### ③ プロンプト残数チャージテスト（広告視聴などの連携時）
```bash
curl -X POST http://<XSERVER_VPS_IP>/v1/user/prompts \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "test_user_01",
    "add_prompts": 50
  }'
```
**期待されるレスポンス**:
```json
{
  "user_id": "test_user_01",
  "remaining_prompts": 1049
}
```

---

## 5. 保守・運用コマンド集

* **サービス状態の確認**:
  ```bash
  systemctl status tohostudio-llm.service
  ```
* **リアルタイムログの閲覧**:
  ```bash
  journalctl -u tohostudio-llm.service -f
  ```
* **ユーザープロンプト管理DBのバックアップ**:
  ```bash
  cp /opt/tohostudio-llm/users_quota.json /opt/tohostudio-llm/users_quota.json.bak
  ```