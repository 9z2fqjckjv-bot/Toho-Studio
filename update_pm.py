import re

with open('src/core/project_manager.py', 'r', encoding='utf-8') as f:
    content = f.read()

if 'from .path_utils import get_series_dir, get_media_dir' not in content:
    content = content.replace('from typing import Dict, Any, Optional, List\n', 'from typing import Dict, Any, Optional, List\nfrom .path_utils import get_series_dir, get_media_dir\n')

content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", "音声", project_name\)',
    r'os.path.join(get_media_dir(project_name, "音声"), project_name)',
    content
)

content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", sub_dir, base_file\) if sub_dir else None,',
    r'os.path.join(get_series_dir(project_name), sub_dir, base_file) if sub_dir else None,',
    content
)

content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", project_name, base_file\),',
    r'os.path.join(get_series_dir(project_name), project_name, base_file),',
    content
)

content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "幼き日の夢", sub_dir, base_file\) if sub_dir else None,',
    r'',
    content
)

content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "幼き日の夢", project_name, base_file\),',
    r'',
    content
)

content = re.sub(
    r'for cand_dir in \[PROJECT_ROOT, os\.path\.join\(PROJECT_ROOT, "交換夫婦"\), os\.path\.join\(PROJECT_ROOT, "幼き日の夢"\)\]:',
    r'for cand_dir in [PROJECT_ROOT, get_series_dir(p_name)]:',
    content
)

content = re.sub(
    r'cand_v = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライドムービー", v_base\)',
    r'cand_v = os.path.join(get_media_dir(p_name, "スライドムービー"), v_base)',
    content
)

content = re.sub(
    r'slide_img_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライド画像", p_name\)',
    r'slide_img_dir = os.path.join(get_media_dir(p_name, "スライド画像"), p_name)',
    content
)

content = re.sub(
    r'slide_vid_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライド動画", p_name\)',
    r'slide_vid_dir = os.path.join(get_media_dir(p_name, "スライド動画"), p_name)',
    content
)

content = re.sub(
    r'audio_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "音声", p_name\)',
    r'audio_dir = os.path.join(get_media_dir(p_name, "音声"), p_name)',
    content
)

with open('src/core/project_manager.py', 'w', encoding='utf-8') as f:
    f.write(content)
