#!/bin/sh
# 在 VPS 上运行：用 fork main（2.22.6）的清单文件构建新基础镜像
# 构建上下文：/data/build/base-image-2.22.6（只含清单文件 + Dockerfile，不含 node_modules）
set -e
SRC=/data/build/v1.0.2
CTX=/data/build/base-image-2.22.6
TAG=dtc-runtime:node22-pnpm10-2.22.6

echo "=== 1. 确认源版本 ==="
grep '"version"' "$SRC/apps/backend/node_modules/@medusajs/medusa/package.json" | head -1
grep -E '"@medusajs/medusa"' "$SRC/apps/backend/package.json"
cd "$SRC" && git rev-parse HEAD 2>/dev/null || echo "not a git repo (or no git)"

echo "=== 2. 准备构建上下文 ==="
rm -rf "$CTX"
mkdir -p "$CTX/apps/backend" "$CTX/apps/storefront"
cp "$SRC/package.json" "$SRC/pnpm-lock.yaml" "$SRC/pnpm-workspace.yaml" "$CTX/"
cp "$SRC/apps/backend/package.json" "$SRC/apps/backend/medusa-config.ts" "$CTX/apps/backend/"
cp "$SRC/apps/storefront/package.json" "$SRC/apps/storefront/next.config.js" "$CTX/apps/storefront/"
cp /tmp/Dockerfile.dtc-runtime-2.22.6 "$CTX/"
ls -R "$CTX"

echo "=== 3. 构建镜像 $TAG ==="
cd "$CTX"
docker build -f Dockerfile.dtc-runtime-2.22.6 -t "$TAG" --platform linux/arm64 . 2>&1 | tail -30

echo "=== 4. 验证 ==="
docker run --rm "$TAG" sh -c "node --version; pnpm --version; cat /app/apps/backend/node_modules/@medusajs/medusa/package.json | grep '\"version\"'; ls /app/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/modules/route.js && echo 'modules route EXISTS'"
docker images "$TAG" --format "{{.Repository}}:{{.Tag}} {{.Size}}"
