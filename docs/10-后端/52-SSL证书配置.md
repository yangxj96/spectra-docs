---
tags:
  - backend
  - infrastructure
  - security
source: https://www.devops00.com/spectra-admin/be-ssl-scripts
---

# SSL 证书配置

> 来源：[[00-项目总览|项目 VitePress 文档]] + `spectra-admin/document/scripts/ssl/`

## 步骤概述

1. 生成 CA 根证书并加载到 Windows「受信任的根证书颁发机构」
2. 用 CA 根证书签发 SSL 证书
3. CA 证书可团队复用

## 一、生成 CA 根证书（需管理员权限）

```powershell
$WorkDir = Join-Path $env:USERPROFILE "dev-https"
$CA_Name = "Spectra CA"
$Org = "Spectra"
$Country = "CN"
$State = "Kunming"
$City = "Kunming"
$ValidDays = 3650  # 10年

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Set-Location $WorkDir

# 生成 CA 私钥和证书
openssl genrsa -out SpectraRootCA.key 2048
openssl req -x509 -new -nodes -key SpectraRootCA.key \
  -sha256 -days $ValidDays \
  -subj "/C=$Country/ST=$State/L=$City/O=$Org/CN=$CA_Name" \
  -out SpectraRootCA.crt

# 安装到信任库
Import-Certificate -FilePath "$WorkDir\SpectraRootCA.crt" -CertStoreLocation Cert:\CurrentUser\Root
```

## 二、卸载 CA 根证书

```powershell
$CA_Name = "Spectra CA"
$Cert = Get-ChildItem -Path Cert:\CurrentUser\Root | Where-Object {
    $_.Subject -like "*CN=$CA_Name*"
}
if ($Cert) {
    Remove-Item -Path "Cert:\CurrentUser\Root\$($Cert.Thumbprint)" -Force
}
```

## 三、生成 SSL 证书

```powershell
# 生成私钥
openssl genrsa -out localhost.key 2048

# SAN 配置（支持 localhost + 127.0.0.1）
# 见 document/scripts/ssl/generate-cert.ps1

# 签发证书
openssl x509 -req -in localhost.csr \
  -CA SpectraRootCA.crt -CAkey SpectraRootCA.key -CAcreateserial \
  -out localhost.crt -days 365 -sha256 \
  -extfile san.cnf -extensions v3_req

# 生成 .p12（Spring Boot 使用）
openssl pkcs12 -export -in localhost.crt -inkey localhost.key \
  -out keystore.p12 -name tomcat -password pass:QuVsKppcWvwwX2Vv
```

## Spring Boot 配置

将 `keystore.p12` 放入 `src/main/resources/`，在 `.mise.local.toml` 中配置：

```toml
SSL_PASSWORD=QuVsKppcWvwwX2Vv
SSL_TYPE=PKCS12
SSL_ALIAS=tomcat
```

## 关键文件

| 文件 | 路径 |
|---|---|
| 生成 CA 脚本 | `spectra-admin/document/scripts/ssl/install-ca.ps1` |
| 卸载 CA 脚本 | `spectra-admin/document/scripts/ssl/uninstall-ca.ps1` |
| 生成 SSL 脚本 | `spectra-admin/document/scripts/ssl/generate-cert.ps1` |

## 相关笔记

- [[80-基础设施]] — 全局基础设施配置
- [[10-环境搭建]] — 开发环境初始化
- [[82-数据库连接池]] — 数据库连接配置
