#!/bin/sh
# Postgres 每日备份 —— 放到 VPS 的 cron 里，每天凌晨跑一次
# 0 3 * * * /data/medusa/scripts/backup.sh >> /var/log/dtc-backup.log 2>&1
# 注意：这个脚本不提交备份文件本身，备份只在 VPS 本地 /data/backup，
# 定期把它同步到 VPS 外（R2 / 另一台机器），否则 VPS 丢了备份也没用。
set -e
BACKUP_DIR=/data/backup
mkdir -p "$BACKUP_DIR"
DATE=$(date +%F-%H%M)
docker exec medusa-postgres-1 pg_dump -U medusa -d medusa-store | gzip > "$BACKUP_DIR/medusa-store-$DATE.sql.gz"
# 只留最近 7 天
find "$BACKUP_DIR" -name "medusa-store-*.sql.gz" -mtime +7 -delete
echo "$DATE 备份完成：$BACKUP_DIR/medusa-store-$DATE.sql.gz"
