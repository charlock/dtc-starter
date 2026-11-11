#!/bin/sh
# 在 VPS 上运行：只构建商城（后端已在上一轮构建成功）
# 关键：构建时 NEXT_PUBLIC_MEDUSA_BACKEND_URL 必须用 http://shop-admin.satank.cn，
# 因为 https 回源现在是 521，sitemap 等 prerender 页在构建时会调后端，https 会失败。
# 这和 v1.0.1 的做法一致（v1.0.1 baked 的也是 http）。
# HTTPS 修好后，需要再做一次 v1.0.3 构建，把这个值改回 https，否则浏览器会拦 mixed content。
set -e
cd /data/build/v1.0.2
echo "== 准备商城构建 env（后端 URL 临时用 http） =="
grep -v "^NEXT_PUBLIC_MEDUSA_BACKEND_URL=" /data/medusa/.env.prod > /tmp/storefront-build.env
echo "NEXT_PUBLIC_MEDUSA_BACKEND_URL=http://shop-admin.satank.cn" >> /tmp/storefront-build.env
echo "NEXT_PUBLIC_BASE_URL=https://shop.satank.cn" >> /tmp/storefront-build.env
grep -E "NEXT_PUBLIC" /tmp/storefront-build.env | cut -c1-60
echo "== 构建商城 =="
docker run --rm -v /data/build/v1.0.2:/app -w /app --network medusa_medusa_network --env-file /tmp/storefront-build.env -e NODE_ENV=production dtc-runtime:node22-pnpm10 sh -c "pnpm --filter @dtc/storefront build" 2>&1 | tail -80
echo "== 检查构建产物 =="
ls apps/storefront/.next/standalone/ | head -20
ls apps/storefront/.next/standalone/.next/BUILD_ID 2>/dev/null && cat apps/storefront/.next/standalone/.next/BUILD_ID; echo
echo "新 key 是否 baked 进 middleware："
grep -a -o "pk_22b9a1c74[a-z0-9]*" apps/storefront/.next/server/src/middleware.js | head -2 || echo "WARN: 新 key 未找到"
echo "后端 URL 是否 baked 为 http："
grep -a -o "http://shop-admin.satank.cn" apps/storefront/.next/server/src/middleware.js | head -2 || echo "WARN: http backend URL 未找到"
echo "== 打包 release v1.0.2 =="
rm -rf /data/medusa/releases/v1.0.2
mkdir -p /data/medusa/releases/v1.0.2/backend-server /data/medusa/releases/v1.0.2/backend-config /data/medusa/releases/v1.0.2/storefront
cp -r apps/backend/.medusa/server/. /data/medusa/releases/v1.0.2/backend-server/
cp apps/backend/medusa-config.ts /data/medusa/releases/v1.0.2/backend-config/medusa-config.ts
cp -r apps/storefront/.next/standalone/. /data/medusa/releases/v1.0.2/storefront/standalone/
# 必须把 .next/static 也复制进来：standalone 里不含 static，不复制则所有
# /_next/static/chunks/* 都是 404，页面无样式、无 JS（2026-11-11 实测踩坑）。
cp -r apps/storefront/.next/static /data/medusa/releases/v1.0.2/storefront/standalone/apps/storefront/.next/static
echo "dtc-runtime:node22-pnpm10" > /data/medusa/releases/v1.0.2/base-image.txt
echo "linux/arm64" > /data/medusa/releases/v1.0.2/target-platform.txt
find /data/medusa/releases/v1.0.2 -maxdepth 2 | sort | head -40
du -sh /data/medusa/releases/v1.0.2
echo "打包完成，下一步：bash deploy-remote.sh v1.0.2"
