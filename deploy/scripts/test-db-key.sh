#!/bin/sh
# 在 VPS 上运行：用 DB 里的真实 publishable token 调 /store/regions
# 不打印完整 token，只打印状态码和前 200 字符
set -e
DBKEY=$(docker exec medusa-postgres-1 psql -U medusa -d medusa-store -t -A -c "select token from api_key where type='publishable' limit 1;" | tr -d '[:space:]')
echo "DB token prefix: $(echo "$DBKEY" | cut -c1-12) length: $(echo -n "$DBKEY" | wc -c)"
docker exec medusa-nginx-1 sh -c "wget -qO- --header=\"x-publishable-api-key: $DBKEY\" --header=\"Host: shop-admin.satank.cn\" http://127.0.0.1/store/regions" | head -c 800
echo ""
echo "--- env key test ---"
ENVKEY=$(grep NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY /data/medusa/.env.prod | cut -d= -f2)
echo "ENV token prefix: $(echo "$ENVKEY" | cut -c1-12) length: $(echo -n "$ENVKEY" | wc -c)"
docker exec medusa-nginx-1 sh -c "wget -qO- --header=\"x-publishable-api-key: $ENVKEY\" --header=\"Host: shop-admin.satank.cn\" http://127.0.0.1/store/regions" | head -c 800 || echo "ENV key -> 400 (as expected if mismatched)"
echo ""
