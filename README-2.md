# Toho-Project-Second-Story
東方Project二次創作のスライド画像を動画にする

## 主要ファイル

- `script.csv`: 動画生成に使う台本です。`text` と `phoneme_sequence` には AquesTalk 用の音声記号列を入れます。
- `ボイス設定.csv`: キャラクターごとの声質、速度、音程の設定です。`auto_pipeline.py` 実行時に `script.csv` の設定へ反映されます。
- `aquestalk_local_api.py`: VOICEVOX 風のローカル AquesTalk API です。
- `auto_pipeline.py`: 音声生成、スライド画像との結合、動画出力を行います。
- `toho_movie_studio.py`: 素材走査、動画/音声/スライド/台本の照合、既存 Python 処理の起動、既存動画へのスライド挿入、BGM/効果音ミックス、進捗付き MP4 書き出しを行う Mac アプリ用 CLI です。
- `rules_pipeline.py`: `rules.html` に沿って、台本抽出、確認事項の検出、音声生成、動画作成を一括実行します。`rules.html` と `motoscript.csv` は変更しません。
- `Sources/TohoMovieStudio/TohoMovieStudioApp.swift`: `toho_movie_studio.py` を操作する SwiftUI 製 Mac アプリです。

## 実行

先に別ターミナルでローカルAPIを起動します。

```bash
source .venv/bin/activate
python3 aquestalk_local_api.py
```

その後、動画生成パイプラインを実行します。

```bash
source .venv/bin/activate
python3 auto_pipeline.py
```

`auto_pipeline.py` は `phoneme_sequence` を優先して読みます。旧形式のローマ字音素列の場合は読み上げに使わず、`text` または `kana_reading` にフォールバックします。

`rules.html` に沿った確認込みの一括実行は次のコマンドを使います。迷シーンはユーザー判断が必要なため、`Movie archive/sample/` を見て選んだスライド番号か開始秒を指定します。

```bash
source .venv/bin/activate
python3 rules_pipeline.py check --script script.csv
python3 rules_pipeline.py all --script script.csv --highlight-slide 90
```

## Mac アプリ

SwiftUI アプリは Swift Package として追加されています。

```bash
swift run TohoMovieStudio
```

アプリ上でできることは次の通りです。

- `Movie archive/`、`slides/`、`audios/` 配下の動画、スライド画像、音声ファイルを読み込みます。
- `AquesTalk API起動` で既存の `aquestalk_local_api.py` を起動します。
- `台本作成` で `keynote_telop_to_csv.py` を実行します。
- `音声+基本動画` で `auto_pipeline.py` を実行します。
- `分析` で入力動画、スライド画像、音声データ、台本CSVを照合し、動画に存在しないスライド画像をスライド順の追加シーン候補として表示します。
- 追加シーンごとに有効/無効、挿入位置、表示秒数、効果音を編集できます。挿入位置は 1 秒単位で指定します。
- `挿入+音響+書き出し` で `movie_studio_plan.json` を保存し、既存動画に追加スライドを挿入し、BGM と効果音を合成して MP4 を書き出します。
- 書き出し中はポップアップで状況、残りシーン数、経過時間、推定残り時間を表示します。

コマンドラインだけで使う場合は次のように実行できます。

```bash
source .venv/bin/activate
python3 toho_movie_studio.py scan --json
python3 toho_movie_studio.py analyze \
  --input "Movie archive/交換夫婦/22話.mp4" \
  --script script.csv \
  --json
python3 toho_movie_studio.py export \
  --input "Movie archive/交換夫婦/22話.mp4" \
  --script script.csv \
  --output studio_export.mp4 \
  --bgm "audios/bgm.mp3" \
  --se "audios/se.wav" \
  --progress-json
```

細かい挿入位置を指定したい場合は、`movie_studio_plan.example.json` を `movie_studio_plan.json` にコピーして編集します。`extra_scenes` の `slide` にスライド画像、`duration` に表示秒数、`se` に効果音、`enabled` に有効/無効を指定します。`at` は元動画上の挿入位置で、1 秒単位の秒数を指定します。`at` が `0` または `null` のシーンは動画冒頭に挿入されます。
