import re

with open('src/web/app.js', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace `交換夫婦/ with `${sName}/
content = content.replace(
    'const pName = (this.project && this.project.project_name) ? this.project.project_name : "";',
    'const pName = (this.project && this.project.project_name) ? this.project.project_name : "";\n    const sName = (this.project && this.project.series_name) ? this.project.series_name : "交換夫婦";'
)

content = content.replace(
    'imgPath = `交換夫婦/スライド画像/${pName}/${pName}.${sNum}.jpeg`;',
    'imgPath = `${sName}/スライド画像/${pName}/${pName}.${sNum}.jpeg`;'
)
content = content.replace(
    'videoClip = `交換夫婦/スライド動画/${pName}/slide_${sNum}.mp4`;',
    'videoClip = `${sName}/スライド動画/${pName}/slide_${sNum}.mp4`;'
)
content = content.replace(
    'audioPath = `交換夫婦/音声/${pName}/slide_${sNum}.wav`;',
    'audioPath = `${sName}/音声/${pName}/slide_${sNum}.wav`;'
)

# For videoPath in setupMediaPreview
# The function might not have sName defined easily, let's just do a regex replace and add sName
content = re.sub(
    r'const pName = this\.project\.project_name;',
    r'const pName = this.project.project_name;\n          const sName = this.project.series_name || "交換夫婦";',
    content
)
content = content.replace(
    'videoPath = `交換夫婦/スライド動画/${pName}/slide_${sNum}.mp4`;',
    'videoPath = `${sName}/スライド動画/${pName}/slide_${sNum}.mp4`;'
)

# For export video path
content = content.replace(
    'video_path: `交換夫婦/完成動画/${this.project.project_name}_完成版.mp4`,',
    'video_path: `${this.project.series_name || "交換夫婦"}/完成動画/${this.project.project_name}_完成版.mp4`,'
)

with open('src/web/app.js', 'w', encoding='utf-8') as f:
    f.write(content)
