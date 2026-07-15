---
tags:
  - devops
  - docker-compose
  - deployment
---

# Docker Compose

> spectra-admin/document/deploy/spectra-admin.yml 整合。

## 服务清单

| 服务 | 镜像 | 端口 | 说明 |
|---|---|---|---|
| spectra-postgres | postgres:18-alpine | — | PostgreSQL 数据库 |
| spectra-redis | redis:7 | — | Redis 缓存 |
| spectra-admin | ghcr.io/yangxj96/spectra-admin:latest | 8888 | 后端 API |

## 完整配置

```yaml
services:
  spectra-postgres:
    container_name: spectra-postgres
    image: postgres:18-alpine
    environment:
      POSTGRES_DB: spectra_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: QuVsKppcWvwwX2Vv
    networks:
      - nginx-net
    volumes:
      - /data/docker/spectra/postgres-data:/var/lib/postgresql
    deploy:
      resources:
        limits:
          memory: 512M

  spectra-redis:
    container_name: spectra-redis
    image: redis:7
    command: redis-server --requirepass QuVsKppcWvwwX2Vv
    restart: unless-stopped
    networks:
      - nginx-net

  spectra-admin:
    image: ghcr.io/yangxj96/spectra-admin:latest
    container_name: spectra-admin
    restart: unless-stopped
    user: "0:0"
    ports:
      - "8888:8888"
    networks:
      - nginx-net
    env_file:
      - /data/docker/spectra/.env
    volumes:
      - /data/docker/spectra/application.yml:/config/application.yml:ro
      - /data/docker/spectra/files:/workspace/files
    deploy:
      resources:
        limits:
          memory: 1g

networks:
  nginx-net:
    external: true
```

## 部署路径

| 路径 | 用途 |
|---|---|
| `/data/docker/spectra/.env` | 环境变量配置 |
| `/data/docker/spectra/application.yml` | Spring Boot 配置 |
| `/data/docker/spectra/files/` | 文件存储目录 |
| `/data/docker/spectra/postgres-data/` | PostgreSQL 数据目录 |

## 启动

```bash
docker compose -f spectra-admin.yml up -d
```

## 相关

- [[10-Docker部署]] — Docker 构建
- [[20-Nginx配置]] — Nginx 反向代理
- [[05-配置清单]] — 环境变量
