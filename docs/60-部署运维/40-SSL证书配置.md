---
tags:
  - backend
  - infrastructure
  - security
---

# SSL 证书配置

> 本地首次启动默认使用 HTTP，不需要证书。本页只用于确实需要 HTTPS、Secure Cookie 或证书链验证的本机环境。

## 哪些内容可复用

| 内容 | 分类 |
|---|---|
| 后端证书相对路径 `spectra-admin/files/ssl/keystore.p12` | 可复用约定 |
| `SSL_TYPE=PKCS12`、`SSL_ALIAS=tomcat` | 可复用默认值 |
| P12 密码、CA、私钥、证书有效期 | 每台机器/每套环境自行生成 |
| 系统证书库位置和企业 CA 流程 | 取决于操作系统和组织策略 |

仓库当前没有提交 `install-ca.ps1`、`generate-cert.ps1` 或 `uninstall-ca.ps1`。不要按旧文档尝试运行不存在的脚本。

## 本机自签名证书示例

要求 OpenSSL 已加入 PATH。以下命令从仓库根目录执行，生成仅用于本机开发的证书：

```powershell
$certDir = Join-Path (Resolve-Path .\spectra-admin) 'files\ssl'
New-Item -ItemType Directory -Path $certDir -Force | Out-Null
Push-Location $certDir

$securePassword = Read-Host '输入本机 P12 密码' -AsSecureString
$passwordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $env:SPECTRA_SSL_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)

    openssl req -x509 -newkey rsa:2048 -sha256 -days 825 -nodes `
        -keyout localhost.key -out localhost.crt `
        -subj '/CN=localhost' `
        -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'

    openssl pkcs12 -export -in localhost.crt -inkey localhost.key `
        -out keystore.p12 -name tomcat -passout env:SPECTRA_SSL_PASSWORD
} finally {
    $env:SPECTRA_SSL_PASSWORD = $null
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
    Pop-Location
}
```

生成的 `localhost.key`、`localhost.crt` 和 `keystore.p12` 都是本机材料，不得提交。确认 P12 可用后，可按本机安全策略处理不再需要的明文私钥文件。

## 后端本机配置

在 `spectra-admin/.mise.local.toml` 中设置：

```toml
SERVER_SSL_ENABLED = "true"
SSL_PASSWORD = "<与生成 P12 时一致的本机密码>"
SSL_TYPE = "PKCS12"
SSL_ALIAS = "tomcat"
```

尖括号内容必须替换，不能直接复制。不要把真实密码写回 `.mise.local.toml.example`。

## 前端同步

把本机前端配置改成 HTTPS：

```dotenv
# spectra-ui/.env.development
VITE_API_URL=https://127.0.0.1:4004/

# spectra-app/.env.development
VITE_API_BASE_URL=https://127.0.0.1:4004
```

浏览器默认不信任自签名证书。个人机器可以按操作系统策略信任 `localhost.crt`，团队或企业环境应使用组织 CA；不要共享或提交开发 CA 私钥。未建立信任时，健康检查和前端请求可能因证书校验失败。

## 恢复 HTTP

```toml
SERVER_SSL_ENABLED = "false"
```

同时把两个前端 API URL 改回 `http://`。协议不一致是新环境最常见的“页面能打开但接口全部失败”原因之一。

## 相关

- [[10-环境搭建]]
- [[20-脚本工具]]
- [[80-基础设施]]
- [[05-配置清单]]
