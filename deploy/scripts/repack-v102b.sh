#!/bin/sh
# 修正打包：不用展平，保留 Next 16 原生 standalone 布局
# .next/standalone/apps/storefront/server.js + node_modules/next 软链是成套的，展平会断链。
# 改动 docker-compose.prod.yml 的 storefront 启动命令和缓存挂载点来适配新布局，
# v1.0.1 回滚时要把 compose 也改回去（下面会备份 compose）。
set -e
SRC=/data/build/v1.0.2/apps/storefront/.next/standalone
DST=/data/medusa/releases/v1.0.2/storefront/standalone
echo "== 重新打包 storefront（原生布局） =="
rm -rf "$DST"
mkdir -p "$DST"
cp -a "$SRC/." "$DST/"
# 必须把 .next/static 也复制进来：standalone 里不含 static，不复制则所有
# /_next/static/chunks/* 都是 404，页面无样式、无 JS（2026-11-11 实测踩坑）。
cp -a /data/build/v1.0.2/apps/storefront/.next/static "$DST/apps/storefront/.next/static"
mkdir -p "$DST/apps/storefront/public"
cp -a /data/build/v1.0.2/apps/storefront/public/. "$DST/apps/storefront/public/"
echo "server.js:"; ls -lh "$DST/apps/storefront/server.js"
echo "next 软链："; ls -l "$DST/apps/storefront/node_modules/next"
echo "新 key："; grep -r -a -l "pk_22b9a1c74" "$DST/apps/storefront/.next/" 2>/dev/null | head -5
echo "== 备份并更新 docker-compose.prod.yml =="
cp /data/medusa/docker-compose.prod.yml /data/medusa/docker-compose.prod.yml.backup.pre-v1.0.2
python3 <<'PY'
import pathlib
p = pathlib.Path("/data/medusa/docker-compose.prod.yml")
t = p.read_text()
old_cmd = 'command: ["node", "/app/apps/storefront/runtime/server.js"]'
new_cmd = 'command: ["node", "/app/apps/storefront/runtime/apps/storefront/server.js"]'
assert old_cmd in t, "storefront command not found in compose"
t = t.replace(old_cmd, new_cmd)
old_cache = "- storefront_cache:/app/apps/storefront/runtime/.next/cache"
new_cache = "- storefront_cache:/app/apps/storefront/runtime/apps/storefront/.next/cache"
assert old_cache in t, "storefront cache mount not found in compose"
t = t.replace(old_cache, new_cache)
p.write_text(t)
print("compose updated")
PY
grep -A2 -B2 "storefront" /data/medusa/docker-compose.prod.yml | grep -E "command|storefront_cache|server.js" | head -10
du -sh /data/medusa/releases/v1.0.2
echo "完成，下一步：bash deploy-remote.sh v1.0.2"
