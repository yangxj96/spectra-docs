---
tags:
  - devops
  - nginx
  - deployment
---

# Nginx 配置

> spectra-admin/document/deploy/spectra.conf 整合。

## 配置概览

```nginx
server {
    listen 443 ssl http2;
    server_name spectra.devops00.com;

    # SSL 配置
    ssl_certificate     /etc/letsencrypt/live/devops00.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/devops00.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 请求限制
    client_max_body_size 10M;
    limit_conn conn_limit 20;
    limit_req zone=req_limit burst=20 nodelay;
}
```

## 前端静态资源

```nginx
root /usr/share/nginx/html/spectra;
index index.html;

# SPA 路由处理
location / {
    try_files $uri $uri/ /index.html;
}

# 静态资源缓存
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|ttf|woff|woff2|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable, max-age=31536000";
}
```

## API 反向代理

```nginx
location /api/ {
    proxy_pass http://spectra-admin:8888;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 5s;
    proxy_read_timeout 120s;
    proxy_send_timeout 60s;
}
```

## 安全配置

- 禁止访问敏感文件（.git, .env, .ini, .log 等）
- 禁止 SQL 注入攻击
- 禁止常见扫描工具和恶意 User-Agent
- 仅允许 GET、POST、HEAD 方法

## 相关

- [[10-Docker部署]] — Docker 部署
- [[30-DockerCompose]] — 容器编排
- [[40-SSL证书配置]] — SSL 证书
