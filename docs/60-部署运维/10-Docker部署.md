---
tags:
  - devops
  - docker
  - deployment
---

# Docker 部署

> Docker 构建命令可以复用；镜像仓库、Tag、端口、Secret、数据卷和证书属于部署环境配置。

## 构建前提

- 使用 `spectra-admin/mvnw.cmd` 生成 Spring Boot 可执行 JAR。
- Dockerfile 位于 `spectra-admin/spectra-launch/Dockerfile`。
- Dockerfile 的构建上下文必须是 `spectra-launch/`，`JAR_FILE` 只传 JAR 文件名。
- 运行镜像时显式配置 `SERVER_PORT`；[[30-DockerCompose]] 使用容器内 HTTP 8888，由 Nginx 终止 TLS。

## 构建

从仓库根目录执行：

```powershell
Push-Location .\spectra-admin
.\mvnw.cmd clean package -DskipTests
$jar = Get-ChildItem .\spectra-launch\target\spectra-launch-*.jar -File |
    Where-Object { $_.Name -notlike '*.jar.original' } |
    Select-Object -First 1

Push-Location .\spectra-launch
docker build --build-arg "JAR_FILE=$($jar.Name)" -t spectra-admin:local .
Pop-Location
Pop-Location
```

`spectra-admin:local` 是本机标签，可直接用于本机验证。推送到镜像仓库时，仓库地址和版本 Tag 必须按发布流程确定；生产部署不要长期跟随 `latest`。

## 本机容器验证

后端仍需要完整的数据库、Redis 和 S3 环境变量。推荐使用 [[30-DockerCompose]] 集中配置，不要把真实值写进 Dockerfile 或 `docker run` 命令历史。

```powershell
docker image inspect spectra-admin:local
```

## AWT 与字体

验证码依赖 Java AWT 字体渲染。修改运行时基础镜像或改用 Spring Boot buildpack 后，必须验证镜像包含 `java.desktop`、fontconfig/freetype 和可用字体。精简 JRE/buildpack 可能出现 `Problem reading font data`；这不是本地完整 JDK 构建失败。

## CI/CD

后端子项目的 `.github/workflows/spectra-minimal-image.yml` 是当前 CI 入口。工作流、镜像仓库权限和发布 Tag 会随部署策略变化，实际发布前以工作流文件和目标环境为准。

## 相关

- [[20-Nginx配置]]
- [[30-DockerCompose]]
- [[40-SSL证书配置]]
- [[05-配置清单]]
