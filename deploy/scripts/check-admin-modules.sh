#!/bin/sh
# 检查 /admin/modules 404 是否是后端 2.21.2 与前端 2.22.6 版本不一致导致的
echo "=== 1. server 容器里的 medusa 版本 ==="
docker exec medusa-medusa_server-1 sh -c "cat /app/apps/backend/.medusa/server/package.json 2>/dev/null | grep -E '\"@medusajs/medusa\"|\"version\"' | head -5; echo ---; ls /app/ | head -20; echo ---; ls /app/node_modules/@medusajs/ 2>/dev/null | head; cat /app/node_modules/@medusajs/medusa/package.json 2>/dev/null | grep '\"version\"' | head -1" 2>&1
echo "=== 2. 镜像 dtc-runtime 里 medusa 版本 ==="
docker run --rm dtc-runtime:node22-pnpm10 sh -c "cat /app/node_modules/@medusajs/medusa/package.json 2>/dev/null | grep '\"version\"'; ls /app/node_modules/@medusajs/medusa/dist/api/admin/ 2>/dev/null | head -40" 2>&1
echo "=== 3. 构建目录（2.22.6）里 admin API 有没有 modules 路由 ==="
ls /data/build/v1.0.2/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/ 2>/dev/null | head -40
echo "--- 2.22.6 里搜 modules 路由 ---"
grep -rln "modules" /data/build/v1.0.2/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/ 2>/dev/null | head -10
grep -rn "admin/modules" /data/build/v1.0.2/apps/backend/node_modules/@medusajs/medusa/dist/api/admin/ 2>/dev/null | head -5
echo "=== 4. 镜像（2.21.2）里搜 modules 路由 ==="
docker run --rm dtc-runtime:node22-pnpm10 sh -c "ls /app/node_modules/@medusajs/medusa/dist/api/admin/ | head -40; echo ---; grep -rln modules /app/node_modules/@medusajs/medusa/dist/api/admin/ 2>/dev/null | head" 2>&1
echo "=== 5. 直接调后端 /admin/modules（绕过 Cloudflare） ==="
curl -s -o /dev/null -w "no-auth: %{http_code}\n" http://localhost:9000/admin/modules 2>&1
curl -s http://localhost:9000/admin/modules 2>&1 | head -c 500; echo
echo "=== 6. 后端日志里 /admin/modules 的 404 ==="
docker logs medusa-medusa_server-1 --since 30m 2>&1 | grep -i "modules" | tail -5
echo "=== 7. Admin 前端包版本（.medusa/server 里） ==="
docker exec medusa-medusa_server-1 sh -c "ls /app/apps/backend/.medusa/server/ | head; cat /app/apps/backend/.medusa/server/package.json 2>/dev/null | grep -E 'medusa|admin' | head" 2>&1
