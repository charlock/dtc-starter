#!/bin/sh
echo "=== baked backend URL in v1.0.1 middleware ==="
grep -a -o "shop-admin[^\"' ]*" /data/medusa/releases/v1.0.1/storefront/standalone/.next/server/src/middleware.js | head -5
grep -a -o "https://[^\"' ]*satank[^\"' ]*" /data/medusa/releases/v1.0.1/storefront/standalone/.next/server/src/middleware.js | head -5
grep -a -o "http://[^\"' ]*satank[^\"' ]*" /data/medusa/releases/v1.0.1/storefront/standalone/.next/server/src/middleware.js | head -5
echo "=== baked base URL ==="
grep -a -o "shop\.satank[^\"' ]*" /data/medusa/releases/v1.0.1/storefront/standalone/.next/server/src/middleware.js | head -5
echo "=== any medusa_server internal URL baked? ==="
grep -a -c "medusa_server" /data/medusa/releases/v1.0.1/storefront/standalone/.next/server/src/middleware.js || true
grep -a -o "localhost:9000" /data/medusa/releases/v1.0.1/storefront/standalone/.next/server/src/middleware.js | head -3 || echo "no localhost"
echo "=== check .env.prod backend URL ==="
grep NEXT_PUBLIC_MEDUSA_BACKEND_URL /data/medusa/.env.prod
grep NEXT_PUBLIC_BASE_URL /data/medusa/.env.prod
