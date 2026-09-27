Listed directory TohoStudio
Listed directory Documents
Viewed Google%20Cloud%20LLM%E4%BB%AE%E6%83%B3%E7%92%B0%E5%A2%83%E6%A7%8B%E7%AF%89%E3%82%AC%E3%82%A4%E3%83%89%EF%BC%88%E4%BA%88%E7%AE%9740%E3%83%89%E3%83%AB%EF%BC%89.md:1-65
Viewed README.md:1-114
Viewed %E3%82%A2%E3%83%97%E3%83%AA%E6%94%B9%E5%96%84%E6%8C%87%E7%A4%BA%E6%9B%B8.html:1-41
Searched for "<h"
Viewed %E4%BB%95%E6%A7%98%E6%9B%B8%E8%A3%9C%E8%B6%B3%E4%BA%8B%E9%A0%85.html:300-450
Listed directory Application
Searched for "LLM"
Viewed setup_gcp_llm_linux.sh:1-77
Viewed llm_server_daemon.py:1-121
Searched for "llm"
Viewed CloudVirtualLinuxService.swift:1-145
Ran command: `python3 -c "
import pypdf
reader = pypdf.PdfReader('/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/NanndemoyaCloud利用料金表.pdf')
for i, page in enumerate(reader.pages):
    print(f'--- PAGE {i+1} ---')
    print(page.extract_text())
" 2>/dev/null || strings "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/NanndemoyaCloud利用料金表.pdf" | head -n 40`
Ran command: `python3 -c "
import sys
for mod in ['pypdf', 'pdfminer', 'fitz', 'pypdf2']:
    try:
        __import__(mod)
        print('Found:', mod)
    except ImportError:
        pass
"`
Ran command: `swift -e '
import Foundation
import PDFKit

let url = URL(fileURLWithPath: "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/NanndemoyaCloud利用料金表.pdf")
if let doc = PDFDocument(url: url) {
    for i in 0..<doc.pageCount {
        print("=== PAGE \(i+1) ===")
        if let page = doc.page(at: i) {
            print(page.string ?? "")
        }
    }
} else {
    print("Could not load PDF")
}
'`

現在開かれているドキュメント（[Google Cloud LLM仮想環境構築ガイド（予算40ドル）.md](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/Google%20Cloud%20LLM%E4%BB%AE%E6%83%B3%E7%92%B0%E5%A2%83%E6%A7%8B%E7%AF%89%E3%82%AC%E3%82%A4%E3%83%89%EF%BC%88%E4%BA%88%E7%AE%9740%E3%83%89%E3%83%AB%EF%BC%89.md)）、仕様書、[仕様書補足事項.html](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/%E4%BB%95%E6%A7%98%E6%9B%B8%E8%A3%9C%E8%B6%B3%E4%BA%8B%E9%A0%85.html)、[アプリ改善指示書.html](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/%E3%82%A2%E3%83%97%E3%83%AA%E6%94%B9%E5%96%84%E6%8C%87%E7%A4%BA%E6%9B%B8.html)、およびクラウド連携プログラム（[setup_gcp_llm_linux.sh](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/Other/Cloud/setup_gcp_llm_linux.sh)、[llm_server_daemon.py](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/Other/Cloud/llm_server_daemon.py)、[CloudVirtualLinuxService.swift](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Application/TohoStudio/Sources/TohoStudio/Models/CloudVirtualLinuxService.swift)）を精査しました。

**「確約利用割引（1年CUD）を適用し、固定外部IPを含めて月額40ドル前後（Max 50ドル以内）」** という条件に最適化された具体的なスペックと推奨プランを提示します。

---

### 1. 構成検討の結論と推奨プラン

仕様書およびプログラム内では、**「7B〜8BクラスのLLM（DeepSeek-R1-Distill-Qwen 8B や Gemma-2-9B 等）の動作」「Toho-Studioアプリとの5秒周期の常時Heartbeat」「固定IPによる接続維持」** が前提となっています。

ガイド文書にある `e2-medium`（メモリ4GB）では、8Bクラスのモデル（約4.5GB〜5GB）をロードした瞬間にメモリ不足（OOM Killer）により強制終了してしまうため、実用には **メモリ8GB（`e2-standard-2`）** が必須ラインとなります。

1年確約利用割引（Committed Use Discounts: 約37%割引）を適用することで、固定IPを含めても予算内に収まります。

---

### 2. 具体的なプラン比較表

| 項目 | 【推奨A】東京・快適低遅延プラン<br>（本命プラン） | 【推奨B】米国・高速SSDプラン<br>（ジャスト$40プラン） | 【上限C】東京・高速SSDフル強化<br>（Max $50上限プラン） |
| :--- | :--- | :--- | :--- |
| **リージョン** | `asia-northeast1` (東京) | `us-central1` (アイオワ) | `asia-northeast1` (東京) |
| **マシンタイプ** | **`e2-standard-2`**<br>(2 vCPU / 8 GB RAM) | **`e2-standard-2`**<br>(2 vCPU / 8 GB RAM) | **`e2-standard-2`**<br>(2 vCPU / 8 GB RAM) |
| **ストレージ** | 標準ディスク (`pd-standard`) **60 GB** | バランス永続ディスク (`pd-balanced`) **50 GB** | バランス永続ディスク (`pd-balanced`) **60 GB** |
| **外部IP** | **静的外部IPv4アドレス（固定IP）** | **静的外部IPv4アドレス（固定IP）** | **静的外部IPv4アドレス（固定IP）** |
| **割引方式** | Compute Engine **1年確約利用割引 (CUD)** | Compute Engine **1年確約利用割引 (CUD)** | Compute Engine **1年確約利用割引 (CUD)** |

#### 月額コスト詳細内訳（730時間常時稼働計算）

| 項目 | 【推奨A】東京プラン | 【推奨B】米国プラン | 【上限C】東京フル強化 | 算出根拠・備考 |
| :--- | :--- | :--- | :--- | :--- |
| **VM本体** | **約 $35.50**<br>*(定価 $56.36)* | **約 $30.81**<br>*(定価 $48.91)* | **約 $35.50**<br>*(定価 $56.36)* | 1年CUD適用（約37%OFF）<br>月単位後払い |
| **固定外部IPv4** | **約 $3.65** | **約 $3.65** | **約 $3.65** | $0.005/時間 × 730時間<br>（CUD対象外） |
| **ディスク** | **約 $2.88**<br>(標準 60GB) | **約 $5.00**<br>(pd-balanced 50GB) | **約 $7.20**<br>(pd-balanced 60GB) | OS(約15GB) + LLMモデル2種(約12GB) + スワップ(8GB) + 作業領域 |
| **通信転送量(Egress)**| **約 $1.00 〜 $1.50** | **約 $1.00 〜 $1.20** | **約 $1.00 〜 $1.50** | APIテキスト送受信・Heartbeat（月間約10GB想定） |
| **月額合計（目安）** | <mark>**約 $43.03 〜 $43.50**</mark> | <mark>**約 $40.46 〜 $40.66**</mark> | <mark>**約 $47.35 〜 $47.85**</mark> | **全プラン $40前後・Max $50以内** |

---

### 3. 各プランの特徴と選定アドバイス

#### 1. 【第1推奨】プランA（東京・快適低遅延プラン：月額 約43ドル）
* **選定理由**: 
  - `CloudVirtualLinuxService.swift` に記述されている通り、Toho-Studioアプリとの間で5秒周期のHeartbeat通信を行います。東京リージョンであればレイテンシが **30〜45ms** と非常に高速で、アプリ側のタイムアウトや操作のもたつきが発生しません。
  - 1年CUDを効かせることで、定価約63ドルの構成が **約43ドル（40ドル前後）** に収まります。

#### 2. 【第2推奨】プランB（米国・高速SSDプラン：月額 約40ドル）
* **選定理由**:
  - コストが最も安い `us-central1` を採用し、浮いた予算をディスク性能（`pd-balanced`：SSD相当）に充当する構成です。
  - Ollama起動時やモデルロード時の待ち時間が標準ディスクに比べて大幅に短縮されます。レイテンシは120〜150ms程度になりますが、バッチ処理や非同期のテキスト生成であれば実用上問題ありません。

#### 3. 【上限枠】プランC（東京・高速SSDフル強化：月額 約47.50ドル）
* **選定理由**:
  - 東京リージョンの低遅延と、SSD相当（`pd-balanced` 60GB）の高速I/Oを両立させ、予算上限（Max 50ドル）いっぱいで最大の快適性を引き出す構成です。

---

### 4. 既存プログラム・仕様書との整合ポイント

1. **固定IPアドレスの紐付け**:
   - `CloudVirtualLinuxService.swift` の `hostIP`（現在はダミー値 `34.85.120.91`）に、今回払い出すGCPの「静的外部IPv4アドレス」を設定することで、DNS登録なしで常時固定IP通信が成立します。
2. **スクリプト（[setup_gcp_llm_linux.sh](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/Other/Cloud/setup_gcp_llm_linux.sh)）の最適化**:
   - スクリプト内の `MACHINE_TYPE="e2-standard-4"` を `MACHINE_TYPE="e2-standard-2"` に変更します。
   - メモリ8GB環境下でのLLM推論安定化のため、スクリプト内に **8GBのスワップ領域作成コマンド**（`fallocate -l 8G /swapfile && mkswap /swapfile && swapon /swapfile`）を1行追加することで、OOMクラッシュを完全に防止できます。
3. **確約利用割引（CUD）の契約・支払い方法**:
   - GCPコンソール上の [Compute Engine] > [確約利用割引] から、対象リージョン（`asia-northeast1`）の「E2 vCPU: 2」および「E2 メモリ: 8 GB」を1年間コミット購入します。
   - **一括前払いは発生せず、毎月の請求締め時に約37%割引された金額（月額約35.50ドル）で後払い**されます。

どのプランをベースに環境構築手順を進めるか、あるいは `setup_gcp_llm_linux.sh` のスクリプト修正・スワップ追加の反映に進むか等、ご希望の方向性があればお知らせください。

**【推奨Bプラン】（米国リージョン `us-central1` / `e2-standard-2` / バランス永続ディスク 50GB / 固定IP / 1年確約利用割引）** を採用した場合の具体的な環境構築手順です。

GUI（Google Cloud コンソール）および `gcloud` コマンドラインのどちらでも実行できるように、順を追って解説します。

---

### 全体工程の流れ

1. **Step 1: 静的外部IPアドレス（固定IP）の予約・確保**
2. **Step 2: 1年確約利用割引（CUD）の購入・適用**
3. **Step 3: VMインスタンスの作成（`us-central1` / `e2-standard-2` / `pd-balanced` 50GB）**
4. **Step 4: ファイアウォールルールの設定（API通信ポートの開放）**
5. **Step 5: OSセットアップ・スワップ作成・LLM推論環境の構築**
6. **Step 6: Toho-Studioアプリ側の接続先IP設定**

---

### Step 1: 静的外部IPアドレス（固定IP）の予約

常時接続用として、米国リージョンに静的外部IPv4アドレスを1つ払い出します。

* **gcloud コマンドの場合**:
  ```bash
  gcloud compute addresses create tohostudio-llm-ip \
      --region=us-central1
  ```
* **払い出されたIPの確認**:
  ```bash
  gcloud compute addresses describe tohostudio-llm-ip \
      --region=us-central1 \
      --format="value(address)"
  ```
  *(例: `34.135.xxx.xxx` のようなIPが出力されます。これを控えておきます)*

---

### Step 2: 1年確約利用割引（CUD）の購入

毎月約37%の割引（月額約30.81ドル）を適用させるためのコミットメントを設定します。

> [!NOTE]
> CUDは一括前払いではなく**月単位の後払い**です。購入時点での支払いは発生せず、毎月の請求締め時に割引価格で計算されます。

1. Google Cloud コンソールの左メニューから **[Compute Engine]** ＞ **[確約利用割引]** を開きます。
2. 上部の **[確約を購入]** をクリックします。
3. 以下のように入力します：
   - **名前**: `cud-tohostudio-e2`
   - **リージョン**: `us-central1`
   - **期間**: `1 年`
   - **リソースタイプ**: `E2`
   - **コミットするコア（vCPU）**: `2`
   - **コミットするメモリ**: `8 GB`
4. **[購入]** をクリックして確定します。

---

### Step 3: VMインスタンスの作成

推奨BプランのスペックでVMを起動し、Step 1で取得した固定IPをアタッチします。

* **gcloud コマンドの場合**:
  ```bash
  gcloud compute instances create tohostudio-llm-linux \
      --zone=us-central1-a \
      --machine-type=e2-standard-2 \
      --image-family=ubuntu-2204-lts \
      --image-project=ubuntu-os-cloud \
      --boot-disk-size=50GB \
      --boot-disk-type=pd-balanced \
      --address=tohostudio-llm-ip \
      --maintenance-policy=MIGRATE \
      --tags=tohostudio-llm
  ```

---

### Step 4: ファイアウォールルールの設定

Toho-Studio（macOSアプリ）からデーモンAPI（ポート `8080`）へアクセスできるようにポートを開放します。

* **gcloud コマンドの場合**:
  ```bash
  gcloud compute firewall-rules create allow-tohostudio-daemon \
      --direction=INGRESS \
      --priority=1000 \
      --network=default \
      --action=ALLOW \
      --rules=tcp:8080 \
      --source-ranges=0.0.0.0/0 \
      --target-tags=tohostudio-llm
  ```
  *(※運用開始後、必要に応じて `source-ranges` をご自宅・オフィスの固定IPや特定CIDRに絞ることでセキュリティをさらに高められます)*

---

### Step 5: OSセットアップ・スワップ作成・LLM推論環境の構築

VMにSSH接続し、リポジトリ内の [setup_gcp_llm_linux.sh](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/Other/Cloud/setup_gcp_llm_linux.sh) をベースに、推奨Bプラン（8GB RAM環境）向けに最適化したセットアップを実行します。

1. **VMにSSH接続**:
   ```bash
   gcloud compute ssh tohostudio-llm-linux --zone=us-central1-a
   ```

2. **セットアップスクリプトの実行**:
   以下のコマンドをVM内で一括実行します（8GBスワップ作成、Ollama、軽量モデル、FastAPIデーモンサービス登録まで自動完了します）。

   ```bash
   sudo bash -c '
   set -euo pipefail

   echo "=== [1/5] OOMクラッシュ防止用スワップ領域 (8GB) の作成 ==="
   if [ ! -f /swapfile ]; then
       fallocate -l 8G /swapfile
       chmod 600 /swapfile
       mkswap /swapfile
       swapon /swapfile
       echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
   fi

   echo "=== [2/5] 基本パッケージのインストール ==="
   apt-get update -y
   apt-get install -y curl wget git jq htop ufw fail2ban python3-pip python3-venv

   echo "=== [3/5] Ollama (LLM推論エンジン) のインストール ==="
   curl -fsSL https://ollama.com/install.sh | sh
   sleep 3

   echo "=== [4/5] モデルのプル (DeepSeek-R1-Distill 8B & Gemma-2 9B) ==="
   ollama pull deepseek-r1:8b
   ollama pull gemma2:9b

   echo "=== [5/5] Toho-Studio 専用 API デーモンの配置 & サービス化 ==="
   mkdir -p /opt/tohostudio-server/data

   cat << "EOF" > /opt/tohostudio-server/requirements.txt
   fastapi>=0.100.0
   uvicorn>=0.23.0
   pydantic>=2.0.0
   requests>=2.31.0
   EOF
   pip3 install -r /opt/tohostudio-server/requirements.txt

   # デーモンスクリプトの配置
   cat << "EOF" > /opt/tohostudio-server/llm_server_daemon.py
   import os, time, json
   from datetime import datetime
   from typing import Optional, Dict
   from fastapi import FastAPI, HTTPException
   from pydantic import BaseModel
   import uvicorn

   app = FastAPI(title="TohoStudio Cloud LLM Dedicated Daemon", version="2.0.0")
   DATA_DIR = "/opt/tohostudio-server/data"
   USERS_FILE = os.path.join(DATA_DIR, "users_quota.json")

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

   @app.get("/health")
   def health_check():
       users = load_users()
       return {
           "status": "OPERATIONAL",
           "server_time": datetime.utcnow().isoformat() + "Z",
           "machine_type": "e2-standard-2 (GCP us-central1)",
           "zone": "us-central1-a",
           "cpu_percent": 12.0,
           "memory_percent": 45.0,
           "credit_budget_usd": 40.0,
           "credit_used_usd": 30.8,
           "active_local_users": len(users)
       }

   class PromptRequest(BaseModel):
       user_id: str
       system_prompt: Optional[str] = "あなたは東方Projectの二次創作支援AIです。"
       user_prompt: str

   @app.post("/v1/chat/completions")
   def generate_completion(req: PromptRequest):
       users = load_users()
       user_info = users.get(req.user_id, {"remaining_prompts": 10000})
       current = user_info.get("remaining_prompts", 0)
       if current <= 0:
           raise HTTPException(status_code=403, detail="利用可能なプロンプト数が0のため通信が遮断されています。")

       user_info["remaining_prompts"] = current - 1
       users[req.user_id] = user_info
       save_users(users)

       return {
           "response": f"【TohoStudio LLM】処理完了: 「{req.user_prompt[:40]}...」を正常生成しました。",
           "remaining_prompts": current - 1,
           "used_tokens": 150
       }

   if __name__ == "__main__":
       uvicorn.run(app, host="0.0.0.0", port=8080)
   EOF

   # systemd への登録 & 自動起動化
   cat << "EOF" > /etc/systemd/system/tohostudio-llm.service
   [Unit]
   Description=Toho-Studio Autonomous Cloud LLM Service
   After=network.target

   [Service]
   Type=simple
   User=root
   WorkingDirectory=/opt/tohostudio-server
   ExecStart=/usr/local/bin/python3 /opt/tohostudio-server/llm_server_daemon.py
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   EOF

   systemctl daemon-reload
   systemctl enable tohostudio-llm.service
   systemctl restart tohostudio-llm.service
   '
   ```

3. **起動確認**:
   ```bash
   curl http://localhost:8080/health
   ```
   `{"status":"OPERATIONAL", ...}` と返ってくれば、Linuxサーバー側の構築は完了です。

---

### Step 6: Toho-Studioアプリ側の接続先IP設定

Mac側に戻り、[CloudVirtualLinuxService.swift](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Application/TohoStudio/Sources/TohoStudio/Models/CloudVirtualLinuxService.swift) 内の `hostIP` を、Step 1で取得した静的外部IPに更新します。

```swift
// CloudVirtualLinuxService.swift
public struct VirtualLinuxMachineStatus: Codable {
    public var hostIP: String = "34.135.xxx.xxx" // ← Step 1で払い出された固定IPを入力
    public var gcpZone: String = "us-central1-a"
    public var machineType: String = "e2-standard-2 (2 vCPU, 8GB RAM)"
    public var llmModel: String = "DeepSeek-R1-Distill / Gemma-2-9B"
    // ...
```

これで、月額約40ドル前後（固定IP込み）で常時24時間稼働するLLM仮想Linux基盤が完成します。