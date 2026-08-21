# Toho-Project-Second-Story
東方Project二次創作のスライド画像を動画にする

## 主要ファイル

- `script.csv`: 動画生成に使う台本です。`text` と `phoneme_sequence` には AquesTalk 用の音声記号列を入れます。
- `ボイス設定.csv`: キャラクターごとの声質、速度、音程の設定です。`auto_pipeline.py` 実行時に `script.csv` の設定へ反映されます。
- `aquestalk_local_api.py`: VOICEVOX 風のローカル AquesTalk API です。
- `auto_pipeline.py`: 音声生成、スライド画像との結合、動画出力を行います。

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
