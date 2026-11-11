#!/bin/sh
# 在 VPS 上运行：备份 DB + 修正 .env.prod 的 publishable key + 克隆 fork
# 不打印任何密钥完整值
set -e
mkdir -p /data/backup /data/build
echo "== 1. 备份数据库 =="
docker exec medusa-postgres-1 pg_dump -U medusa -d medusa-store | gzip > /data/backup/medusa-store-v1.0.1-pre-v1.0.2-$(date +%F-%H%M).sql.gz
ls -lh /data/backup/ | tail -5
echo "== 2. 备份 .env.prod =="
cp /data/medusa/.env.prod /data/medusa/.env.prod.backup.pre-v1.0.2
echo "== 3. 把 .env.prod 里的 publishable key 修正为 DB 里的真 key =="
DBKEY=$(docker exec medusa-postgres-1 psql -U medusa -d medusa-store -t -A -c "select token from api_key where type='publishable' limit 1;" | tr -d '[:space:]')
echo "DB key prefix: $(echo "$DBKEY" | cut -c1-12) length: $(echo -n "$DBKEY" | wc -c)"
# 用临时文件替换，避免在命令行历史里留下完整 key
python3 - "$DBKEY" <<'PY'
import sys, pathlib
key = sys.argv[1]
p = pathlib.Path("/data/medusa/.env.prod")
lines = []
for line in p.read_text().splitlines():
    if line.startswith("NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY="):
        lines.append("NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=" + key)
    else:
        lines.append(line)
p.write_text("\n".join(lines) + "\n")
print("env key updated, prefix:", key[:12])
PY
unset DBKEY
grep NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY /data/medusa/.env.prod | cut -c1-45
echo "== 4. 克隆 fork =="
rm -rf /data/build/v1.0.2
git clone --depth 1 https://github.com/charlock/dtc-starter.git /data/build/v1.0.2
cd /data/build/v1.0.2 && git log --oneline -1 && git rev-parse HEAD
echo "== 5. 测试 npm registry 连通 =="
docker run --rm dtc-runtime:node22-pnpm10 sh -c "node -e \"fetch('https://registry.npmjs.org/@medusajs/medusa').then(r=>console.log('npm registry', r.status)).catch(e=>console.log('npm FAIL', e.message))\""
echo "准备完成"
