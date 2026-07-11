# AGENTS.md

## System Architecture

Spectra is a full-stack system: one backend API serves two frontend clients. They live in separate directories with independent toolchains, but **they collaborate at runtime** — both frontends connect to `spectra-admin` as their API server.

```
┌─────────────────┐      ┌─────────────────┐
│  spectra-ui     │      │  spectra-app    │
│  (Web Admin)    │      │  (Mobile/H5)    │
│  Vue 3 + Element│      │  Vue 3 + uni-app│
│  Plus, Vite 8   │      │  Vite 5         │
└────────┬────────┘      └────────┬────────┘
         │                        │
         │   VITE_API_URL         │   VITE_API_BASE_URL
         │                        │
         └───────────┬────────────┘
                     │
          ┌──────────▼──────────┐
          │   spectra-admin     │
          │   (Backend API)     │
          │   Spring Boot 4     │
          │   Java 25, Maven    │
          │   PostgreSQL, Redis │
          └─────────────────────┘
```

| Directory | Role | Stack | Port (dev) |
|---|---|---|---|
| `spectra-admin/` | Backend API server | Java 25, Spring Boot 4, Maven, PostgreSQL, Redis | 4004 |
| `spectra-ui/` | Web admin panel | Vue 3, Vite 8, Element Plus, pnpm | 5173 |
| `spectra-app/` | Mobile app (H5 / WeChat Mini Program) | Vue 3, uni-app, Vite 5, pnpm | — |

**Each project has its own `AGENTS.md` — read it before working in that project.** This file covers only cross-project facts.

## How the Projects Connect

Both frontends point to the same backend in development:

- `spectra-ui/.env` → `VITE_API_URL=https://127.0.0.1:4004/`
- `spectra-app/.env.development` → `VITE_API_BASE_URL=https://127.0.0.1:4004`

The backend default port is **4004** (set via `SERVER_PORT` in `.mise.local.toml`).

When working on a feature that spans frontend + backend:
1. Start `spectra-admin` first (`./mvnw spring-boot:run -pl spectra-launch`)
2. Then start the relevant frontend (`pnpm start` in `spectra-ui` or `spectra-app`)

## Common Toolchain

- **Node**: 24.14.0, **pnpm**: 11.0.9 — managed via [mise](https://mise.jdx.dev/) (`mise.toml` / `.mise.local.toml`)
- **Java**: JDK 25 (Temurin), **Maven**: 3.9.12 — wrapper included (`mvnw` / `mvnw.cmd`)
- **npm registry**: taobao mirror (`registry.npmmirror.com`) configured in `.npmrc` for Vue projects

## Quick Reference

```bash
# spectra-admin (from spectra-admin/)
./mvnw clean package -DskipTests          # build
./mvnw spring-boot:run -pl spectra-launch # run API server

# spectra-ui (from spectra-ui/)
pnpm install && pnpm start                # dev server (auto format+lint+typecheck via prestart)

# spectra-app (from spectra-app/)
pnpm install && pnpm start                # H5 dev (auto typecheck+lint+format via prestart)
pnpm dev:mp-weixin                        # WeChat Mini Program dev
```

## Environment Setup

Before running anything, configure local environment:

- **spectra-admin**: copy `.mise.local.toml.example` to `.mise.local.toml`, fill in DB/Redis/S3/AI credentials
- **spectra-ui**: create `.env` with `VITE_API_URL` (defaults to `https://127.0.0.1:4004/`)
- **spectra-app**: create `.env` or use `.env.development` (defaults to `https://127.0.0.1:4004`)

Required services: **PostgreSQL** + **Redis** (for spectra-admin).

## 本地开发数据库（只读）

以下账号只有**只读权限**，可以放心用于查询和调试：

| 配置项 | 值 |
|---|---|
| 数据库类型 | PostgreSQL 18 |
| 地址 | `127.0.0.1` |
| 用户名 | `ai` |
| 密码 | `QuVsKppcWvwwX2Vv` |

对应 `.mise.local.toml` 配置：
```toml
DB_URL="jdbc:postgresql://127.0.0.1:5432/devops00_spectra_db"
DB_USERNAME="ai"
DB_PASSWORD="QuVsKppcWvwwX2Vv"
```

## Code Style (shared across Vue projects)

Both `spectra-ui` and `spectra-app` use identical Prettier config:
- 4-space indent, double quotes, semicolons, 120 char width, LF line endings
- No trailing commas, `arrowParens: avoid`, `bracketSameLine: true`

## Git Conventions

All projects use Conventional Commits: `type(scope): description`
- Backend scopes: `ai`, `security`, `core`, `framework`, `log`, `project`
- Use Chinese in commit body when the codebase is in Chinese

## CodeGraph

根目录有 `.codegraph/` 索引，覆盖全部三个子项目（spectra-admin、spectra-ui、spectra-app）。使用 `codegraph_explore` 前先确认目标文件是否在索引范围内。

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
