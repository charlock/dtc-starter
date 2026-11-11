// v1.0.2 生产版 medusa-config.ts — fork main (Medusa 2.22.6)
// 相对原仓库：补 redisUrl + workerMode + Redis 的 event-bus / workflow-engine / locking，
// S3_BUCKET 有值时自动启用 file-s3（Cloudflare R2，region auto）。
// Cache 模块先不开：它在 2.22 需要 MEDUSA_FF_CACHING=true，且要在
// docker-compose.prod.yml 的 medusa_server/worker 环境里加上这个变量，
// 下一个版本再开，先保 v1.0.2 一次成功。

import { loadEnv, defineConfig } from "@medusajs/framework/utils"

loadEnv(process.env.NODE_ENV || "production", process.cwd())

const REDIS_URL = process.env.REDIS_URL
const S3_BUCKET = process.env.S3_BUCKET

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    databaseDriverOptions: {
      ssl: false,
      sslmode: "disable",
    },
    redisUrl: REDIS_URL,
    workerMode: process.env.MEDUSA_WORKER_MODE as "shared" | "worker" | "server",
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET,
      cookieSecret: process.env.COOKIE_SECRET,
    },
  },
  admin: {
    disable: process.env.MEDUSA_WORKER_MODE === "worker",
  },
  modules: [
    {
      resolve: "@medusajs/medusa/event-bus-redis",
      options: {
        redisUrl: REDIS_URL,
      },
    },
    {
      resolve: "@medusajs/medusa/workflow-engine-redis",
      options: {
        redis: {
          redisUrl: REDIS_URL,
        },
      },
    },
    {
      resolve: "@medusajs/medusa/locking",
      options: {
        providers: [
          {
            resolve: "@medusajs/medusa/locking-redis",
            id: "locking-redis",
            is_default: true,
            options: {
              redisUrl: REDIS_URL,
            },
          },
        ],
      },
    },
    ...(S3_BUCKET
      ? [
          {
            resolve: "@medusajs/medusa/file",
            options: {
              providers: [
                {
                  resolve: "@medusajs/medusa/file-s3",
                  id: "s3",
                  options: {
                    file_url: process.env.S3_FILE_URL,
                    access_key_id: process.env.S3_ACCESS_KEY_ID,
                    secret_access_key: process.env.S3_SECRET_ACCESS_KEY,
                    region: process.env.S3_REGION || "auto",
                    bucket: S3_BUCKET,
                    endpoint: process.env.S3_ENDPOINT,
                  },
                },
              ],
            },
          },
        ]
      : []),
  ],
})
