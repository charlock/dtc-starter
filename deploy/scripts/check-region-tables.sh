#!/bin/sh
echo "=== region-related tables ==="
docker exec medusa-postgres-1 psql -U medusa -d medusa-store -c "\dt *region*" 2>&1
docker exec medusa-postgres-1 psql -U medusa -d medusa-store -c "\dt *countr*" 2>&1
echo "=== region table columns ==="
docker exec medusa-postgres-1 psql -U medusa -d medusa-store -c "\d region" 2>&1
echo "=== region_country columns ==="
docker exec medusa-postgres-1 psql -U medusa -d medusa-store -c "\d region_country" 2>&1 || docker exec medusa-postgres-1 psql -U medusa -d medusa-store -c "select * from region_country limit 3;" 2>&1 | head -20
echo "=== existing region_country rows ==="
docker exec medusa-postgres-1 psql -U medusa -d medusa-store -c "select * from region_country;" 2>&1 | head -20
echo "=== medusa dist modules list ==="
ls /app/apps/backend/node_modules/@medusajs/medusa/dist/modules/ 2>/dev/null | head -40 || ls apps/backend/node_modules/@medusajs/medusa/dist/modules/ | head -40
echo "=== medusa binary in running server ==="
docker exec medusa-medusa_server-1 sh -c "ls /app/node_modules/.bin/medusa && /app/node_modules/.bin/medusa --version" 2>&1 | head -5
