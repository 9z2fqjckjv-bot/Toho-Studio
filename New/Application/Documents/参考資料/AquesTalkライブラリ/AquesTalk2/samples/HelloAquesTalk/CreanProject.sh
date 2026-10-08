#!/bin/bash

# xcodeの不要ファイルを削除
# myProject.xcodeprojのフォルダにコピーして
# $ ./CleanProject.sh

find . -name '*.xcuserstate' -delete
find . -name 'xcuserdata' -type d -exec rm -rf {} +
find . -name '.DS_Store' -delete

echo "✅ プロジェクト:${DIST_DIR} 不要ファイル削除完了"
