#!/usr/bin/env bash
# 一次改好 versionName + versionCode，避免两者不同步导致覆盖安装失败。
#
# 用法:
#   scripts/bump-version.sh 3.3.1-2      # 开发迭代（带 -N 后缀）
#   scripts/bump-version.sh 3.3.2        # 正式版（无后缀）
#
# versionCode 规则: yyyyMMdd + 两位当日序号（01 起）
#   - 同一天多次递增，序号 +1
#   - 换天后序号从 01 重新开始
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "用法: $0 <versionName>   例: $0 3.3.1-2 或 $0 3.3.2" >&2
  exit 1
fi

NEW_VERSION="$1"
if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9]+)?$ ]]; then
  echo "版本号格式错误: $NEW_VERSION" >&2
  echo "期望: X.Y.Z 或 X.Y.Z-N（如 3.3.1、3.3.1-2）" >&2
  exit 1
fi

GRADLE_FILE="$(cd "$(dirname "$0")/.." && pwd)/app/build.gradle.kts"
TODAY="$(date +%Y%m%d)"
CUR_CODE="$(grep -oP 'versionCode\s*=\s*\K[0-9]+' "$GRADLE_FILE" | head -1)"
CUR_DATE="${CUR_CODE:0:8}"
CUR_SEQ="${CUR_CODE:8:2}"

if [[ "$CUR_DATE" == "$TODAY" ]]; then
  NEW_SEQ="$(printf '%02d' $((10#$CUR_SEQ + 1)))"
else
  NEW_SEQ="01"
fi
NEW_CODE="${TODAY}${NEW_SEQ}"

# 用 Python 做替换，保证只改目标行且保留文件其余内容
python3 - "$GRADLE_FILE" "$NEW_CODE" "$NEW_VERSION" <<'PYEOF'
import re, sys
path, code, name = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
src = re.sub(r'versionCode\s*=\s*\d+', 'versionCode = %s' % code, src, count=1)
src = re.sub(r'versionName\s*=\s*"[^"]*"', 'versionName = "%s"' % name, src, count=1)
open(path, 'w').write(src)
PYEOF

echo "版本已更新:"
echo "  versionName = $NEW_VERSION"
echo "  versionCode = $NEW_CODE  (原 $CUR_CODE)"
