#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
import_script=$script_dir/../import-regions.sh
test_root=$(mktemp -d "${TMPDIR:-/tmp}/spectra-import-regions.XXXXXX")
trap 'rm -rf -- "$test_root"' EXIT
capture=$test_root/mise.log
export SPECTRA_IMPORT_TEST_CAPTURE=$capture
export PATH=$script_dir/fixtures:$PATH

"$import_script"

rg -F 'SPECTRA_REGION_IMPORT=true' "$capture" >/dev/null
rg -F -- '-Pmanual-integration' "$capture" >/dev/null
rg -F -- '-Dgroups=manual-integration' "$capture" >/dev/null
rg -F -- '-Dsurefire.failIfNoSpecifiedTests=false' "$capture" >/dev/null
printf '%s\n' 'PASS: import-regions enables the manual integration profile'
