#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:?用法: ./deploy-remote.sh <version> [target-platform]}"
TARGET_PLATFORM="${2:-${TARGET_PLATFORM:-}}"
BASE_IMAGE="${BASE_IMAGE:-}"

if [[ ! "$VERSION" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
  echo "错误：版本号只能包含字母、数字、点、下划线和连字符" >&2
  exit 1
fi
if [[ "$VERSION" == "." || "$VERSION" == ".." ]]; then
  echo "错误：版本号不能是路径特殊目录" >&2
  exit 1
fi
if [[ ! -f .env.prod ]]; then
  echo "错误：服务器缺少 .env.prod" >&2
  exit 1
fi
if [[ ! -d "releases/$VERSION/backend-server" || ! -f "releases/$VERSION/backend-config/medusa-config.ts" || ! -f "releases/$VERSION/storefront/standalone/server.js" && ! -f "releases/$VERSION/storefront/standalone/apps/storefront/server.js" || ! -f "releases/$VERSION/base-image.txt" || ! -f "releases/$VERSION/target-platform.txt" ]]; then
  echo "错误：发布包 $VERSION 不完整" >&2
  exit 1
fi
RELEASE_BASE_IMAGE="$(<"releases/$VERSION/base-image.txt")"
RELEASE_TARGET_PLATFORM="$(<"releases/$VERSION/target-platform.txt")"
if [[ -n "$BASE_IMAGE" && "$BASE_IMAGE" != "$RELEASE_BASE_IMAGE" ]]; then
  echo "错误：BASE_IMAGE 与该版本记录不一致：$RELEASE_BASE_IMAGE" >&2
  exit 1
fi
if [[ -n "$TARGET_PLATFORM" && "$TARGET_PLATFORM" != "$RELEASE_TARGET_PLATFORM" ]]; then
  echo "错误：TARGET_PLATFORM 与该版本记录不一致：$RELEASE_TARGET_PLATFORM" >&2
  exit 1
fi
BASE_IMAGE="$RELEASE_BASE_IMAGE"
TARGET_PLATFORM="$RELEASE_TARGET_PLATFORM"
if [[ ! "$BASE_IMAGE" =~ ^[A-Za-z0-9][A-Za-z0-9._:/-]*$ ]]; then
  echo "错误：BASE_IMAGE 格式无效" >&2
  exit 1
fi
if [[ ! "$TARGET_PLATFORM" =~ ^linux/(amd64|arm64)$ ]]; then
  echo "错误：TARGET_PLATFORM 仅支持 linux/amd64 或 linux/arm64" >&2
  exit 1
fi
BASE_PLATFORM="$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$BASE_IMAGE" 2>/dev/null || true)"
if [[ "$BASE_PLATFORM" != "$TARGET_PLATFORM" ]]; then
  echo "错误：服务器基础镜像平台为 ${BASE_PLATFORM:-未知}，目标平台为 $TARGET_PLATFORM" >&2
  echo "请在本地重新构建基础镜像并运行 deploy.sh 上传" >&2
  exit 1
fi

export VERSION TARGET_PLATFORM BASE_IMAGE
COMPOSE=(docker compose -f docker-compose.prod.yml --env-file .env.prod)

echo "==> 启动/更新生产服务（复用基础镜像，仅替换版本化编译产物）"
"${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" up -d --no-build
"${COMPOSE[@]}" exec -T nginx nginx -t
# 上游容器更新后重新加载，使 Nginx 重新解析 Docker 服务地址。
"${COMPOSE[@]}" exec -T nginx nginx -s reload

echo "==> 服务状态"
"${COMPOSE[@]}" ps
