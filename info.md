これまでのご相談内容を踏まえ、**Keynoteでのスライド作成後から、ゆっくりボイス作成、動画合成、YouTube非公開投稿までを完全自動化するための構築ガイド**を作成しました。

この構築を行えば、手動でのWeb操作やFinal Cut Proでのタイムライン調整が不要になり、コマンドひとつで100枚以上のスライド動画を一括作成・投稿できるようになります。

---

## 全体システム構成図

```
[Keynoteスライド作成]
       │ (1) PNG画像として一括書き出し
       ▼
 [スライド画像群] (slide_001.png ...) + [台本ファイル] (script.csv)
       │
       ├─► (2) Pythonスクリプト実行 (`auto_pipeline.py`)
       │      │
       │      ├─► ① 台本からゆっくりボイス（キャラ別/ボイス種別）を一括自動生成
       │      ├─► ② 画像と音声をピッタリの尺で結合（MoviePy / FFmpeg）
       │      └─► ③ 完成したMP4をYouTubeへ非公開（限定公開）アップロード
       ▼
 [YouTube投稿完了]

```

---

## 準備編：環境構築

Macの「ターミナル」を開き、必要なツールのセットアップを行います。

### 1. Pythonライブラリのインストール

ターミナルで以下のコマンドを実行します。

```bash
pip install moviepy requests google-api-python-client google-auth-httplib2 google-auth-oauthlib

```

### 2. 音声合成エンジンの準備（VOICEVOX または AquesTalk）

手軽かつ高品質に「女性1」「女性2」「中性」などの声を生成するため、無料の音声合成エンジン **VOICEVOX**（またはAquesTalkのローカルAPI）をMacにインストールしてバックグラウンドで起動しておきます。

---

## 実践編：ファイルの作成と設定

作業用フォルダ（例: `slide_video_project`）を作成し、その中に以下のファイル・フォルダを配置します。

```text
slide_video_project/
├── auto_pipeline.py       # 自動化メインスクリプト
├── script.csv             # 台本ファイル
├── client_secret.json     # YouTube API用認証鍵（GCPからダウンロード）
├── slides/                # Keynoteから書き出したPNG画像を入れるフォルダ
└── audios/                # 生成された音声が自動保存されるフォルダ

```

### 1. 台本ファイル（`script.csv`）の作成

スライド番号、読み上げるテキスト、そしてキャラクター（声の種類）を指定します。

```csv
slide_num,character,text
1,霊夢,こんにちは！今回は〇〇について解説するよ。
2,魔理沙,よろしくぜ。まずはこのポイントから見ていこう。
3,案内役（中性）,ここが一番重要な部分になります。

```

---

### 2. メインスクリプト（`auto_pipeline.py`）の作成

以下のコードをコピーして `auto_pipeline.py` として保存します。

```python
import os
import csv
import requests
from moviepy.editor import ImageClip, AudioFileClip, concatenate_videoclips
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google_auth_oauthlib.flow import InstalledAppFlow

# ==========================================
# 設定: キャラクター・ボイスプロファイル定義
# ==========================================
# VOICEVOX等の話者ID（Speaker ID）マッピング
# 女性1(f1相当)=2, 女性2(f2相当)=3, 中性(d_1相当)=8 など
VOICE_PROFILES = {
    "霊夢": {"speaker_id": 2, "speed": 1.0},
    "魔理沙": {"speaker_id": 3, "speed": 1.05},
    "案内役（中性）": {"speaker_id": 8, "speed": 1.0},
    "ナレーション（ロボ）": {"speaker_id": 13, "speed": 1.1}
}

# ==========================================
# 1. 音声の一括生成処理
# ==========================================
def generate_audios_from_csv(csv_path):
    print("--- [Step 1] 音声の自動生成を開始 ---")
    os.makedirs("audios", exist_ok=True)
    
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            slide_num = row['slide_num']
            char_name = row['character']
            text = row['text']
            
            profile = VOICE_PROFILES.get(char_name, {"speaker_id": 2, "speed": 1.0})
            speaker_id = profile["speaker_id"]
            
            # VOICEVOX APIへのリクエスト (localhost:50021)
            base_url = "http://localhost:50021"
            
            # クエリ作成
            res_query = requests.post(f"{base_url}/audio_query", params={"text": text, "speaker": speaker_id})
            query_data = res_query.json()
            query_data["speedScale"] = profile["speed"]
            
            # 音声波形生成
            res_synth = requests.post(f"{base_url}/synthesis", params={"speaker": speaker_id}, json=query_data)
            
            audio_path = f"audios/slide_{slide_num}.wav"
            with open(audio_path, 'wb') as audio_file:
                audio_file.write(res_synth.content)
                
            print(f"スライド {slide_num} ({char_name}): 音声作成完了")

# ==========================================
# 2. 画像と音声を結合して動画化 (FCP代替)
# ==========================================
def render_video_from_slides(slide_count, output_mp4="output.mp4"):
    print("\n--- [Step 2] 動画の自動結合・レンダリングを開始 ---")
    clips = []
    
    for i in range(1, slide_count + 1):
        img_path = f"slides/slide_{i}.png"  # Keynoteから書き出した画像
        audio_path = f"audios/slide_{i}.wav"
        
        if not os.path.exists(img_path) or not os.path.exists(audio_path):
            print(f"エラー: スライド {i} の画像または音声が見つかりません。")
            continue
            
        audio_clip = AudioFileClip(audio_path)
        # 音声の尺に合わせて画像の表示時間をピッタリ自動調整
        img_clip = ImageClip(img_path).set_duration(audio_clip.duration).set_audio(audio_clip)
        clips.append(img_clip)

    final_clip = concatenate_videoclips(clips, method="compose")
    final_clip.write_videofile(output_mp4, fps=24, codec="libx264", audio_codec="aac")
    print(f"動画の生成が完了しました: {output_mp4}")
    return output_mp4

# ==========================================
# 3. YouTubeへの非公開（限定公開）自動投稿
# ==========================================
def upload_to_youtube(video_path, title="【自動生成】スライド解説動画"):
    print("\n--- [Step 3] YouTubeへ投稿を開始 ---")
    SCOPES = ['https://www.googleapis.com/auth/youtube.upload']
    
    flow = InstalledAppFlow.from_client_secrets_file('client_secret.json', SCOPES)
    credentials = flow.run_local_server(port=0)
    youtube = build('youtube', 'v3', credentials=credentials)

    body = {
        'snippet': {
            'title': title,
            'description': '自動処理パイプラインにより投稿された動画です。',
            'categoryId': '27' # 教育・ノウハウ
        },
        'status': {
            'privacyStatus': 'unlisted' # 'unlisted' (限定公開) または 'private' (非公開)
        }
    }

    media = MediaFileUpload(video_path, chunksize=-1, resumable=True)
    request = youtube.videos().insert(part='snippet,status', body=body, media_body=media)
    
    response = request.execute()
    print(f"アップロード完了！ 動画ID: https://youtu.be/{response.get('id')}")

# ==========================================
# パイプライン実行
# ==========================================
if __name__ == "__main__":
    CSV_FILE = "script.csv"
    
    # 1. 音声生成
    generate_audios_from_csv(CSV_FILE)
    
    # 台本行数をカウントしてスライド枚数を自動取得
    with open(CSV_FILE, 'r', encoding='utf-8') as f:
        slide_count = sum(1 for _ in f) - 1
        
    # 2. 動画合成
    mp4_file = render_video_from_slides(slide_count)
    
    # 3. YouTube投稿
    upload_to_youtube(mp4_file)

```

---

## 運用編：日常の作成ルーティン

設定完了後は、動画作成時の作業が以下の3ステップのみに短縮されます。

1. **Keynoteでスライド作成** ➔ `ファイル` ＞ `書き出し先` ＞ `イメージ` で `slides/` フォルダへPNG保存。
2. **`script.csv` に台本を入力**（スライド番号・キャラ名・テロップ）。
3. **ターミナルでスクリプトを実行**:
```bash
python auto_pipeline.py

```



処理が完了すると、自動的にYouTube上に限定公開（非公開）動画としてアップロードされます。

はい、**APIを使わず、Web上のChatGPTなどの通常チャット画面（ブラウザ）から直接指示してCSVを作成する方法**もあります。

スライド画像（PNG）をチャット画面にアップロードしてプロンプト（指示文）を入力すれば、AIが画面内のテキストを読み取って台本データ（CSV形式）を出力してくれます。

---

### 通常チャットで実行する手順

1. **スライド画像をアップロードする**
* Keynoteから書き出したスライド画像（PNG）を、チャットの添付ボタン（＋マーク）やドラッグ＆ドロップでアップロードします。
* ※一度に複数の画像をまとめて選択してアップロードできます。


2. **以下のプロンプト（指示文）を入力して送信する**

#### プロンプト（コピーしてそのままお使いいただけます）

```text
添付したスライド画像（ファイル名順）のテロップや主要な解説テキストを読み取り、以下の条件に従って台本データを作成してください。

【条件】
1. 出力はコードブロック内に「CSV形式」のみで出力してください。
2. ヘッダー行は「slide_num,character,text」としてください。
3. character（話者）は、テキストの口調や内容に合わせて「霊夢」「魔理沙」「案内役（中性）」のいずれかを自動で割り当ててください。
4. textには改行を含めず、読み上げ用の1文として出力してください。

【出力フォーマット例】
slide_num,character,text
1,霊夢,こんにちは！今回は〇〇について解説するよ。
2,魔理沙,よろしくぜ。まずはこのポイントから見ていこう。
3,案内役（中性）,ここが一番重要な部分になります。

```

3. **出力されたCSVテキストを保存する**
* チャット上にコードブロック形式でCSVデータが生成されます。
* 右上の「コピー」ボタンを押し、テキストエディタ（メモ帳やTextEdit等）に貼り付けて `script.csv` という名前で保存します。



---

### メリットと注意点

* **メリット**: APIキーの発行やPythonでの画像解析処理を組む必要がなく、ブラウザだけで完結します。
* **注意点**: 100枚などの大量のスライド画像を一度にアップロードすると、一度のチャットで扱える画像数や出力文字数の上限に達する場合があります。その場合は**10〜20枚ずつ分けてアップロード**して指示するのがスムーズです。

生成された `script.csv` さえ保存できれば、あとは先ほど構築した `auto_pipeline.py` を実行するだけで、音声生成からYouTube非公開投稿までを自動で行えます。
