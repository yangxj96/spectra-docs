---
tags:
  - devops
  - docker-compose
  - deployment
---

# Docker Compose

> 本页是部署模板，不是仓库内现成的 Compose 文件。复制示例后，必须为目标机器创建自己的 `.env`，并在真实部署中固定镜像版本。

## 可复用与必须配置

| 内容 | 分类 | 说明 |
|---|---|---|
| 服务名、容器内端口 8888、数据库/Redis 内部地址 | 可复用 | 同一 Compose 网络内按服务名访问 |
| Named Volume | 可直接使用 | Docker 管理真实宿主机路径，避免写死 `/data/...` |
| `POSTGRES_PASSWORD`、`REDIS_PASSWORD` | 必须配置 | 只写入部署机 `.env` 或 Secret 管理系统 |
| S3/AI/RAG 地址和凭据 | 必须按功能配置 | 示例不提供真实 Provider |
| 宿主机映射端口、域名、镜像 Tag、资源限制 | 每套环境配置 | 不同服务器可能冲突或有不同规范 |

## Compose 模板

下面示例以 Nginx 在容器外或同网络反向代理后端为前提。后端容器内使用 HTTP 8888；开发机的 4004 约定不适用于容器内部。

示例中的 `postgres:18-alpine` 只覆盖基础启动，不自带项目 RAG 所需的 pgvector。启用 RAG 时应换成组织批准的 PostgreSQL 18 + pgvector 镜像或在数据库服务器安装扩展，再执行 `docs/sql/spectra_ai/建表.sql`。

```yaml
services:
  spectra-postgres:
    image: postgres:18-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-devops00_spectra_db}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set POSTGRES_PASSWORD}
    volumes:
      - spectra-postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10

  spectra-redis:
    image: redis:7
    restart: unless-stopped
    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD:?set REDIS_PASSWORD}"]
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD:?set REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10

  spectra-admin:
    image: ghcr.io/yangxj96/spectra-admin:${SPECTRA_IMAGE_TAG:?set SPECTRA_IMAGE_TAG}
    restart: unless-stopped
    ports:
      - "${SPECTRA_HTTP_PORT:-8888}:8888"
    environment:
      SERVER_PORT: "8888"
      SERVER_SSL_ENABLED: "false"
      DB_URL: jdbc:postgresql://spectra-postgres:5432/${POSTGRES_DB:-devops00_spectra_db}
      DB_USERNAME: ${POSTGRES_USER:-postgres}
      DB_PASSWORD: ${POSTGRES_PASSWORD:?set POSTGRES_PASSWORD}
      REDIS_HOST: spectra-redis
      REDIS_PORT: "6379"
      REDIS_DB: "0"
      REDIS_PASSWORD: ${REDIS_PASSWORD:?set REDIS_PASSWORD}
      S3_ENDPOINT: ${S3_ENDPOINT:?set S3_ENDPOINT}
      S3_ACCESS_KEY: ${S3_ACCESS_KEY:?set S3_ACCESS_KEY}
      S3_SECRET_KEY: ${S3_SECRET_KEY:?set S3_SECRET_KEY}
      S3_BUCKET: ${S3_BUCKET:?set S3_BUCKET}
      S3_REGION: ${S3_REGION:?set S3_REGION}
      AI_KEY: ${AI_KEY:?set AI_KEY}
      AI_BASE_URL: ${AI_BASE_URL:?set AI_BASE_URL}
      AI_MODEL: ${AI_MODEL:?set AI_MODEL}
      RAG_KEY: ${RAG_KEY:?set RAG_KEY}
      RAG_BASE_URL: ${RAG_BASE_URL:?set RAG_BASE_URL}
      RAG_MODEL: ${RAG_MODEL:?set RAG_MODEL}
    volumes:
      - spectra-files:/app/files
    depends_on:
      spectra-postgres:
        condition: service_healthy
      spectra-redis:
        condition: service_healthy

volumes:
  spectra-postgres-data:
  spectra-files:
```

真实生产环境优先使用 Docker/Kubernetes Secret，避免密码出现在普通 `.env`、命令历史或 `docker inspect` 可见配置中。本模板使用 Compose 变量只是说明所有必需字段。

## 部署机 `.env`

把 Compose 文件和 `.env` 放在部署机自选目录。路径属于部署环境，不应写死在项目文档：

```dotenv
SPECTRA_IMAGE_TAG=<固定发布版本>
SPECTRA_HTTP_PORT=8888
POSTGRES_DB=devops00_spectra_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<强随机密码>
REDIS_PASSWORD=<另一个强随机密码>
S3_ENDPOINT=<真实 S3/MinIO URL>
S3_ACCESS_KEY=<真实值>
S3_SECRET_KEY=<真实值>
S3_BUCKET=<真实值>
S3_REGION=<真实值>

AI_KEY=<真实值>
AI_BASE_URL=<真实值>
AI_MODEL=<真实值>
RAG_KEY=<真实值>
RAG_BASE_URL=<真实值>
RAG_MODEL=<真实值>
```

尖括号内容是占位符，不能原样运行。`.env` 必须限制文件权限并排除版本控制。

## 初始化和启动

Compose 创建空数据库后，仍需按 [[10-环境搭建#4. 准备 PostgreSQL 与 Redis]] 初始化项目 schema。随后在 Compose 文件所在目录执行：

```powershell
docker compose config
docker compose up -d
docker compose ps
```

`docker compose config` 会展开变量，输出可能包含秘密；只在可信终端查看，不要粘贴到 Issue、日志或聊天。

## 相关

- [[10-Docker部署]]
- [[20-Nginx配置]]
- [[05-配置清单]]
- [[10-环境搭建]]
