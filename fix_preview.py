import re

with open('src/server.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Change /tmp/toho_preview.wav to a unique file
content = content.replace(
    'preview_tmp = "/tmp/toho_preview.wav"',
    'import uuid\n                preview_tmp = f"/tmp/toho_preview_{uuid.uuid4().hex}.wav"'
)

with open('src/server.py', 'w', encoding='utf-8') as f:
    f.write(content)
