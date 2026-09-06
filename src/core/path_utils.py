import os

# Dedicated app data roots (edit / backup / export / log / program)
CHAR_STUDIO_DIRNAME = "東方キャラ立ち絵スタジオ"
MOVIE_MAKER_DIRNAME = "東方ムービーメーカ"


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
    return get_app_data_root(MOVIE_MAKER_DIRNAME, root_dir)


def get_app_subdir(app_dirname: str, sub: str, root_dir: str = None) -> str:
    """program | projects | backups | exports | logs under an app folder."""
    base = get_app_data_root(app_dirname, root_dir)
    path = os.path.join(base, sub)
    os.makedirs(path, exist_ok=True)
    return path


def ensure_app_layout(root_dir: str = None) -> dict:
    """Create both apps' standard folder trees and return paths."""
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

    # Check if a directory matching the project_name prefix exists
    try:
        for item in os.listdir(root_dir):
            d = os.path.join(root_dir, item)
            if os.path.isdir(d) and not item.startswith('.'):
                if project_name.startswith(item):
                    return d

                # Or if it contains a key file matching project_name
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
