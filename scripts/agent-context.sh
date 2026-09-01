#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$script_dir/.." && pwd)
current_path=$(pwd -P)
area=auto
facts=0

usage() {
  printf '%s\n' '用法: scripts/agent-context.sh [--area auto|all|backend|web|plugin] [--facts]'
}

while (($# > 0)); do
  case "$1" in
    --area)
      (($# >= 2)) || { usage >&2; exit 2; }
      area=$2
      shift 2
      ;;
    --facts) facts=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '未知参数: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$area" in
  auto|all|backend|web|plugin) ;;
  *) printf '无效 area: %s\n' "$area" >&2; exit 2 ;;
esac

if [[ "$area" == auto ]]; then
  case "$current_path" in
    "$project_root/spectra-admin"|"$project_root/spectra-admin"/*) area=backend ;;
    "$project_root/spectra-ui"|"$project_root/spectra-ui"/*) area=web ;;
    "$project_root/logicflow-plugin-flowable"|"$project_root/logicflow-plugin-flowable"/*) area=plugin ;;
    *) area=all ;;
  esac
fi

printf '%s\n' '=== Agent Context Route ==='
printf 'Workspace: %s\n' "$project_root"
printf 'Area: %s\n' "$area"

case "$area" in
  all)
    cat <<'ROUTES'
Name      Agent                                      Skill                         Validate
backend   spectra-admin/AGENTS.md                    $spectra-admin-spec           ./mvnw -pl <module> -am test
web       spectra-ui/AGENTS.md                       $spectra-ui-spec              pnpm run type-check; pnpm run test
plugin    logicflow-plugin-flowable/AGENTS.md        无专用 Skill；使用插件 AGENTS.md pnpm run format:check; pnpm run build
ROUTES
    printf '%s\n' 'Docs: 仅按任务读取 docs/00-项目总览.md、架构笔记或一个目标领域笔记。'
    ;;
  backend)
    cat <<'ROUTE'
Name: backend
Agent: spectra-admin/AGENTS.md
Skill: $spectra-admin-spec
Docs:
- docs/10-后端/目标领域笔记
- docs/30-数据模型/目标实体笔记
Validate: ./mvnw -pl <module> -am test
ROUTE
    ;;
  web)
    cat <<'ROUTE'
Name: web
Agent: spectra-ui/AGENTS.md
Skill: $spectra-ui-spec
Docs:
- docs/20-前端/10-spectra-ui.md（仅目标规则未覆盖时）
Validate: pnpm run type-check; pnpm run test
ROUTE
    ;;
  plugin)
    cat <<'ROUTE'
Name: plugin
Agent: logicflow-plugin-flowable/AGENTS.md
Skill: 无专用 Skill；使用插件 AGENTS.md
Docs:
- docs/20-前端/30-流程建模插件.md（仅节点行为未覆盖时）
Validate: pnpm run format:check; pnpm run build
ROUTE
    ;;
esac

printf '%s\n' 'Context policy: 不预加载无关领域文档；结构分析优先使用 CodeGraph。'

if ((facts)); then
  command -v rg >/dev/null 2>&1 || { printf '未找到 rg（ripgrep），无法读取项目事实。\n' >&2; exit 1; }
  wrapper_properties=$project_root/spectra-admin/.mvn/wrapper/maven-wrapper.properties
  pom=$project_root/spectra-admin/pom.xml
  maven_version=$(sed -n 's/.*apache-maven-\([^/]*\)-bin.*/\1/p' "$wrapper_properties" | head -n1)
  backend_version=$(sed -n 's:.*<revision>\([^<]*\)</revision>.*:\1:p' "$pom" | head -n1)
  spring_boot_version=$(awk '/<artifactId>spring-boot-starter-parent<\/artifactId>/ { found=1; next } found && /<version>/ { gsub(/.*<version>|<\/version>.*/, ""); print; exit }' "$pom")
  controller_count=$(rg -l '^\s*@RestController\s*$' "$project_root/spectra-admin" -g '*.java' 2>/dev/null | wc -l | tr -d ' ')
  entity_count=$(rg -l '@TableName' "$project_root/spectra-admin" -g '*.java' 2>/dev/null | wc -l | tr -d ' ')
  if command -v codegraph >/dev/null 2>&1; then code_graph='可用'; else code_graph='未在 PATH 中（可选）'; fi
  printf '%s\n' '=== Project Facts ==='
  printf 'BackendVersion: %s\n' "$backend_version"
  printf 'SpringBoot: %s\n' "$spring_boot_version"
  printf 'Maven: %s\n' "$maven_version"
  printf 'Controllers: %s\n' "$controller_count"
  printf 'Entities: %s\n' "$entity_count"
  printf 'CodeGraph: %s\n' "$code_graph"
  printf 'Shell: bash\n'
fi
