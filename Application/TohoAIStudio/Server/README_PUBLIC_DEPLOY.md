# TohoAIStudio V3.0 一般配布・外部公開ゲートウェイ 運用ガイド

本ディレクトリには、一般配布（外部公開）を見据えて再設計された **TohoAIStudio V3.0 統合LLMゲートウェイサーバ** 一式が格納されています。

---

## 1. 新・定額プラン料金体系（原価割れ防止・バースト制御・繰越対応）

旧料金案の「過剰なプロンプト枠・追加パックの逆ザヤ」を解消し、クラウド推論APIプロキシ（Gemini 2.5 Flash / DeepSeek V3・R1 等）を裏側で稼働させても**全プランで安定黒字を維持できる6段階プラン**に刷新しています。

| プランID | プラン名 | 月額料金 | 月間基本枠 | お試し広告上限 | 月間最大合計 | 5時間上限 | 週間上限 | 未使用枠の繰越 |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `free` | 無料プラン (Starter) | **¥0** | 30回 | +270回 | **300回** | 15回 | 80回 | 180日 (半年) |
| `lite_980` | ライトプラン | **¥980** | 800回 | +200回 | **1,000回** | 60回 | 300回 | 365日 (1年) |
| `standard_1980` | スタンダードプラン | **¥1,980** | 2,000回 | +500回 | **2,500回** | 150回 | 750回 | 365日 (1年) |
| `creator_2980` | クリエイタープラン | **¥2,980** | 3,500回 | +1,000回 | **4,500回** | 250回 | 1,300回 | 365日 (1年) |
| `pro_4980` | プロスタジオプラン | **¥4,980** | 6,500回 | +1,500回 | **8,000回** | 450回 | 2,400回 | 365日 (1年) |
| `ultra_9800` | アルティメットプラン | **¥9,800** | 15,000回 | +3,000回 | **18,000回** | 1,000回 | 5,500回 | 365日 (1年) |

### 追加プロンプトパック（バースト上限免除・1年間有効）
- `pack_10` (+10回): **¥100**（¥10.0/回）
- `pack_100` (+100回): **¥500**（¥5.0/回）
- `pack_500` (+500回): **¥1,800**（¥3.6/回）
- `pack_1000` (+1,000回): **¥3,000**（¥3.0/回）

---

## 2. Nanndemoya独自API の運用方法（課金基盤不要・ライセンスキー方式）

Nanndemoya独自APIは、アプリ内にクレジットカード決済基盤を持たず、**「何でも屋」側で取得したマスターAPIキーを発行ライセンスキーで安全に中継し、利用実績に応じて直接代金を受け取り・支払いする方式**で実装されています。

### ① マスターAPIキーの登録（`MacMini` 側）
`ssh macmini` で接続し、`/opt/tohostudio-llm-gateway/.env` に「何でも屋」管理のAPIキーを追記して再起動します：
```bash
ssh macmini 'sudo nano /opt/tohostudio-llm-gateway/.env && sudo systemctl restart tohostudio-llm-gateway'
```

### ② 利用者向けライセンスキーの発行
```bash
ssh macmini '/opt/tohostudio-llm-gateway/venv/bin/python3 /opt/tohostudio-llm-gateway/admin_cli.py issue-key --user "user_001" --label "山田様 NanndemoyaAPIライセンス" --provider auto'
```
発行された `NDM-XXXXXX-XXXXXXXX` キーを利用者にお渡しします。利用者は TohoAIStudio の **「外部API・Nanndemoya認証」** タブに入力するだけで、定額枠を消費せずに利用開始できます。

### ③ 利用実績（精算明細）の確認
```bash
ssh macmini '/opt/tohostudio-llm-gateway/venv/bin/python3 /opt/tohostudio-llm-gateway/admin_cli.py usage-report'
```
ライセンスキーごとの **累計リクエスト回数・入力/出力トークン数・最終利用日時** が一覧出力されます。

### ④ 定額プランの手動割当・利用制限解除
```bash
ssh macmini '/opt/tohostudio-llm-gateway/venv/bin/python3 /opt/tohostudio-llm-gateway/admin_cli.py set-plan --user "user_001" --plan standard_1980'
```

---

## 3. 一般配布時の外部HTTPS公開手順（Cloudflare Tunnel・月額0円）

自宅の `MacMini (debian.local:8095)` をルーターのポート開放や固定IP契約なしで安全に全国公開する手順です。

1. `MacMini` に `cloudflared` を導入してログイン：
   ```bash
   ssh macmini
   curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
   sudo dpkg -i /tmp/cloudflared.deb
   cloudflared tunnel login
   ```
2. トンネルを作成し、`nanndemoya.net` のサブドメイン（例: `ai.nanndemoya.net`）を `http://127.0.0.1:8095` にルーティング：
   ```bash
   cloudflared tunnel create tohostudio-gateway
   cloudflared tunnel route dns tohostudio-gateway ai.nanndemoya.net
   ```
3. `/etc/cloudflared/config.yml` を作成してサービス常駐化：
   ```yaml
   tunnel: tohostudio-gateway
   credentials-file: /home/Gemini/.cloudflared/<TUNNEL_UUID>.json
   ingress:
     - hostname: ai.nanndemoya.net
       service: http://127.0.0.1:8095
     - service: http_status:404
   ```
   ```bash
   sudo cloudflared service install
   sudo systemctl enable --now cloudflared
   ```
4. 一般配布時は TohoAIStudio 内の **「ゲートウェイ通信確認」** タブ（または `CloudVirtualLinuxService.swift` の初期URL）を `https://ai.nanndemoya.net` に設定するだけで、全国のユーザー端末からHTTPS暗号化通信で即座に利用可能になります。
