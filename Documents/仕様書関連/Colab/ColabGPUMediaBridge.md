# Google Colab GPU メディア生成ブリッジ構築ガイド（動画・画像・BGM・SE 完全対応）

本書は、手元の Mac（MacBook Neo / メモリ8GB）やローカル Linux 仮想マシン（4GB RAM）ではスペック的に困難な**「高画質イラスト生成」「アニメ動画（MP4）生成」「BGM音楽生成」「効果音（SE）生成」**を、**Google Colab の無料 NVIDIA GPU（T4 / VRAM 16GB）に一時的に肩代わりさせ、完成したファイルをローカル環境へ直接ダウンロードする連携手順書** です。

---

## 1. 連携アーキテクチャの概要

常時起動の高額なクラウドサーバーを契約することなく、**「素材をまとめて生成したい時だけ Colab を立ち上げる」** という完全無料のハイブリッド運用です。

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │ 🌐 Google Colab（無料 NVIDIA T4 GPU / VRAM 16GB）                        │
 │  ・画像生成（SD-Turbo）   : 1〜2秒で1枚レンダリング                     │
 │  ・アニメ動画（AnimateDiff）: 16フレームの MP4 ループアニメーション動画 │
 │  ・BGM音楽（MusicGen）    : 東方風の戦闘・日常曲を作曲                  │
 │  ・効果音（SE）          : スペルカード発動音、打撃音、爆発音などを生成 │
 │  ・Cloudflare Tunnel     : 世界中から届く一時HTTPS URLを発行            │
 └──────────────────────────────────┬──────────────────────────────────────┘
                                    │
                         一時URL（https://xxxx.trycloudflare.com）
                                    │
 ┌──────────────────────────────────┴──────────────────────────────────────┐
 │ 💻 あなたの Mac（MacBook Neo）/ VirtualBuddy Linux VM                   │
 │  ・普段のテキストLLM対話 : ローカル VM（Gemma 2 / 完全無料・常時稼働）  │
 │  ・メディア生成リクエスト : Colab の一時URLにプロンプトを送信           │
 │  ・受取 : 数秒で完成した PNG、MP4、WAV が手元のストレージに即時保存！  │
 └─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Google Colab 側での起動手順（3ステップ）

### Step 1: Google Colab を開く
1. ブラウザで [Google Colab](https://colab.research.google.com/) を開きます。
2. 作成したノートブック [TohoStudio_GPU_Server.ipynb](file:///Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/仕様書関連/Colab/TohoStudio_GPU_Server.ipynb) をアップロードして開きます。

### Step 2: GPU を有効化する
1. Colab のメニューバーから **「ランタイム」** ＞ **「ランタイムのタイプを変更」** をクリックします。
2. ハードウェア アクセラレータで **「T4 GPU」** を選択し、**「保存」** をクリックします。

### Step 3: すべて実行する
1. メニューバーの **「ランタイム」** ＞ **「すべてのセルを実行」**（ショートカット: `Command + F9`）を押します。
2. 最後のセルに以下のように **一時アクセス URL** が表示されます：

```text
===================================================================
🎉 Colab GPU 4大メディア生成サーバーが正常に起動しました！
👉 接続先 URL: https://random-words-1234.trycloudflare.com
===================================================================
```

この `https://xxxx.trycloudflare.com` という URL をコピーします。

---

## 3. 手元の Mac / Linux VM からの生成・受取テスト

Mac の「ターミナル.app」または VirtualBuddy 内のターミナルから、以下のコマンドを実行してテストします。

### 1. 接続確認（ヘルスチェック）
```bash
curl https://xxxx.trycloudflare.com/health
```
返却例:
```json
{
  "status": "READY",
  "gpu": "Tesla T4",
  "vram_free_gb": 9.8,
  "capabilities": ["image", "video", "bgm", "se"]
}
```

---

### 2. 東方風イラストの画像生成（約1〜2秒で完了！）
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/image \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "1girl, Hakurei Reimu, touhou project, red ribbon, miko dress, masterpiece, best quality"
  }' \
  --output reimu_colab.png
```
カレントディレクトリに **`reimu_colab.png`**（512x512 PNG）が保存されます。

---

### 3. アニメーション動画（MP4）の生成（約30〜45秒で完了！）
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/video \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "1girl, Hakurei Reimu floating in cherry blossoms, red ribbon fluttering in wind, masterpiece, best quality"
  }' \
  --output reimu_animation.mp4
```
カレントディレクトリに **`reimu_animation.mp4`**（8fps、16フレームの MP4 動画）が保存されます。

---

### 4. 東方風 BGM の音楽生成（約10〜15秒で完了！）
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/bgm \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "japanese traditional flute touhou style energetic battle bgm 140bpm",
    "duration_seconds": 8
  }' \
  --output touhou_battle_bgm.wav
```
カレントディレクトリに **`touhou_battle_bgm.wav`**（8秒間の BGM 音声ファイル）が保存されます。

---

### 5. スペルカード発動・効果音（SE）の生成（約3〜5秒で完了！）
```bash
curl -X POST https://xxxx.trycloudflare.com/v1/generate/se \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "magic spell card laser beam burst whoosh sound effect",
    "duration_seconds": 2
  }' \
  --output spell_card_se.wav
```
カレントディレクトリに **`spell_card_se.wav`**（2秒間の高品位 SE ファイル）が保存されます。

---

## 4. コストと運用のポイント

1. **利用料金**:
   - **完全無料** です。Google アカウントの Colab 無料枠で動作します。
2. **利用が終わったら**:
   - ブラウザの Colab タブを閉じるか、メニューの **「ランタイム」＞「セッションを切断して削除」** を押せば終了します。
   - 次に素材を作りたくなった時に、また「すべてのセルを実行」を押せば数分で新しい URL が発行されます。
3. **MacBook Neo の保護**:
   - 動画や画像の巨大なレンダリング計算（発熱・電力消費）を手元の Mac で一切行わないため、ファンレスの MacBook Neo を痛めることなく、世界トップクラスの GPU 性能を手元で享受できます。
