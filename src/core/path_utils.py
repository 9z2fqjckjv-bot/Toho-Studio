import os

# Dedicated app data roots (edit / backup / export / log / program)
CHAR_STUDIO_DIRNAME = "東方キャラ立ち絵スタジオ"
# Finder / SSD 上の実フォルダ名（末尾の長音あり）
MOVIE_MAKER_DIRNAME = "東方ムービーメーカー"
# 旧表記（長音なし）も互換参照する
MOVIE_MAKER_DIRNAME_ALIASES = ("東方ムービーメーカー", "東方ムービーメーカ")


def get_project_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def get_app_data_root(app_dirname: str, root_dir: str = None) -> str:
    """Return <project>/<app_dirname>, creating it if needed."""
    if root_dir is None:
        root_dir = get_project_root()
    path = os.path.join(root_dir, app_dirname)
    os.makedirs(path, exist_ok=True)
    return path


def get_char_studio_root(root_dir: str = None) -> str:
    return get_app_data_root(CHAR_STUDIO_DIRNAME, root_dir)


def get_movie_maker_root(root_dir: str = None) -> str:
    if root_dir is None:
        root_dir = get_project_root()
    for name in MOVIE_MAKER_DIRNAME_ALIASES:
        path = os.path.join(root_dir, name)
        if os.path.isdir(path):
            return path
    return get_app_data_root(MOVIE_MAKER_DIRNAME, root_dir)


def resolve_license_file(root_dir: str = None) -> str:
    """Find AquesTalk license.txt after folder reorganization."""
    if root_dir is None:
        root_dir = get_project_root()
    env = os.environ.get("TOHO_LICENSE_FILE") or os.environ.get("AQUESTALK_LICENSE_FILE")
    candidates = []
    if env:
        candidates.append(os.path.expanduser(env))
    candidates.extend([
        os.path.join(root_dir, "license.txt"),
        os.path.join(root_dir, "documents", "license.txt"),
        os.path.join(get_movie_maker_root(root_dir), "license.txt"),
        os.path.join(get_movie_maker_root(root_dir), "program", "license.txt"),
        os.path.join(get_char_studio_root(root_dir), "license.txt"),
    ])
    for path in candidates:
        if path and os.path.isfile(path):
            return path
    return os.path.join(root_dir, "documents", "license.txt")


def get_app_subdir(app_dirname: str, sub: str, root_dir: str = None) -> str:
    """program | projects | backups | exports | logs under an app folder."""
    base = get_app_data_root(app_dirname, root_dir)
    path = os.path.join(base, sub)
    os.makedirs(path, exist_ok=True)
    return path


def ensure_app_layout(root_dir: str = None) -> dict:
    """Create both apps' standard folder trees and return paths."""
    if root_dir is None:
        root_dir = get_project_root()
    layout = {}
    for app in (CHAR_STUDIO_DIRNAME, MOVIE_MAKER_DIRNAME):
        layout[app] = {}
        for sub in ("program", "projects", "backups", "exports", "logs"):
            layout[app][sub] = get_app_subdir(app, sub, root_dir)
    return layout


def get_series_dir(project_name: str, root_dir: str = None) -> str:
    """Finds the base directory (series directory) for a given project_name."""
    if root_dir is None:
        root_dir = get_project_root()

    if not project_name:
        return os.path.join(root_dir, "交換夫婦")

    try:
        for item in os.listdir(root_dir):
            d = os.path.join(root_dir, item)
            if os.path.isdir(d) and not item.startswith('.'):
                if project_name.startswith(item):
                    return d
                if os.path.exists(os.path.join(d, f"{project_name}.key")) or os.path.exists(os.path.join(d, f"{project_name}.keynote")):
                    return d
    except Exception:
        pass

    default_series = os.path.join(root_dir, "交換夫婦")
    if os.path.exists(default_series):
        return default_series

    return root_dir


def get_media_dir(project_name: str, media_type: str) -> str:
    """Gets the path to the media directory for the given project, e.g., '音声' or 'スライド画像'."""
    series_dir = get_series_dir(project_name)
    return os.path.join(series_dir, media_type)
