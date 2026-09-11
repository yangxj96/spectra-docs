#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sync_script=$script_dir/../sync-website-docs.sh
test_root=$(mktemp -d "${TMPDIR:-/tmp}/spectra-doc-sync.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
source_root=$test_root/spectra-docs
website_root=$test_root/yangxj96-website

assert_file() {
  [[ -f "$1" ]] || { printf 'ASSERTION FAILED: missing file %s\n' "$1" >&2; exit 1; }
}
assert_absent() {
  [[ ! -e "$1" ]] || { printf 'ASSERTION FAILED: unexpected file %s\n' "$1" >&2; exit 1; }
}
assert_contains() {
  rg -F -- "$2" "$1" >/dev/null || { printf 'ASSERTION FAILED: %s does not contain %s\n' "$1" "$2" >&2; exit 1; }
}
assert_not_contains() {
  ! rg -F -- "$2" "$1" >/dev/null || { printf 'ASSERTION FAILED: %s unexpectedly contains %s\n' "$1" "$2" >&2; exit 1; }
}

mkdir -p "$source_root/docs/后端/10-后端模块" "$source_root/docs/后端/40-配置说明"
mkdir -p "$source_root/docs/前端" "$source_root/docs/流程设计器"
mkdir -p "$source_root/docs/开发指南" "$source_root/docs/部署运维" "$source_root/docs/AI速查"
mkdir -p "$source_root/docs/使用指南" "$source_root/docs/参考文档" "$source_root/docs/参与贡献"
mkdir -p "$website_root/docs/pages/blogs" "$website_root/docs/pages/spectra" \
  "$website_root/docs/pages/spectra-ui" "$website_root/docs/pages/spectra-admin" \
  "$website_root/docs/pages/spectra-guide" "$website_root/docs/pages/spectra-ops" \
  "$website_root/docs/pages/logicflow-flowable" "$website_root/docs/pages/spectra-quickstart" \
  "$website_root/docs/pages/spectra-user-guide" "$website_root/docs/pages/spectra-reference" \
  "$website_root/docs/pages/spectra-contributing"
mkdir -p "$source_root/scripts"
cp -- "$sync_script" "$source_root/scripts/sync-website-docs.sh"
cp -- "${sync_script%.sh}.py" "$source_root/scripts/sync-website-docs.py"

cat >"$source_root/scripts/website-docs-manifest.json" <<'JSON'
{
  "version": 2,
  "source": {"docsRoot": "docs", "excludeGlobs": ["superpowers/**"]},
  "sections": [
    {"id": "overview", "sourceFiles": ["00-项目总览.md"], "target": "docs/pages/spectra", "routePrefix": "spectra", "sidebar": "overviewSidebar", "routeOverrides": {"00-项目总览.md": "index.md"}},
    {"id": "quickstart", "sourceFiles": ["01-快速开始.md"], "target": "docs/pages/spectra-quickstart", "routePrefix": "spectra-quickstart", "sidebar": "quickstartSidebar", "routeOverrides": {"01-快速开始.md": "index.md"}},
    {"id": "user-guide", "sourceRoot": "使用指南", "target": "docs/pages/spectra-user-guide", "routePrefix": "spectra-user-guide", "sidebar": "userGuideSidebar", "routeOverrides": {"00-使用指南.md": "index.md"}},
    {"id": "frontend", "sourceRoot": "前端", "target": "docs/pages/spectra-ui", "routePrefix": "spectra-ui", "sidebar": "frontendSidebar", "routeOverrides": {"00-前端总览.md": "index.md"}},
    {"id": "backend", "sourceRoot": "后端", "target": "docs/pages/spectra-admin", "routePrefix": "spectra-admin", "sidebar": "backendSidebar", "routeOverrides": {"10-后端模块/00-后端总览.md": "index.md", "40-配置说明/00-后端配置说明.md": "spectra-config.md"}},
    {"id": "guide", "sourceRoot": "开发指南", "target": "docs/pages/spectra-guide", "routePrefix": "spectra-guide", "sidebar": "guideSidebar"},
    {"id": "operations", "sourceRoot": "部署运维", "target": "docs/pages/spectra-ops", "routePrefix": "spectra-ops", "sidebar": "operationsSidebar", "sidebarTitleOverrides": {"05-运维应急解锁手册.md": "运维应急解锁手册"}},
    {"id": "designer", "sourceRoot": "流程设计器", "target": "docs/pages/logicflow-flowable", "routePrefix": "logicflow-flowable", "sidebar": "designerSidebar", "routeOverrides": {"00-流程设计器.md": "index.md"}},
    {"id": "reference", "sourceRoot": "参考文档", "target": "docs/pages/spectra-reference", "routePrefix": "spectra-reference", "sidebar": "referenceSidebar", "routeOverrides": {"00-版本与支持范围.md": "index.md"}},
    {"id": "contributing", "sourceRoot": "参与贡献", "target": "docs/pages/spectra-contributing", "routePrefix": "spectra-contributing", "sidebar": "contributingSidebar", "routeOverrides": {"00-贡献指南.md": "index.md"}}
  ],
  "attachments": [{"source": "后端/10-后端模块/permission-catalog.yaml", "target": "permission-catalog.yaml", "section": "backend"}]
}
JSON
printf '%s\n' '# 项目总览' '' '参见 [[00-前端总览]]、[[00-后端总览]]、[[00-开发指南]] 和 [[00-流程设计器]]。\n' >"$source_root/docs/00-项目总览.md"
printf '%s\n' '# 快速开始' >"$source_root/docs/01-快速开始.md"
printf '%s\n' '# 使用指南' >"$source_root/docs/使用指南/00-使用指南.md"
printf '%s\n' '# 后端总览' '' '参见 [[00-前端总览]] 和 [[00-开发指南]]。\n' >"$source_root/docs/后端/10-后端模块/00-后端总览.md"
printf '%s\n' '# 前端总览' '' '参见 [[00-后端总览]]。\n' >"$source_root/docs/前端/00-前端总览.md"
printf '%s\n' '# 流程设计器' '' '参见 [[00-后端总览]]。\n' >"$source_root/docs/流程设计器/00-流程设计器.md"
printf '%s\n' '# 开发指南' >"$source_root/docs/开发指南/00-开发指南.md"
printf '%s\n' '# 部署运维' >"$source_root/docs/部署运维/00-部署运维.md"
printf '%s\n' '# 版本与支持范围' >"$source_root/docs/参考文档/00-版本与支持范围.md"
printf '%s\n' '# 贡献指南' >"$source_root/docs/参与贡献/00-贡献指南.md"
printf '%s\n' '# DEV_OPS Break-glass Runbook' >"$source_root/docs/部署运维/05-运维应急解锁手册.md"
printf '%s\n' '# 后端配置说明' >"$source_root/docs/后端/40-配置说明/00-后端配置说明.md"
printf '%s\n' '# 旧页面' >"$source_root/docs/后端/10-后端模块/old.md"
printf '%s\n' 'version: 1' 'items:' '  - code: demo.read' >"$source_root/docs/后端/10-后端模块/permission-catalog.yaml"
printf '%s\n' 'TOKEN=must-not-copy' >"$source_root/docs/.env"
printf '%s\n' '# AI 内部速查不得发布' >"$source_root/docs/AI速查/05-配置清单.md"
printf '%s\n' '{"scripts":{"docs:build":"true"}}' >"$website_root/package.json"
printf '%s\n' '# Keep my blog' >"$website_root/docs/pages/blogs/keep.md"
printf '%s\n' '# Legacy AI page' >"$website_root/docs/pages/spectra-admin/legacy-ai.md"
printf '%s\n' '# Legacy frontend page' >"$website_root/docs/pages/spectra-admin/legacy-frontend.md"
printf '%s\n' '# Legacy guide page' >"$website_root/docs/pages/spectra-guide/legacy-guide.md"
printf '%s\n' '# Legacy designer page' >"$website_root/docs/pages/logicflow-flowable/legacy.md"

default_sync_script=$source_root/scripts/sync-website-docs.sh
"$default_sync_script" --source-root "$source_root" --mode Preview >/tmp/spectra-sync-default-preview.$$ \
  || { cat /tmp/spectra-sync-default-preview.$$ >&2; exit 1; }
assert_contains /tmp/spectra-sync-default-preview.$$ 'Preview 完成，未修改 website。'
rm -f -- /tmp/spectra-sync-default-preview.$$

"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Preview >/tmp/spectra-sync-preview.$$ \
  || { cat /tmp/spectra-sync-preview.$$ >&2; exit 1; }
assert_file "$website_root/docs/pages/spectra-admin/legacy-ai.md"
assert_absent "$website_root/.vitepress/generated/project-sidebar.mts"

"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Apply --prune-legacy >/tmp/spectra-sync-apply.$$ \
  || { cat /tmp/spectra-sync-apply.$$ >&2; exit 1; }
assert_file "$website_root/docs/pages/spectra/index.md"
assert_file "$website_root/docs/pages/spectra-quickstart/index.md"
assert_file "$website_root/docs/pages/spectra-user-guide/index.md"
assert_file "$website_root/docs/pages/spectra-ui/index.md"
assert_file "$website_root/docs/pages/spectra-admin/index.md"
assert_file "$website_root/docs/pages/spectra-guide/00-开发指南.md"
assert_file "$website_root/docs/pages/spectra-ops/00-部署运维.md"
assert_file "$website_root/docs/pages/logicflow-flowable/index.md"
assert_file "$website_root/docs/pages/spectra-reference/index.md"
assert_file "$website_root/docs/pages/spectra-contributing/index.md"
assert_file "$website_root/docs/pages/spectra-admin/spectra-config.md"
assert_file "$website_root/docs/public/spectra-admin/permission-catalog.yaml"
assert_file "$website_root/.vitepress/generated/project-sidebar.mts"
assert_absent "$website_root/docs/pages/spectra-admin/legacy-ai.md"
assert_absent "$website_root/docs/pages/spectra-admin/legacy-frontend.md"
assert_absent "$website_root/docs/pages/spectra-guide/legacy-guide.md"
assert_absent "$website_root/docs/pages/logicflow-flowable/legacy.md"
assert_contains "$website_root/docs/pages/blogs/keep.md" '# Keep my blog'
assert_contains "$website_root/.vitepress/generated/spectra-docs-sync.json" 'permission-catalog.yaml'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'export const frontendSidebar'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'export const quickstartSidebar'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'export const userGuideSidebar'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'export const guideSidebar'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'export const operationsSidebar'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'export const referenceSidebar'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'export const contributingSidebar'
assert_contains "$website_root/.vitepress/generated/project-sidebar.mts" '运维应急解锁手册'
assert_not_contains "$website_root/.vitepress/generated/project-sidebar.mts" 'DEV_OPS Break-glass Runbook'
if rg -i '\.env|token|password|secret|AI速查' "$website_root/.vitepress/generated/spectra-docs-sync.json" >/dev/null; then
  printf '%s\n' 'ASSERTION FAILED: sensitive path entered generated manifest' >&2
  exit 1
fi
if rg -F 'AI 内部速查不得发布' "$website_root/docs" >/dev/null; then
  printf '%s\n' 'ASSERTION FAILED: AI quick-reference content was published' >&2
  exit 1
fi

"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Apply --prune-legacy >/tmp/spectra-sync-repeat.$$ \
  || { cat /tmp/spectra-sync-repeat.$$ >&2; exit 1; }
assert_contains /tmp/spectra-sync-repeat.$$ '删除: 0'
rm -f -- /tmp/spectra-sync-preview.$$ /tmp/spectra-sync-apply.$$ /tmp/spectra-sync-repeat.$$

rm -f -- "$source_root/docs/old.md"
"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Apply >/dev/null
rm -f -- "$source_root/docs/后端/10-后端模块/old.md"
"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Apply >/dev/null
assert_absent "$website_root/docs/pages/spectra-admin/old.md"
printf '%s\n' 'PASS: sync-website-docs fixture assertions'
