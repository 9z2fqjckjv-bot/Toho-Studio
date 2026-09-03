# Toho-Project-Second-Story 運用メモ

このプロジェクトは、Keynote で作成した東方Project二次創作スライドを、AquesTalk 音声付きの動画に変換し、YouTube へ限定公開アップロードするための自動化環境です。

Mac のターミナルでは、必ずプロジェクト直下へ移動してから作業します。

```bash
cd "/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story"
```

## 現在のフォルダ構成

```text
Toho-Project-Second-Story/
├── .env                               # AquesTalk ライセンスとエンジン設定
├── .gitignore
├── README.md
├── info.md                            # この運用メモ
├── auto_pipeline.py                   # 音声生成、動画生成、YouTube投稿のメイン処理
├── aquestalk_local_api.py             # VOICEVOX風のローカルAquesTalk API
├── keynote_telop_to_csv.py            # KeynoteファイルからテロップCSVを抽出
├── script.csv                         # auto_pipeline.py が読む台本CSV
├── 交換夫婦22話-台本.csv              # 作品別の台本CSV
├── ボイス設定.csv                    # キャラクター別の声質、速度、音程設定
├── client_secret.json                 # YouTube API OAuth クライアント設定
├── client_secret.json.example
├── license.pdf                        # AquesTalk ライセンス資料
├── aquestalk/
│   ├── README.md
│   └── libAquesTalk10.dylib           # AquesTalk10 Mac用ライブラリ
├── aquestalk1/
│   ├── README.md
│   └── libAquesTalk1-*.dylib          # AquesTalk1 Mac用ライブラリを配置
├── slides/
│   ├── .gitkeep
│   └── 交換夫婦（22話目）.key          # Keynote元ファイル
└── audios/
    └── .gitkeep                       # 生成されたwavの保存先
```

## 全体の流れ

```text
Keynoteファイル
    │
    ├─ keynote_telop_to_csv.py
    │      └─ テロップ、話者、声質、速度、音程をCSV化
    │
    ├─ KeynoteからPNGを書き出し
    │      └─ slides/slide_1.png, slides/slide_2.png ...
    │
    ├─ aquestalk_local_api.py
    │      └─ http://localhost:50021 で音声合成APIを起動
    │
    └─ auto_pipeline.py
           ├─ script.csv から audios/slide_*.wav を生成
           ├─ slides/ と audios/ を結合して output.mp4 を生成
           └─ output.mp4 を YouTube へ限定公開アップロード
```

## 初回セットアップ

### 1. Python仮想環境を作成

macOS では `python` ではなく `python3` を使うのが安全です。

```bash
cd "/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story"
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip
```

以後、新しいターミナルを開いたときは次のコマンドで仮想環境を有効化します。

```bash
cd "/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story"
source .venv/bin/activate
```

### 2. 必要ライブラリをインストール

```bash
python3 -m pip install \
  moviepy \
  requests \
  google-api-python-client \
  google-auth-httplib2 \
  google-auth-oauthlib \
  keynote-parser \
  PyYAML
```

MoviePy が内部で使う FFmpeg が見つからない場合は、Homebrew で入れます。

```bash
brew install ffmpeg
```

### 3. AquesTalk1 の設定

`.env` を開き、AquesTalk1 を使う設定になっていることを確認します。

```bash
open -e .env
```

`.env` には次の値を設定します。既にライセンス値が入っている場合は消さないでください。

```text
AQUESTALK_LICENSE_ID=...
AQUESTALK_USER_KEY=...
AQUESTALK_ENGINE=aquestalk1
AQUESTALK1_LIB_DIR=aquestalk1
```

AquesTalk1 Mac のDMGを開き、声種ごとの `.dylib` を `aquestalk1/` にコピーします。

```bash
mkdir -p aquestalk1
cp "/Volumes/AquesTalk1/"**/libAquesTalk1-*.dylib aquestalk1/
ls aquestalk1/libAquesTalk1-*.dylib
```

AquesTalk1 は漢字かな混じり文ではなく、かな表記の音声記号列を入力します。`script.csv` の `text` は、ひらがな、カタカナ、句読点、AquesTalk用の音声記号で書いてください。

AquesTalk10 に戻したい場合だけ、`.env` を次のように変更します。

```text
AQUESTALK_ENGINE=aquestalk10
```

### 4. YouTube API の設定

YouTube へアップロードする場合は、Google Cloud Console で YouTube Data API v3 を有効化し、OAuth クライアントの JSON を `client_secret.json` としてプロジェクト直下に置きます。

初回アップロード時はブラウザが開き、Google アカウントでの認可が求められます。

## 日常運用

### 1. KeynoteからテロップCSVを作る

Keynoteファイルから下部テロップを抽出して `script.csv` を作ります。

```bash
python3 keynote_telop_to_csv.py "slides/交換夫婦（22話目）.key" -o script.csv
```

作品別に保存したい場合は、出力先を変えます。

```bash
python3 keynote_telop_to_csv.py "slides/交換夫婦（22話目）.key" -o "交換夫婦22話-台本.csv"
cp "交換夫婦22話-台本.csv" script.csv
```

`script.csv` は `auto_pipeline.py` が読む固定ファイル名です。

主な列は次の通りです。

| 列名 | 内容 |
| --- | --- |
| `slide_num` | スライド番号。省略時はCSVの行順が使われます。 |
| `character` | 話者名。ログ表示や確認用です。 |
| `text` | 読み上げる本文です。 |
| `voice_type` | `f1`、`f2`、`中性`、`jgr` などの声質です。 |
| `speed` | 速度です。`100` が標準です。 |
| `pitch` | 音程です。`100` が標準です。 |

### 2. Keynoteから画像を書き出す

Keynote で次の操作を行います。

```text
ファイル > 書き出す > イメージ > PNG
```

書き出し先は `slides/` にします。

`auto_pipeline.py` は次のファイル名を探します。

```text
slides/slide_1.png
slides/slide_2.png
slides/slide_3.png
...
```

Keynote の書き出し名が `交換夫婦（22話目）.001.png` のようになる場合は、`slide_1.png`、`slide_2.png` の形式にリネームしてください。

### 3. AquesTalkローカルAPIを起動

ターミナルを1つ開き、プロジェクト直下で API サーバーを起動します。

```bash
cd "/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story"
source .venv/bin/activate
python3 aquestalk_local_api.py
```

起動できたら、別のターミナルで確認します。

```bash
curl http://127.0.0.1:50021/health
```

`"status": "ok"` が返れば準備完了です。

### 4. 自動パイプラインを実行

AquesTalk API を起動したまま、別のターミナルで実行します。

```bash
cd "/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story"
source .venv/bin/activate
python3 auto_pipeline.py
```

処理内容は次の通りです。

1. `script.csv` を読み込む
2. `audios/slide_*.wav` を生成する
3. `slides/slide_*.png` と音声を結合する
4. `output.mp4` を生成する
5. YouTube へ限定公開でアップロードする

## よく使う確認コマンド

現在の場所を確認します。

```bash
pwd
```

プロジェクト直下のファイルを確認します。

```bash
ls
```

スライド画像が正しい名前で存在するか確認します。

```bash
ls slides/slide_*.png
```

生成済み音声を確認します。

```bash
ls audios/slide_*.wav
```

CSVの先頭を確認します。

```bash
head -n 5 script.csv
```

## トラブル対応

### `python: command not found` と出る

Mac では `python3` を使います。

```bash
python3 auto_pipeline.py
```

### `ModuleNotFoundError` が出る

仮想環境が有効化されていないか、ライブラリが未インストールです。

```bash
source .venv/bin/activate
python3 -m pip install moviepy requests google-api-python-client google-auth-httplib2 google-auth-oauthlib keynote-parser PyYAML
```

### `Connection refused` または `localhost:50021` に接続できない

`aquestalk_local_api.py` が起動していません。別ターミナルで起動してください。

```bash
python3 aquestalk_local_api.py
```

### `slides/slide_1.png` が見つからない

Keynote から PNG を書き出したあと、ファイル名を `slide_1.png`、`slide_2.png` の形式に揃えてください。

### 動画だけ作りたい、YouTube投稿はしたくない

現在の `auto_pipeline.py` は、通常はYouTube投稿をスキップします。

投稿する場合だけ、次のように `UPLOAD_TO_YOUTUBE=1` を付けて実行します。

```bash
UPLOAD_TO_YOUTUBE=1 python3 auto_pipeline.py
```

### AquesTalk1 のライブラリが見つからない

`AquesTalk1 library for voice 'f1' not found` と出る場合は、`aquestalk1/` に `.dylib` がありません。

```bash
ls aquestalk1/libAquesTalk1-*.dylib
```

最低限、`script.csv` の `voice_type` に対応するファイルが必要です。

```text
f1  -> aquestalk1/libAquesTalk1-f1.dylib
f2  -> aquestalk1/libAquesTalk1-f2.dylib
jgr -> aquestalk1/libAquesTalk1-jgr.dylib
```

### CSVをブラウザ版ChatGPTで作りたい

Keynote から書き出したスライド画像を ChatGPT に添付し、次のように依頼します。

```text
添付したスライド画像をファイル名順に読み取り、読み上げ用CSVを作成してください。
出力はCSVのみ。
ヘッダーは character,text,voice_type,speed,pitch としてください。
voice_type は f1、f2、中性、jgr のいずれかを選んでください。
speed と pitch は標準を100として設定してください。
```

出力されたCSVを `script.csv` として保存すれば、`auto_pipeline.py` で利用できます。
