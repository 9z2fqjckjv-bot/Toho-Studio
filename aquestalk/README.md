# AquesTalk ローカルインストール

このフォルダには、`aquestalk_local_api.py` が使用する AquesTalk10 のローカル実行環境を配置しています。

配置済みファイル:

- `libAquesTalk10.dylib`: 株式会社アクエストが配布する AquesTalk10 Mac 1.1.1 の実行ライブラリ

ローカル API の起動方法:

```bash
cp .env.example .env
# .env を編集し、license.pdf に記載された値を設定してください。
python3 aquestalk_local_api.py
```

環境変数を直接指定して起動することもできます。

```bash
AQUESTALK_LICENSE_ID="your-license-id" \
AQUESTALK_USER_KEY="your-usage-license-key" \
python3 aquestalk_local_api.py
```

このサーバーは、`auto_pipeline.py` がすでに使用している VOICEVOX 風 API の一部を提供します。

- `POST /audio_query?text=...&speaker=2`
- `POST /synthesis?speaker=2`
- `GET /health`

AquesTalk10 が直接受け付けるのは、かなの音声記号列です。漢字を含む通常の日本語文を読み上げる場合は、AquesTalkPlayer Mac を `/Applications` にインストールするか、`AQUESTALKPLAYER_PATH` に実行ファイルのパスを設定してください。

```bash
export AQUESTALKPLAYER_PATH="/Applications/AquesTalkPlayer.app/Contents/MacOS/AquesTalkPlayer"
```

ライセンスについて:

アクエストの評価版パッケージには、利用目的や再配布に関する制限があります。商用利用、継続利用、公開コンテンツでの利用を行う場合は、API を起動する前にライセンス情報を環境変数で設定してください。

- `AQUESTALK_LICENSE_ID`: 契約書に記載されたライセンス ID です。ローカル管理用であり、AquesTalk ライブラリには渡しません。
- `AQUESTALK_USER_KEY`: 契約書に記載された使用ライセンスキーです。起動時に `AquesTalk_SetUsrKey()` へ渡します。
- `AQUESTALK_DEV_KEY`: 任意の開発ライセンスキーです。設定されている場合は、起動時に `AquesTalk_SetDevKey()` へ渡します。

ライセンス値や `license.pdf` は Git にコミットしないでください。
