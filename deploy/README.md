# satank.cn — Medusa 独立站部署（生产实况，2026-11-11）

域名：商城 `https://shop.satank.cn`，后台 `https://shop-admin.satank.cn`
（后台 = Medusa API + Admin 面板，Admin 在 `https://shop-admin.satank.cn/app`）
VPS：Oracle Cloud 新加坡，`168.107.91.111`，3 CPU / 19G / 150G，Ubuntu 24.04.5 LTS，ARM64
代码：fork `https://github.com/charlock/dtc-starter`，main 在 `6440e85`（Medusa 2.22.6 / Next 16.3.8）
镜像：`nginx:1.30-alpine`、`postgres:16-alpine`、`redis:8-alpine`、
基础镜像 `dtc-runtime:node22-pnpm10-2.22.6`（基于 `node:22.23.3-alpine`，见 `docker/`）

## 现状（2026-11-11，v1.1.0 已部署，实测）

- 商城、前台、后台、`https://` 全部 200。HTTPS 521 已修好（Origin 证书 + Nginx 443）。
- 地区：Europe / EUR、United States / USD、China / CNY 三个，`/us/store` 和
  `/cn/store` 都是 200。注意：中国区商品还没有 CNY 价格（只有 EUR 和 USD
  价格），中国区要能下单得先给商品加 CNY 价格。
- 后端已是 **Medusa 2.22.6**（v1.1.0）：基础镜像按 fork main 的 lockfile 重建
  （`docker/Dockerfile.dtc-runtime-2.22.6`），发布时 `medusa db:migrate` 自动跑了
  2 个新迁移（迁移记录 188 → 190）。之前 2.21.2 后端 + 2.22.6 前端不一致导致的
  `GET /admin/modules` 404 已消失。旧镜像 `dtc-runtime:node22-pnpm10`（2.21.2）
  还在 VPS 上，回滚可用，但回滚会带回那个 404。
- Redis 已接好：event-bus-redis、workflow-engine-redis、locking-redis 都已连接，
  没有 Local Event Bus / in-memory locking 警告。Cache 模块还没开（需要
  `MEDUSA_FF_CACHING=true` + compose 里加环境变量，下个版本再开）。
- 支付先不上，只跑商品和下单流程；文件存储先用本地卷，R2 第二阶段再填。

## 生产系统长什么样（和早期 /opt 方案不同）

生产在 VPS 的 `/data/medusa/`，不是 `/opt/dtc-deploy`（那个方案没上过生产，
不要跑它，会抢 80 端口、另起一个空数据库）：

```
/data/medusa/
  docker-compose.prod.yml   # 6 个服务，见下
  deploy-remote.sh          # 发布脚本：校验 release 完整性 -> up -d -> nginx -t/reload
  .env.prod                 # 真实密钥，只在 VPS 上，绝不提交
  nginx/default.conf.template  # Nginx 模板（80 + 443，Origin 证书）
  nginx/certs/              # origin.pem / origin.key，只在 VPS 上，绝不提交
  releases/v1.0.1/          # 旧版本（Medusa 2.21.2 / Next 15.5.24）
  releases/v1.0.2/          # 商城重建（2.22.6 / Next 16.3.8，key 已修正，http 后端 URL）
  releases/v1.0.3/          # 同 v1.0.2 后端，商城改回 https 后端 URL
  releases/v1.1.0/          # 当前版本：后端真升到 2.22.6（新基础镜像），商城同 v1.0.3
  releases/<version>/
    backend-server/         # medusa build 产物（.medusa/server）
    backend-config/medusa-config.ts
    storefront/standalone/  # Next standalone 产物（Next 16 布局见下）
    base-image.txt          # dtc-runtime:node22-pnpm10-2.22.6
    target-platform.txt     # linux/arm64
```

每个 release 都是版本化的构建产物，`deploy-remote.sh <version>` 只替换产物，
不重新打镜像、不动数据库。回滚就是再跑一次旧版本号。

## Next 16 的坑（v1.0.2 构建时踩到的）

1. 商城构建时 `NEXT_PUBLIC_MEDUSA_BACKEND_URL` 必须能连通后端，
   否则 sitemap 等预渲染页在构建时调后端失败，`next build` 直接退出。
   HTTPS 没通的时候用 `http://shop-admin.satank.cn` 构建（v1.0.1 也是这么做的），
   HTTPS 通了以后必须重建一版改回 `https`，否则浏览器拦 mixed content。
2. Next 16 的 standalone 布局变了：`server.js` 在
   `standalone/apps/storefront/server.js`，不是 `standalone/server.js`，
   `node_modules/next` 是软链，展平会断链。所以发布包保留原生布局，
   `docker-compose.prod.yml` 的 storefront 启动命令和缓存挂载点也跟着改了。
   `deploy-remote.sh` 的完整性检查已同时接受两种布局。
3. `.next/cache` 和 `.next/server/route-cache` 目录必须在发布包里预创建，
   否则 Docker 在只读挂载里建挂载点会失败（`read-only file system`）。
   route-cache 另外挂了一个 volume，见 compose。
4. `NEXT_PUBLIC_*` 是构建时 baked 进去的，改了必须重建商城，不是重启容器。
5. standalone 里**不含 `.next/static`**：打包时必须手动把 `.next/static` 复制到
   `standalone/apps/storefront/.next/static`（public 同理）。漏了这一步，
   页面 HTML 是 200，但所有 `/_next/static/chunks/*` 都是 404，页面无样式、无 JS。
   2026-11-11 实测：v1.0.2/v1.0.3 的发布包都漏了 static，首页一直是裸 HTML，
   补上 2.8M 的 static 并重启商城后才恢复。注意这不是缓存问题，不要只清缓存。

## 文件清单

```
docker-compose.prod.yml      # 生产 compose（已脱敏，密钥都是 <CHANGE_ME>）
deploy-remote.sh             # 发布脚本
nginx/default.conf.template  # 80 + 443，Origin 证书
nginx/certs/README.md        # 证书放这里，不提交
backend/medusa-config.ts     # 生产版配置（Redis event/workflow/locking + file-s3 门控）
env/.env.prod.example        # .env.prod 模板
docker/
  Dockerfile.dtc-runtime-2.22.6  # 基础镜像 Dockerfile（2.22.6，见下）
scripts/
  prepare-v102.sh            # 备份 DB、修正 .env.prod 的 publishable key、克隆 fork
  build-storefront-v102.sh   # 商城构建（http 后端 URL，HTTPS 没通时用）
  build-storefront-v103.sh   # 商城构建（https 后端 URL）+ 打包 release
  repack-v102b.sh            # Next 16 standalone 保留原生布局的打包（已并入 v103 脚本）
  install-origin-cert.sh     # 装 Origin 证书、更新 Nginx/compose、跑 deploy-remote.sh
  test-db-key.sh             # 用数据库里的真 key 调 /store/regions，验证 key 是否对得上
  check-baked-url.sh         # 查发布包里 baked 的后端 URL 是 http 还是 https
  create-regions.md          # 建 US/CN 地区的接口说明
  backup.sh                  # 每日 pg_dump（配 cron）
  sanitize-for-github.py     # 把 compose 里的密钥换成占位符（提交前跑）
  build-base-image-2226.sh   # 构建 2.22.6 基础镜像（v1.1.0 用）
  assemble-v110.sh           # 组装 v1.1.0 发布包
  check-admin-modules.sh     # 查 /admin/modules 404 的诊断脚本
  check-modules-route-2212.sh  # 查 2.21.2 里有没有 modules 路由
  check-region-tables.sh     # 查 region / region_country 表结构
```

不在这个包里的东西（VPS 上才有，不提交）：`.env.prod`、`nginx/certs/origin.pem`、
`nginx/certs/origin.key`、`releases/`、`build/`、`/data/backup/`、数据库本身。

## 后端升级（v1.1.0 做法，后端版本变了才需要）

server/worker 容器用基础镜像里的 `node_modules`，发布包只换 `.medusa/server`
和配置，所以升后端版本必须先重建基础镜像：

```sh
# 1. 在 VPS 上构建新基础镜像（Dockerfile 在 docker/，脚本在 scripts/）
bash deploy/scripts/build-base-image-2226.sh   # 产物 dtc-runtime:node22-pnpm10-2.22.6
# 2. 组装新 release（后端产物复用已构建好的版本，base-image.txt 指向新镜像）
bash deploy/scripts/assemble-v110.sh
# 3. 发布；server 启动命令里自带 `medusa db:migrate`，迁移自动跑
cd /data/medusa && bash deploy-remote.sh v1.1.0
```

升级前先备份数据库（`/data/backup/medusa-store-pre-v1.1.0-*.sql.gz`）。
`docker/Dockerfile.dtc-runtime-2.22.6` 是从 `docker history` 还原的原镜像做法：
`node:22.23.3-alpine` + rsync + corepack pnpm 10.11.1，只复制 package 清单 +
`medusa-config.ts` + `next.config.js`，然后 `pnpm install --frozen-lockfile`。

## 发布新版本（商城改动）

```sh
# 1. 在 VPS 上克隆/更新 fork，改代码
# 2. 构建商城（按 HTTPS 通没通选 v102 还是 v103 脚本里的后端 URL）
bash deploy/scripts/build-storefront-v103.sh
# 3. 发布
cd /data/medusa && bash deploy-remote.sh v1.0.3
# 4. 验收
curl -s -o /dev/null -w "%{http_code}\n" https://shop.satank.cn/
curl -s -o /dev/null -w "%{http_code}\n" https://shop-admin.satank.cn/health
```

后端改动同理：先 `medusa build`，再把 `.medusa/server` 和 `medusa-config.ts`
打包成新 release；后端版本升级要先重建基础镜像，见上节。

## 已知问题

- 管理员密码曾明文出现在 VPS 的 `/root/.bash_history` 里，建议清历史、换密码。
- 中国区商品还没有 CNY 价格（只有 EUR 和 USD 价格），中国区要能下单得先加价。
- R2 还没填，文件存储还是本地卷。
