#!/bin/sh
# 在 VPS 上运行：只重建商城 v1.0.3，后端沿用 v1.0.2 的产物
# 改动：NEXT_PUBLIC_MEDUSA_BACKEND_URL 改回 https（HTTPS 已通，http 会被浏览器拦 mixed content）
# 另外修 route-cache：预创建 .next/server/route-cache 目录，并加一个 volume 挂载（见 compose 修改）
set -e
cd /data/build/v1.0.2
echo "== 准备商城构建 env（后端 URL 用 https） =="
grep -v "^NEXT_PUBLIC_MEDUSA_BACKEND_URL=" /data/medusa/.env.prod > /tmp/storefront-build-v103.env
echo "NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://shop-admin.satank.cn" >> /tmp/storefront-build-v103.env
grep -E "NEXT_PUBLIC" /tmp/storefront-build-v103.env | cut -c1-60
echo "== 构建商城 =="
docker run --rm -v /data/build/v1.0.2:/app -w /app --network medusa_medusa_network --env-file /tmp/storefront-build-v103.env -e NODE_ENV=production dtc-runtime:node22-pnpm10 sh -c "pnpm --filter @dtc/storefront build" 2>&1 | tail -30
echo "== 打包 release v1.0.3（后端复制 v1.0.2，商城用新构建） =="
rm -rf /data/medusa/releases/v1.0.3
mkdir -p /data/medusa/releases/v1.0.3/backend-server /data/medusa/releases/v1.0.3/backend-config /data/medusa/releases/v1.0.3/storefront
cp -a /data/medusa/releases/v1.0.2/backend-server/. /data/medusa/releases/v1.0.3/backend-server/
cp -a /data/medusa/releases/v1.0.2/backend-config/. /data/medusa/releases/v1.0.3/backend-config/
cp -a apps/storefront/.next/standalone/. /data/medusa/releases/v1.0.3/storefront/standalone/
mkdir -p /data/medusa/releases/v1.0.3/storefront/standalone/apps/storefront/public
cp -a /data/build/v1.0.2/apps/storefront/public/. /data/medusa/releases/v1.0.3/storefront/standalone/apps/storefront/public/
mkdir -p /data/medusa/releases/v1.0.3/storefront/standalone/apps/storefront/.next/cache
mkdir -p /data/medusa/releases/v1.0.3/storefront/standalone/apps/storefront/.next/server/route-cache
echo "dtc-runtime:node22-pnpm10" > /data/medusa/releases/v1.0.3/base-image.txt
echo "linux/arm64" > /data/medusa/releases/v1.0.3/target-platform.txt
echo "新 key baked："
grep -r -a -l "pk_22b9a1c74" /data/medusa/releases/v1.0.3/storefront/standalone/apps/storefront/.next/ 2>/dev/null | head -3
echo "https 后端 URL baked："
grep -r -a -o "https://shop-admin.satank.cn" /data/medusa/releases/v1.0.3/storefront/standalone/apps/storefront/.next/server/chunks/*.js 2>/dev/null | sort | uniq -c | head -3
echo "http 后端 URL 不应出现："
grep -r -a -l "http://shop-admin.satank.cn" /data/medusa/releases/v1.0.3/storefront/standalone/apps/storefront/.next/ 2>/dev/null | head -3 || echo "http URL 未出现，好"
du -sh /data/medusa/releases/v1.0.3
echo "== 给 route-cache 加 volume（compose） =="
python3 <<'PY'
import pathlib
p = pathlib.Path("/data/medusa/docker-compose.prod.yml")
t = p.read_text()
if "storefront_route_cache" not in t:
    t = t.replace(
        "      - storefront_cache:/app/apps/storefront/runtime/apps/storefront/.next/cache\n",
        "      - storefront_cache:/app/apps/storefront/runtime/apps/storefront/.next/cache\n      - storefront_route_cache:/app/apps/storefront/runtime/apps/storefront/.next/server/route-cache\n",
        1,
    )
    t = t.replace(
        "  storefront_cache:\n",
        "  storefront_cache:\n  storefront_route_cache:\n",
        1,
    )
    p.write_text(t)
    print("compose route-cache volume added")
else:
    print("compose already has route-cache volume")
PY
echo "完成，下一步：bash deploy-remote.sh v1.0.3"
