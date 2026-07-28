---
tags:
  - devops
  - docker
  - deployment
source: https://www.devops00.com/spectra-admin/ (Docker 部分)
---

# Docker 部署

> Docker 构建与部署配置。

## 验证码与字体

本项目的验证码功能依赖 Java AWT（`java.desktop` 模块）进行字体注册与图像绘制。

### 问题

Spring Boot `build-image` 默认使用精简（headless）JRE，不包含 `java.desktop` 模块，导致：

```
java.io.IOException: Problem reading font data
```

### 解决方案

使用完整 JDK 的 buildpack 构建镜像：

```xml
<plugin>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-maven-plugin</artifactId>
  <configuration>
    <image>
      <builder>paketobuildpacks/builder-jammy-full</builder>
    </image>
  </configuration>
</plugin>
```

该 builder 提供：
- 完整的 `java.desktop` 模块
- 字体渲染依赖（fontconfig / freetype）
- AWT 字体注册与验证码正常生成

> 本地开发环境（完整 JDK）通常不会出现该问题。

## 手动 Docker 构建

```bash
# 在 spectra-launch 目录下执行
docker build --build-arg JAR_FILE=spectra-launch-*.jar -t spectra-admin .
```

## CI/CD

GitHub Actions 工作流：`.github/workflows/spectra-minimal-image.yml`
- 手动触发（`workflow_dispatch`）
- 构建 Maven 项目 → 创建 Docker 镜像 → 推送到 GHCR

## 相关

- [[20-Nginx配置]] — Nginx 反向代理
- [[30-DockerCompose]] — 容器编排
- [[40-SSL证书配置]] — SSL 证书
