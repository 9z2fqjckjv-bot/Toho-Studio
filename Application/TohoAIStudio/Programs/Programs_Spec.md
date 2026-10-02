# TohoAIStudio Programs Configuration

新版仕様書（TohoStudio新版仕様書.pages）準拠のTohoAIStudio内蔵プログラム仕様および管理設定です。

## 内蔵プログラム一覧 (Programs)

1. **VirtualLinuxVMProgram (LLM入り仮想LinuxVMとの通信確認)**
   - 仮想LinuxホストIP: 34.134.96.84
   - GCP Zone: us-central1-a
   - マシンタイプ: e2-standard-2 (2 vCPU, 8GB RAM, T4 GPU)
   - 内蔵LLMモデル: DeepSeek-R1-Distill-Qwen (8B) / Gemma-2 (9B)
   - 通信プロトコル: SSHトンネル / HTTP REST (ポート8000)
   - 監視周期: 5秒間隔ハートビート (Ping, CPU, Memory, GPU)
   - 自動運転省電力モード・プロンプト0時切断機能

2. **AIChatProgram (LLMとのAIチャット機能)**
   - 東方Project専用コンテキストプロンプト（東方世界観・キャラクター口調・同人ガイドライン適合）
   - DeepSeek-R1等の思考ログ（<think>タグ）アコーディオン展開表示
   - スライド＆シナリオメーカー、ムービーメーカー、素材スタジオへのワンクリック転送機能

3. **AIEditorProgram (LLMを用いたAI編集機能)**
   - 台本・セリフ推敲＆キャラ口調変換（霊夢、魔理沙、妖夢、咲夜、レミリア、フランドール、チルノなど）
   - シーン構成＆絵コンテ自動生成（プロットから尺・セリフ・BGM付きMovieScene群を生成しムービーメーカータイムラインへ即時反映）
   - 立ち絵パーツ・表情ポーズプロンプト生成（PSDTool・キャラクターメーカー連動）
   - ゲームロジック＆Blocklyスクリプト生成（ゲームメーカー連動）

4. **UsageBillingProgram (使用量の確認と請求確認)**
   - AIプロンプト月間定額枠（10,000回）モニター（閾値アラート: 1,000回、500回、100回、0回）
   - Google Cloud $100クレジット残高およびCompute Engine/Storage内訳
   - 外部API（Gemini, ChatGPT, Claude）月間概算料金
   - 定額式プラン（月額4,980円）/ 都度課金式プラン（1回0.8円）の切り替えおよび請求書書き出し

5. **ExternalAPIManagementProgram (外部APIの起動、運用管理)**
   - Google Gemini API (Gemini 1.5 Pro, Gemini 1.5 Flash)
   - OpenAI ChatGPT API (GPT-4o, o1-preview, GPT-4o-mini)
   - Anthropic Claude API (Claude 3.5 Sonnet, Claude 3.5 Haiku)
   - macOS Keychainおよびセキュア暗号化保存、リアルタイム接続テスト

6. **InAppBillingBrowserProgram (外部APIの請求をアプリケーション内の専用ブラウザで確認)**
   - アプリ内WebKit (WKWebView) 専用ブラウザ
   - Google AI Studio / Google Cloud Billing
   - OpenAI Platform Usage & Billing
   - Anthropic Console Plans & Billing
   - NanndemoyaCloud 請求管理ポータル
