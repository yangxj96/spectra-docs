#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sync_script=$script_dir/../sync-website-docs.sh
test_root=$(mktemp -d "${TMPDIR:-/tmp}/spectra-doc-sync.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
source_root=$test_root/source
website_root=$test_root/website

assert_file() {
  [[ -f "$1" ]] || { printf 'ASSERTION FAILED: missing file %s\n' "$1" >&2; exit 1; }
}
assert_absent() {
  [[ ! -e "$1" ]] || { printf 'ASSERTION FAILED: unexpected file %s\n' "$1" >&2; exit 1; }
}
assert_contains() {
  rg -F -- "$2" "$1" >/dev/null || { printf 'ASSERTION FAILED: %s does not contain %s\n' "$1" "$2" >&2; exit 1; }
}

mkdir -p "$source_root/docs/20-前端" "$source_root/docs/10-后端" "$source_root/docs/99-模板"
mkdir -p "$website_root/docs/pages/blogs" "$website_root/docs/pages/spectra-admin" "$website_root/docs/pages/logicflow-flowable"
mkdir -p "$source_root/scripts"

cat >"$source_root/scripts/website-docs-manifest.json" <<'JSON'
{
  "version": 1,
  "source": {"docsRoot": "docs", "excludeGlobs": ["90-计划/**", "99-模板/**", "superpowers/**"]},
  "targets": {
    "spectra": "docs/pages/spectra-admin",
    "designer": "docs/pages/logicflow-flowable",
    "assets": "docs/public/spectra-admin",
    "generatedSidebar": "docs/.vitepress/generated/project-sidebar.mts",
    "generatedManifest": "docs/.vitepress/generated/spectra-docs-sync.json"
  },
  "designerSources": ["20-前端/40-流程设计器.md"],
  "attachments": [{"source": "10-后端/permission-catalog.yaml", "target": "permission-catalog.yaml"}],
  "routeOverrides": {"00-项目总览.md": "index.md", "old.md": "old.md"}
}
JSON
printf '%s\n' '# 项目总览' '' '查看 [[20-前端/40-流程设计器]]。\n' >"$source_root/docs/00-项目总览.md"
printf '%s\n' '# 流程设计器' '' '`pnpm add @yangxj96/logicflow-plugin-flowable`' >"$source_root/docs/20-前端/40-流程设计器.md"
printf '%s\n' '# 旧页面' >"$source_root/docs/old.md"
printf '%s\n' 'version: 1' 'items:' '  - code: demo.read' >"$source_root/docs/10-后端/permission-catalog.yaml"
printf '%s\n' 'TOKEN=must-not-copy' >"$source_root/docs/.env"
printf '%s\n' '# 模板' >"$source_root/docs/99-模板/ignored.md"
printf '%s\n' '{"scripts":{"docs:build":"true"}}' >"$website_root/package.json"
printf '%s\n' '# Keep my blog' >"$website_root/docs/pages/blogs/keep.md"
printf '%s\n' '# Legacy project page' >"$website_root/docs/pages/spectra-admin/legacy.md"
printf '%s\n' '# Legacy designer page' >"$website_root/docs/pages/logicflow-flowable/legacy.md"

"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Preview >/tmp/spectra-sync-preview.$$ \
  || { cat /tmp/spectra-sync-preview.$$ >&2; exit 1; }
assert_file "$website_root/docs/pages/spectra-admin/legacy.md"
assert_absent "$website_root/docs/.vitepress/generated/project-sidebar.mts"

"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Apply --prune-legacy >/tmp/spectra-sync-apply.$$ \
  || { cat /tmp/spectra-sync-apply.$$ >&2; exit 1; }
assert_file "$website_root/docs/pages/spectra-admin/index.md"
assert_file "$website_root/docs/pages/logicflow-flowable/index.md"
assert_file "$website_root/docs/public/spectra-admin/permission-catalog.yaml"
assert_file "$website_root/docs/.vitepress/generated/project-sidebar.mts"
assert_absent "$website_root/docs/pages/spectra-admin/legacy.md"
assert_absent "$website_root/docs/pages/logicflow-flowable/legacy.md"
assert_contains "$website_root/docs/pages/blogs/keep.md" '# Keep my blog'
assert_contains "$website_root/docs/.vitepress/generated/spectra-docs-sync.json" 'permission-catalog.yaml'
if rg -i '\.env|token|password|secret' "$website_root/docs/.vitepress/generated/spectra-docs-sync.json" >/dev/null; then
  printf '%s\n' 'ASSERTION FAILED: sensitive path entered generated manifest' >&2
  exit 1
fi

"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Apply --prune-legacy >/tmp/spectra-sync-repeat.$$ \
  || { cat /tmp/spectra-sync-repeat.$$ >&2; exit 1; }
assert_contains /tmp/spectra-sync-repeat.$$ '删除: 0'
rm -f -- /tmp/spectra-sync-preview.$$ /tmp/spectra-sync-apply.$$ /tmp/spectra-sync-repeat.$$

rm -f -- "$source_root/docs/old.md"
"$sync_script" --source-root "$source_root" --website-root "$website_root" --mode Apply >/dev/null
assert_absent "$website_root/docs/pages/spectra-admin/old.md"
printf '%s\n' 'PASS: sync-website-docs fixture assertions'
