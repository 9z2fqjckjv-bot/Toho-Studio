import re

with open('src/core/project_manager.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Add series_name to create_empty_project
content = content.replace(
    '"project_file_path": os.path.join(PROJECT_ROOT, f"{project_name}.tpmproj"),',
    '"project_file_path": os.path.join(PROJECT_ROOT, f"{project_name}.tpmproj"),\n            "series_name": os.path.basename(get_series_dir(project_name)),'
)

# Also in _relocate_project_media
content = content.replace(
    'data["project_file_path"] = project_file_path',
    'data["project_file_path"] = project_file_path\n        data["series_name"] = os.path.basename(get_series_dir(p_name))'
)

with open('src/core/project_manager.py', 'w', encoding='utf-8') as f:
    f.write(content)
