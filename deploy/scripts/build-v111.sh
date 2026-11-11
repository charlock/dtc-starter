#!/bin/sh
# 在 VPS 上运行：为 v1.1.1 重新构建后端 + 商城（搜索索引加 CNY）
# 改动：fork 分支 satank/cny-search-index（提交 3bfb7d9e）
#   - apps/backend/src/search/helpers/pricing.ts：PRICE_CURRENCIES 加 "cny"
#   - apps/storefront/src/lib/search-client.ts：SEARCH_PRICE_CURRENCIES 加 "cny"
# 不加 cny 时，/cn/store 的列表页（InstantSearch 索引）会回退到 EUR 显示 €10，
# 而商品页/购物车/结算页（走实时 API）已是 CN¥100。加 cny 后索引在下次启动时
# 按新 schema 重建，列表页即可显示 ¥100。
# 失败就停，不要继续部署。基镜像用 2.22.6（dtc-runtime:node22-pnpm10-2.22.6）。
set -e
cd /data/build/v1.0.2
IMG=dtc-runtime:node22-pnpm10-2.22.6
echo "== 0. 确认源码分支和改动 =="
git log --oneline -1
grep -n "PRICE_CURRENCIES =" apps/backend/src/search/helpers/pricing.ts
grep -n "SEARCH_PRICE_CURRENCIES =" apps/storefront/src/lib/search-client.ts
echo "== 1. 构建后端 =="
docker run --rm -v /data/build/v1.0.2:/app -w /app --network medusa_medusa_network --env-file /data/medusa/.env.prod -e NODE_ENV=production -e MEDUSA_WORKER_MODE=server $IMG sh -c "pnpm --filter @dtc/backend build" 2>&1 | tail -40
echo "后端构建完成，检查 .medusa/server："
ls apps/backend/.medusa/server/ | head -10
grep '"@medusajs/medusa"' apps/backend/.medusa/server/package.json
grep -n "cny" apps/backend/.medusa/server/src/search/helpers/pricing.js 2>/dev/null | head -3 || echo "NOTE: 编译产物里未直接找到 cny（可能被打包进 chunk，部署后以索引行为为准）"
echo "== 2. 准备商城构建 env（后端 URL 用 https） =="
grep -v "^NEXT_PUBLIC_MEDUSA_BACKEND_URL=" /data/medusa/.env.prod > /tmp/storefront-build-v111.env
echo "NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://shop-admin.satank.cn" >> /tmp/storefront-build-v111.env
grep -E "NEXT_PUBLIC" /tmp/storefront-build-v111.env | cut -c1-60
echo "== 3. 构建商城 =="
docker run --rm -v /data/build/v1.0.2:/app -w /app --network medusa_medusa_network --env-file /tmp/storefront-build-v111.env -e NODE_ENV=production $IMG sh -c "pnpm --filter @dtc/storefront build" 2>&1 | tail -40
echo "商城构建完成，检查 standalone："
ls apps/storefront/.next/standalone/apps/storefront/server.js && echo "server.js OK"
grep -r -o "pk_22b9a1c74[a-z0-9]*" apps/storefront/.next/server/src/middleware.js 2>/dev/null | head -1 || echo "WARN: 新 key 未在 middleware.js 里找到"
echo "== 4. 打包 release v1.1.1（后端配置沿用 v1.1.0 生产版） =="
R=/data/medusa/releases
rm -rf $R/v1.1.1
mkdir -p $R/v1.1.1/backend-server $R/v1.1.1/backend-config $R/v1.1.1/storefront
cp -r apps/backend/.medusa/server/. $R/v1.1.1/backend-server/
cp -a $R/v1.1.0/backend-config/. $R/v1.1.1/backend-config/
cp -a apps/storefront/.next/standalone/. $R/v1.1.1/storefront/standalone/
# 必须带 .next/static：standalone 里不含它，漏了则所有 /_next/static/chunks/* 404
cp -a apps/storefront/.next/static $R/v1.1.1/storefront/standalone/apps/storefront/.next/static
mkdir -p $R/v1.1.1/storefront/standalone/apps/storefront/public
cp -a apps/storefront/public/. $R/v1.1.1/storefront/standalone/apps/storefront/public/
mkdir -p $R/v1.1.1/storefront/standalone/apps/storefront/.next/cache
mkdir -p $R/v1.1.1/storefront/standalone/apps/storefront/.next/server/route-cache
echo -n "$IMG" > $R/v1.1.1/base-image.txt
echo -n "linux/arm64" > $R/v1.1.1/target-platform.txt
echo "release v1.1.1 打包完成："
ls $R/v1.1.1
ls $R/v1.1.1/storefront/standalone/apps/storefront/.next/static/chunks | wc -l
du -sh $R/v1.1.1
echo "下一步：先备份 DB，再跑 bash deploy-remote.sh v1.1.1"
