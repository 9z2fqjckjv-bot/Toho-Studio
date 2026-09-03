# Toho-Project-Second-Story

Mac のターミナルから、Drive 同期フォルダ内の Python アプリを起動するためのリポジトリです。

対象:

- `app.py`（東方Projectムービーメーカー）
- `psd_studio_app.py`

本体のソースは GitHub ではなく、Google Drive for Desktop の次の場所にあります。

`パソコン` → `マイ Mac` → `ZSSD` → `GitHub` → `repository` → `Toho-Project-Second-Story`

## 起動

ターミナル:

```sh
cd /path/to/Toho-Project-Second-Story
python3 launch.py
```

または:

```sh
sh launch.sh
```

パスを明示する場合:

```sh
python3 launch.py --project "$HOME/ZSSD/GitHub/repository/Toho-Project-Second-Story"
```

環境変数 `TOHO_PROJECT_ROOT` でも指定できます。プロジェクトに `.venv` があれば、その中の Python を使います。

`psd_studio_app.py` がまだフォルダに無い場合は `app.py` だけ起動し、見つからなかった旨を表示します。
