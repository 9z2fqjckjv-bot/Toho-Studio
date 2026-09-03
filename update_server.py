import re

with open('src/server.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'from .core.path_utils import get_series_dir, get_media_dir' not in content:
    content = content.replace('from .core.crash_reporter import get_crash_reporter\n', 'from .core.crash_reporter import get_crash_reporter\nfrom .core.path_utils import get_series_dir, get_media_dir\n')

# Global OUTPUT dirs
content = re.sub(
    r'AUDIO_OUTPUT_DIR = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "音声"\)',
    r'# AUDIO_OUTPUT_DIR is now resolved dynamically',
    content
)
content = re.sub(
    r'VIDEO_OUTPUT_DIR = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "完成動画"\)',
    r'# VIDEO_OUTPUT_DIR is now resolved dynamically',
    content
)

# Fix ep_audio_dir
content = re.sub(
    r'ep_audio_dir = os\.path\.join\(AUDIO_OUTPUT_DIR, project_name\)',
    r'ep_audio_dir = os.path.join(get_media_dir(project_name, "音声"), project_name)',
    content
)

# Fix os.path.join(PROJECT_ROOT, "交換夫婦")
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦"\)',
    r'get_series_dir("")',
    content
)

# Fix slide_clip_dir
content = re.sub(
    r'slide_clip_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライド動画", p_name\)',
    r'slide_clip_dir = os.path.join(get_media_dir(p_name, "スライド動画"), p_name)',
    content
)

# Fix movie_dir
content = re.sub(
    r'movie_dir = os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライドムービー"\)',
    r'movie_dir = get_media_dir(p_name, "スライドムービー")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライドムービー", f"\{p_name\}\.mov"\)',
    r'os.path.join(get_media_dir(p_name, "スライドムービー"), f"{p_name}.mov")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライドムービー", f"\{project_name\}\.mov"\)',
    r'os.path.join(get_media_dir(project_name, "スライドムービー"), f"{project_name}.mov")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", "スライドムービー", f"\{project_name\}\.mp4"\)',
    r'os.path.join(get_media_dir(project_name, "スライドムービー"), f"{project_name}.mp4")',
    content
)


# Fix video_output_dir
content = re.sub(
    r'os\.makedirs\(VIDEO_OUTPUT_DIR, exist_ok=True\)',
    r'vid_out = get_media_dir(project_name, "完成動画")\n                        os.makedirs(vid_out, exist_ok=True)',
    content
)
content = re.sub(
    r'out_video_path = os\.path\.join\(VIDEO_OUTPUT_DIR, f"\{project_name\}_完成版\{out_ext\}"\)',
    r'out_video_path = os.path.join(vid_out, f"{project_name}_完成版{out_ext}")',
    content
)

# Fix API sync durations (the big loop)
content = re.sub(
    r'for sub in os\.listdir\(os\.path\.join\(repo_root, "交換夫婦", "スライド動画"\)\) if os\.path\.isdir\(os\.path\.join\(repo_root, "交換夫婦", "スライド動画"\)\) else \[\]:',
    r'vid_base = os.path.join(get_series_dir(project_name), "スライド動画")\n                    for sub in os.listdir(vid_base) if os.path.isdir(vid_base) else []:',
    content
)
content = re.sub(
    r'project_video_dir = os\.path\.join\(repo_root, "交換夫婦", "スライド動画", sub\)',
    r'project_video_dir = os.path.join(vid_base, sub)',
    content
)
content = re.sub(
    r'for sub in os\.listdir\(os\.path\.join\(repo_root, "交換夫婦", "音声"\)\) if os\.path\.isdir\(os\.path\.join\(repo_root, "交換夫婦", "音声"\)\) else \[\]:',
    r'aud_base = os.path.join(get_series_dir(project_name), "音声")\n                    for sub in os.listdir(aud_base) if os.path.isdir(aud_base) else []:',
    content
)
content = re.sub(
    r'project_audio_dir = os\.path\.join\(repo_root, "交換夫婦", "音声", sub\)',
    r'project_audio_dir = os.path.join(aud_base, sub)',
    content
)


# Keynote imports
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", f"\{project_name\}\.key"\)',
    r'os.path.join(get_series_dir(project_name), f"{project_name}.key")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", f"\{project_name\}\.keynote"\)',
    r'os.path.join(get_series_dir(project_name), f"{project_name}.keynote")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", "音声", p_name, f"slide_\{s_idx:03d\}\.wav"\)',
    r'os.path.join(get_media_dir(p_name, "音声"), p_name, f"slide_{s_idx:03d}.wav")',
    content
)
content = re.sub(
    r'os\.path\.join\(PROJECT_ROOT, "交換夫婦", f"\{project_name\}\.tpmproj"\)',
    r'os.path.join(PROJECT_ROOT, f"{project_name}.tpmproj")',
    content
)


with open('src/server.py', 'w', encoding='utf-8') as f:
    f.write(content)

