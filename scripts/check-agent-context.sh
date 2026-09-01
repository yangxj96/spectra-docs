#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$script_dir/.." && pwd)
global_agent=${CODEX_HOME:-$HOME/.codex}/AGENTS.md

targets=(
  "global|$global_agent|3072"
  "root|$project_root/AGENTS.md|6144"
  "backend|$project_root/spectra-admin/AGENTS.md|4096"
  "web|$project_root/spectra-ui/AGENTS.md|4096"
  "plugin|$project_root/logicflow-plugin-flowable/AGENTS.md|3072"
)

printf '%-10s %8s %8s %-10s %s\n' Scope Bytes Limit Status Path
failures=0
for target in "${targets[@]}"; do
  IFS='|' read -r scope path limit <<<"$target"
  if [[ ! -f "$path" ]]; then
    printf '%-10s %8s %8s %-10s %s\n' "$scope" 0 "$limit" MISSING "$path"
    failures=$((failures + 1))
    continue
  fi
  bytes=$(stat -c '%s' "$path")
  if ((bytes <= limit)); then
    status=OK
  else
    status=TOO_LARGE
    failures=$((failures + 1))
  fi
  printf '%-10s %8s %8s %-10s %s\n' "$scope" "$bytes" "$limit" "$status" "$path"
done

for pattern in \
  '必读 `docs/00-项目总览.md`' \
  '后端任务再读 `docs/40-规范/15-后端开发规范.md`' \
  '每次.*读取.*docs/'; do
  if rg -n --pcre2 "$pattern" "$project_root/AGENTS.md" >/dev/null 2>&1; then
    printf '根 AGENTS 包含无条件文档加载规则: %s\n' "$pattern" >&2
    failures=$((failures + 1))
  fi
done

if ((failures > 0)); then
  printf 'Agent context audit failed: %s 项。\n' "$failures" >&2
  exit 1
fi
printf '%s\n' 'Agent context audit passed.'
