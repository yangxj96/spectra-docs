#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_root=$(cd -- "$script_dir/.." && pwd)
backend_root=$project_root/spectra-admin

command -v mise >/dev/null 2>&1 || { printf '未找到 mise。\n' >&2; exit 1; }
cd "$backend_root"
env SPECTRA_REGION_IMPORT=true mise exec -- ./mvnw \
  -Pmanual-integration \
  -pl spectra-modules/spectra-core -am \
  -Dgroups=manual-integration \
  -Dtest=RegionServiceTest \
  -Dsurefire.failIfNoSpecifiedTests=false \
  -Dstyle.color=never \
  test
