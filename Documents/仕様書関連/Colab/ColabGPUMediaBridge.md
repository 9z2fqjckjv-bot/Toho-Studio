# Google Colab L4 GPU メディア生成ブリッジ構築ガイド（動画・画像・BGM・SE 完全対応）

本書は、手元の Mac やローカル Linux 仮想マシンではスペック的に困難な**「超高精細画像生成（SDXL 1.0）」「動画生成（AnimateDiff）」「高音質BGM生成（MusicGen Medium）」「効果音生成（AudioLDM 2）」**を、**Google Colab の高性能 GPU（NVIDIA L4 / VRAM 24GB）に肩代わりさせ、完成した高品質メディアを手元の TohoStudio に直接取り込む運用マニュアル** です。

東方Projectの制作に限らず、**アニメ・実写写真・SF・ファンタジー・現代日常・映画的SFXなど、あらゆる汎用的なクリエイティブワーク** に対応しています。

---

## 1. 連携アーキテクチャの概要

手元のファンレス Mac に負担をかけることなく、必要な時だけ Google Colab 上で潤沢な 24GB VRAM を誇る L4 GPU サーバーを立ち上げ、高品質なメディア素材を高速取得します。

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │ 🌐 Google Colab（NVIDIA L4 GPU / VRAM 24GB）                             │
 │  ・高精細画像（SDXL 1.0） : 1024px+ ネイティブ解像度 / 30steps / 汎用画質 │
 │  ・動画生成（AnimateDiff）: 滑らかなループ動画 (MP4)                     │
 │  ・BGM音楽（MusicGen Med）: 豊かなステレオ感と多様なジャンル対応         │
 │  ・効果音（AudioLDM 2）   : レーザー、爆発、打撃、足音、環境音などの本物SFX│
 │  ・Cloudflare Tunnel     : 世界中から届く一時HTTPS URLを発行            │
 └──────────────────────────────────┬──────────────────────────────────────┘
                                    │
                         一時URL（https://xxxx.trycloudflare.com）
                                    │
 ┌──────────────────────────────────┴──────────────────────────────────────┐
 │ 💻 あなたの Mac（TohoStudio）/ VirtualBuddy Linux VM                     │
 │  ・プロンプト最適化     : ローカル LLM（Gemma 2 / Llama 3.2）が自動英訳 │
 │  ・メディア生成リクエスト: Colab の一時URLにプロンプト・比率・除外指定を送信 │
 │  ・受取                 : 完成した PNG、MP4、WAV が手元のアプリに即時保存！│
 └─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Google Colab 側での起動手順（3ステップ）

### Step 1: Google Colab を開く
1. ブラウザまたは TohoStudio の「Colabを開く」ボタンから、[Google Colab ノートブック](https://colab.research.google.com/drive/1lnh3dQi3ZRyF1Oq8qvzsSrGiHi72_hQP?usp=sharing) を開きます。

### Step 2: L4 GPU を選択する
1. Colab のメニューバーから **「ランタイム」** ＞ **「ランタイムのタイプを変更」** をクリックします。
2. ハードウェア アクセラレータで **「L4 GPU」**（VRAM 24GB）を選択し、**「保存」** をクリックします。
   *(※無料枠等で T4 を利用する場合でも、メモリ自動クリーン処理により動作します)*

### Step 3: すべて実行する
1. メニューバーの **「ランタイム」** ＞ **「すべてのセルを実行」**（ショートカット: `Command + F9`）を押します。
2. 最後のセルに以下のように **一時アクセス URL** が表示されます：

```text
===================================================================
🎉 Colab L4 GPU 4大メディア高品位生成サーバーが正常に起動しました！
👉 接続先 URL: https://random-words-1234.trycloudflare.com
===================================================================
```

3. TohoStudio アプリ内の「Colab GPU 接続」欄にこの URL を入力（またはアプリ内ブラウザからの自動検出）すれば、準備完了です！

---

## 3. 生成エンドポイントと cURL テスト

### 1. 接続確認（ヘルスチェック）
```bash
curl https://xxxx.trycloudflare.com/health
```
返却例:
```json
{
  "status": "READY",
  "gpu": "NVIDIA L4",
  "vram_free_gb": 22.4,
  "capabilities": ["image (SDXL 1.0)", "se (AudioLDM 2)", "bgm (MusicGen Medium)", "video (AnimateDiff)"]
}
```

---

### 2. 高精細汎用画像生成 (SDXL 1.0)
アスペクト比（16:9 / 1:1 / 9:16）、除外プロンプト（negative_prompt）、シード値に完全対応。
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/image \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "futuristic cyberpunk city with neon reflections in rain, cinematic lighting, masterpiece, 8k",
    "negative_prompt": "people, blurry, low quality, distorted",
    "width": 1344,
    "height": 768
  }' \
  --output sample_image.png
```
カレントディレクトリに **`sample_image.png`**（1344x768 の極上イラスト・写真）が保存されます。

---

### 3. 本格効果音 (SE) 生成 (AudioLDM 2)
効果音・環境音に特化した音響合成モデル。太鼓やビートではなく、意図した通りの効果音（SFX）を直接生成します。
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/se \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "heavy futuristic energy laser cannon charging and firing burst blast",
    "duration_seconds": 2.5
  }' \
  --output laser_blast.wav
```
カレントディレクトリに **`laser_blast.wav`**（2.5秒間の高品位 SFX ファイル）が保存されます。

---

### 4. BGM 音楽生成 (MusicGen Medium)
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/bgm \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "upbeat japanese shamisen and synthwave electronic fusion, dynamic fast tempo",
    "duration_seconds": 10
  }' \
  --output bgm_sample.wav
```
カレントディレクトリに **`bgm_sample.wav`**（10秒間の豊かなBGM音声ファイル）が保存されます。

---

### 5. 動画生成 (AnimateDiff)
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/video \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "sakura cherry blossoms floating gracefully across starry night sky, motion",
    "width": 512,
    "height": 512
  }' \
  --output animation.mp4
```
カレントディレクトリに **`animation.mp4`**（MP4 動画）が保存されます。

---

## 4. 特徴と安定運用のポイント

1. **意図通りの生成クオリティ**:
   - アスペクト比や除外プロンプトが忠実に反映されます。
   - 効果音には音楽モデルではなく効果音特化の `AudioLDM 2` を割り当てているため、単発効果音・環境音が濁らずクリアに出力されます。
2. **GPU メモリの自動解放**:
   - 各生成完了後に `gc.collect()` および `torch.cuda.empty_cache()` を実行するため、画像・音声・動画を切り替えて連続生成しても VRAM OOM にならず安定稼働します。
3. **安全・無料・手元のマシン保護**:
   - 巨大な計算処理はすべて Colab 側で行われるため、MacBook Neo 等のファンレス軽量マシンでも発熱やバッテリー劣化を気にせず世界水準のAI生成を楽しめます。
