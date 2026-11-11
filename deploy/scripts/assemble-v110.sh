#!/bin/sh
# 在 VPS 上运行：组装 v1.1.0 发布包（后端 2.22.6 + 商城 v1.0.3）
# backend-server / backend-config 复用 v1.0.2（已是 2.22.6 构建产物）
# storefront 复用 v1.0.3（https 后端 URL，key 已修正）
# base-image 换成新镜像 dtc-runtime:node22-pnpm10-2.22.6
set -e
R=/data/medusa/releases
V=v1.1.0
IMG=dtc-runtime:node22-pnpm10-2.22.6

echo "=== 1. 前置检查 ==="
docker image inspect "$IMG" --format '{{.Os}}/{{.Architecture}} {{.Id}}' 2>&1
test -d "$R/v1.0.2/backend-server" || { echo "缺 v1.0.2 backend-server"; exit 1; }
test -d "$R/v1.0.3/storefront" || { echo "缺 v1.0.3 storefront"; exit 1; }

echo "=== 2. 组装 $V ==="
rm -rf "$R/$V"
mkdir -p "$R/$V"
cp -a "$R/v1.0.2/backend-server" "$R/$V/backend-server"
cp -a "$R/v1.0.2/backend-config" "$R/$V/backend-config"
cp -a "$R/v1.0.3/storefront" "$R/$V/storefront"
echo -n "$IMG" > "$R/$V/base-image.txt"
echo -n "linux/arm64" > "$R/$V/target-platform.txt"

echo "=== 3. 校验 ==="
ls "$R/$V"
grep '"@medusajs/medusa"' "$R/$V/backend-server/package.json"
grep -c "event-bus-redis" "$R/$V/backend-config/medusa-config.ts"
ls "$R/$V/storefront/standalone/apps/storefront/server.js" && echo "storefront server.js OK"
cat "$R/$V/base-image.txt"; echo
cat "$R/$V/target-platform.txt"; echo
du -sh "$R/$V"
