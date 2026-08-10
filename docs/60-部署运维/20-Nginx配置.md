---
tags:
  - devops
  - nginx
  - deployment
---

# Nginx 配置

> 这是可复用结构模板。域名、证书路径、静态文件目录和上游地址必须按部署环境修改。

## 变量说明

| 占位内容 | 是否可直接使用 | 说明 |
|---|---|---|
| `/api/` 路由和常用代理头 | 可以作为基线 | 与后端 context path 一致 |
| `spectra-admin:8888` | 仅同 Compose 网络可直接使用 | Compose 模板中后端服务名和容器端口 |
| `<你的域名>` | 不可以 | 改成实际 DNS 域名 |
| `<证书路径>`、`<私钥路径>` | 不可以 | 由证书签发/Secret 挂载方式决定 |
| `<Web 构建目录>` | 不可以 | 由镜像或宿主机部署目录决定 |

## 示例

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name <你的域名>;

    ssl_certificate     <证书路径>;
    ssl_certificate_key <私钥路径>;
    ssl_protocols TLSv1.2 TLSv1.3;

    root <Web 构建目录>;
    index index.html;
    client_max_body_size 10M;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        try_files $uri $uri/ /index.html;
    }

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

    location ~ /\. {
        deny all;
    }
}
```

尖括号占位符不是合法的最终 Nginx 值，部署前必须全部替换。若 Nginx 不在 Compose 网络中，`spectra-admin` 服务名无法解析，应改为实际可达的主机和映射端口，例如部署机环回地址上的 8888。

开发端口 4004 与容器端口 8888 是两套场景：

- 本机 `dev` profile：默认 HTTP 4004。
- Compose/生产 `prod` profile：模板显式设置容器 HTTP 8888，由 Nginx 终止 TLS。

## 验证

```powershell
nginx -t
```

配置检查通过后再按部署平台的服务管理方式 reload。证书私钥、完整 `.env` 和带凭据的上游 URL 不得进入仓库或诊断日志。

## 相关

- [[10-Docker部署]]
- [[30-DockerCompose]]
- [[40-SSL证书配置]]
