import os

def get_project_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

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
