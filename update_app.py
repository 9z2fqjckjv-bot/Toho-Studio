import re

with open('src/web/app.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace absolute paths with dynamic paths based on this.config.project_root or fallback to hardcoded relative
# Actually, the media endpoint is /media/<path>
# Let's replace the absolute prefix with nothing, so it becomes just 交換夫婦/...
# which the backend will resolve via PROJECT_ROOT.

content = content.replace(
    '`/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story/交換夫婦/',
    '`交換夫婦/'
)
# For the video Path
content = content.replace(
    "video_path: `/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story/交換夫婦/完成動画/${this.project.project_name}_完成版.mp4`",
    "video_path: `交換夫婦/完成動画/${this.project.project_name}_完成版.mp4`"
)

# Wait, if we set imgPath = `交換夫婦/スライド画像/...`, later in app.js:
# imgUrl = `/media/${encodeURIComponent(comp.imgPath)}`;
# this means it requests /media/交換夫婦%2Fスライド画像%2F...
# That will be unquoted to 交換夫婦/スライド画像/... in backend, and resolved to PROJECT_ROOT / 交換夫婦 / ...
# This is perfect!

with open('src/web/app.js', 'w', encoding='utf-8') as f:
    f.write(content)
