import re

# corpus_learner.py
with open('src/core/corpus_learner.py', 'r', encoding='utf-8') as f:
    content = f.read()
if 'from .path_utils import get_series_dir' not in content:
    content = content.replace('from typing import List, Dict, Any\n', 'from typing import List, Dict, Any\nfrom .path_utils import get_series_dir\n')

content = re.sub(
    r'TOHO_DIR = os\.path\.join\(PROJECT_ROOT, "交換夫婦"\)',
    r'TOHO_DIR = get_series_dir("")',
    content
)
content = re.sub(
    r'CACHE_FILE = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "corpus_cache\.json"\)',
    r'CACHE_FILE = os.path.join(TOHO_DIR, "corpus_cache.json")',
    content
)
with open('src/core/corpus_learner.py', 'w', encoding='utf-8') as f:
    f.write(content)

# keynote_parser.py
with open('src/core/keynote_parser.py', 'r', encoding='utf-8') as f:
    content = f.read()

if 'from .path_utils import get_series_dir, get_media_dir' not in content:
    content = content.replace('from typing import List, Dict, Any, Optional\n', 'from typing import List, Dict, Any, Optional\nfrom .path_utils import get_series_dir, get_media_dir\n')

content = re.sub(
    r'DEFAULT_KEYNOTE_DIR = os\.path\.join\(PROJECT_ROOT, "交換夫婦"\)',
    r'DEFAULT_KEYNOTE_DIR = get_series_dir("")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", f"\{base_name\}\.tpmproj"\)',
    r'os.path.join(get_series_dir(base_name), f"{base_name}.tpmproj")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライド画像", base_name\)',
    r'os.path.join(get_media_dir(base_name, "スライド画像"), base_name)',
    content
)
content = re.sub(
    r'slides_img_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライド画像", base_name\)',
    r'slides_img_dir = os.path.join(get_media_dir(base_name, "スライド画像"), base_name)',
    content
)
content = re.sub(
    r'slides_movie_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライドムービー"\)',
    r'slides_movie_dir = get_media_dir(base_name, "スライドムービー")',
    content
)
content = re.sub(
    r'slide_clip_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライド動画", base_name\)',
    r'slide_clip_dir = os.path.join(get_media_dir(base_name, "スライド動画"), base_name)',
    content
)
content = re.sub(
    r'out_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライド動画", base_name\)',
    r'out_dir = os.path.join(get_media_dir(base_name, "スライド動画"), base_name)',
    content
)

with open('src/core/keynote_parser.py', 'w', encoding='utf-8') as f:
    f.write(content)

# script_manager.py
with open('src/core/script_manager.py', 'r', encoding='utf-8') as f:
    content = f.read()

if 'from .path_utils import get_media_dir' not in content:
    content = content.replace('from typing import List, Dict, Any\n', 'from typing import List, Dict, Any\nfrom .path_utils import get_media_dir\n')

content = re.sub(
    r'SCRIPT_DIR = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "台本"\)',
    r'SCRIPT_DIR = get_media_dir("", "台本")',
    content
)
with open('src/core/script_manager.py', 'w', encoding='utf-8') as f:
    f.write(content)


# audio_video_merger.py
with open('src/core/audio_video_merger.py', 'r', encoding='utf-8') as f:
    content = f.read()

if 'from .path_utils import get_media_dir' not in content:
    content = content.replace('from typing import List, Dict, Any, Optional\n', 'from typing import List, Dict, Any, Optional\nfrom .path_utils import get_media_dir\n')

content = re.sub(
    r'movie_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライドムービー"\)',
    r'movie_dir = get_media_dir("", "スライドムービー")',
    content
)
with open('src/core/audio_video_merger.py', 'w', encoding='utf-8') as f:
    f.write(content)
