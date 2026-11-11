#!/bin/sh
echo "=== 1. 镜像里后端实际用的 medusa 版本 ==="
docker run --rm dtc-runtime:node22-pnpm10 sh -c "cat /app/apps/backend/node_modules/@medusajs/medusa/package.json 2>/dev/null | grep '\"version\"'; ls /app/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/ 2>/dev/null | wc -l; ls /app/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/modules 2>/dev/null || echo 'NO modules route in image (2.21.2)'" 2>&1
echo "=== 2. 运行中容器里后端实际用的 medusa 版本 ==="
docker exec medusa-medusa_server-1 sh -c "cat /app/apps/backend/node_modules/@medusajs/medusa/package.json 2>/dev/null | grep '\"version\"'; ls /app/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/modules 2>/dev/null || echo 'NO modules route in running server'" 2>&1
echo "=== 3. 2.22.6 的 /admin/modules 路由是干什么的 ==="
cat /data/build/v1.0.2/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/modules/route.js 2>&1 | head -60
echo "=== 4. 前端哪里调 /admin/modules（admin 包） ==="
grep -rln "admin/modules" /data/build/v1.0.2/apps/backend/node_modules/@medusajs/admin-shared/dist/ /data/build/v1.0.2/apps/backend/node_modules/@medusajs/admin-sdk/dist/ 2>/dev/null | head -5
grep -rn "modules" /data/build/v1.0.2/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/modules/route.d.ts 2>/dev/null | head -5
echo "=== 5. v1.0.1 release 的后端版本（对照） ==="
grep -E '"@medusajs/medusa"' /data/medusa/releases/v1.0.1/backend-server/package.json 2>/dev/null; grep -E '"@medusajs/admin-sdk"' /data/medusa/releases/v1.0.1/backend-server/package.json 2>/dev/null
echo "=== 6. v1.0.1 的 backend-server 里有没有 modules 路由 ==="
ls /data/medusa/releases/v1.0.1/backend-server/ 2>/dev/null | head; find /data/medusa/releases/v1.0.1 -name "route.js" -path "*admin/modules*" 2>/dev/null | head -3
echo "=== 7. 404 响应体 ==="
docker exec medusa-nginx-1 sh -c "wget -qO- http://medusa_server:9000/admin/modules 2>&1 | head -c 300; echo" 2>&1 || docker exec medusa-medusa_server-1 sh -c "wget -qO- http://localhost:9000/admin/modules 2>&1 | head -c 300; echo" 2>&1
