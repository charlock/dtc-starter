#!/bin/sh
# 在 VPS 上运行：装好 Origin 证书后更新 Nginx 模板 + compose，reload Nginx
# 用法：先把 origin.pem 和 origin.key 放到 /tmp/origin.pem /tmp/origin.key，再跑这个脚本
# 证书文件由主人在 Cloudflare 后台生成，只放这两个文件，不打印私钥内容
set -e
cd /data/medusa
test -f /tmp/origin.pem || { echo "缺少 /tmp/origin.pem"; exit 1; }
test -f /tmp/origin.key || { echo "缺少 /tmp/origin.key"; exit 1; }
echo "== 备份现有 Nginx 配置 =="
cp nginx/default.conf.template nginx/default.conf.template.backup.pre-v1.0.3
cp docker-compose.prod.yml docker-compose.prod.yml.backup.pre-v1.0.3
echo "== 安装证书（权限 600，只 root 可读） =="
mkdir -p nginx/certs
cp /tmp/origin.pem nginx/certs/origin.pem
cp /tmp/origin.key nginx/certs/origin.key
chmod 600 nginx/certs/origin.key
chmod 644 nginx/certs/origin.pem
rm -f /tmp/origin.pem /tmp/origin.key
echo "== 更新 Nginx 模板（模板文件由小伍从本地传过来，放在 /tmp/default.conf.template） =="
cp /tmp/default.conf.template nginx/default.conf.template
echo "== 更新 compose：加 443 端口和证书挂载 =="
python3 <<'PY'
import pathlib
p = pathlib.Path("docker-compose.prod.yml")
t = p.read_text()
if "443:443" not in t:
    t = t.replace(
        '      - "${HTTP_PORT:-80}:80"',
        '      - "${HTTP_PORT:-80}:80"\n      - "${HTTPS_PORT:-443}:443"',
        1,
    )
if "nginx/certs" not in t:
    t = t.replace(
        "      - ./nginx/default.conf.template:/etc/nginx/templates/default.conf.template:ro",
        "      - ./nginx/default.conf.template:/etc/nginx/templates/default.conf.template:ro\n      - ./nginx/certs:/etc/nginx/certs:ro",
        1,
    )
p.write_text(t)
print("compose updated")
PY
echo "== 重启 Nginx 并验证 =="
# 注意：compose 里的 medusa_server/worker/storefront 需要 VERSION/BASE_IMAGE，
# 直接 docker compose up 会报 required variable missing。
# 所以这里用现有的 deploy-remote.sh（它会从最新 release 的 txt 文件里读这两个变量），
# VERSION 参数传当前在跑的版本；如果要顺便升级到新版本，传新版本号。
VERSION="${VERSION:-v1.0.3}"
bash deploy-remote.sh "$VERSION"
echo "Nginx 443 已就绪，下一步：重建商城（后端 URL 改回 https），否则浏览器会拦 mixed content"
