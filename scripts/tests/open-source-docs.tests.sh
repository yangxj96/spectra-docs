#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$script_dir/../.." && pwd)

assert_file() {
  [[ -f "$1" ]] || { printf 'ASSERTION FAILED: missing file %s\n' "$1" >&2; exit 1; }
}

assert_contains() {
  rg -F -- "$2" "$1" >/dev/null || { printf 'ASSERTION FAILED: %s does not contain %s\n' "$1" "$2" >&2; exit 1; }
}

assert_file "$project_root/README.md"
assert_file "$project_root/LICENSE"
assert_file "$project_root/CONTRIBUTING.md"
assert_file "$project_root/CODE_OF_CONDUCT.md"
assert_file "$project_root/SECURITY.md"
assert_file "$project_root/CHANGELOG.md"
assert_file "$project_root/.github/ISSUE_TEMPLATE/bug_report.md"
assert_file "$project_root/.github/ISSUE_TEMPLATE/feature_request.md"
assert_file "$project_root/.github/pull_request_template.md"
assert_file "$project_root/docs/00-项目总览.md"
assert_file "$project_root/docs/01-快速开始.md"
assert_file "$project_root/docs/使用指南/00-使用指南.md"
assert_file "$project_root/docs/参考文档/00-版本与支持范围.md"
assert_file "$project_root/docs/参与贡献/00-贡献指南.md"

if rg -n "docs/(02-使用指南|60-参考文档|70-参与贡献)/" "$project_root/README.md" >/dev/null; then
  printf '%s\n' 'ASSERTION FAILED: README contains numbered public directory paths' >&2
  exit 1
fi

if rg -n '^\s*[-+].*AI速查|sourceRoot.*AI速查' "$project_root/scripts/website-docs-manifest.json" >/dev/null; then
  printf '%s\n' 'ASSERTION FAILED: AI quick-reference entered website manifest' >&2
  exit 1
fi

assert_contains "$project_root/scripts/website-docs-manifest.json" '"sourceRoot": "使用指南"'
assert_contains "$project_root/scripts/website-docs-manifest.json" '"sourceRoot": "参考文档"'
assert_contains "$project_root/scripts/website-docs-manifest.json" '"sourceRoot": "参与贡献"'
assert_contains "$project_root/docs/00-项目总览.md" '系统业务使用者'
assert_contains "$project_root/docs/参与贡献/01-提交与分支规范.md" 'Conventional Commits'

printf '%s\n' 'PASS: open-source documentation assertions'
