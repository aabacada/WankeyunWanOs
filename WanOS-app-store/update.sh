#!/bin/sh
# 重新拉取官方应用目录 API，更新 app-store-api-*.json。
# 注意：apps.json 的合并逻辑（API + 设备导出 upload.md）在生成它的 Python 步骤里，
# 本脚本只做拉取和备份，合并后请按 README 的说明重新生成 apps.json 并核对总数应为 81。
set -eu
cd "$(dirname "$0")"
DATE="$(date +%Y%m%d)"
API_URL="https://wxqun988.vxjuejin.com/wanos/api/app-store"
echo "fetch $API_URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL --max-time 60 "$API_URL" -o "app-store-api-$DATE.json"
else
  wget -qO "app-store-api-$DATE.json" "$API_URL"
fi
python3 -c "import json; d=json.load(open('app-store-api-$DATE.json')); print('apps:', len(d['apps']), 'updated_at:', d.get('updated_at'))"
echo "saved app-store-api-$DATE.json; now regenerate apps.json from it + upload.md and verify total=78"
