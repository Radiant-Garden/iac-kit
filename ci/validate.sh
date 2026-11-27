#!/usr/bin/env bash
# tofu validate for every module and example root.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
status=0
for dir in "$repo"/tofu/modules/*/ "$repo"/examples/*/; do
  [[ -n $(find "$dir" -maxdepth 1 -name '*.tf' -print -quit) ]] || continue
  rel=${dir#"$repo"/}
  if tofu -chdir="$dir" init -input=false -backend=false >/dev/null &&
    tofu -chdir="$dir" validate -no-color >/dev/null; then
    echo "ok   $rel"
  else
    echo "FAIL $rel" >&2
    tofu -chdir="$dir" validate -no-color >&2 || true
    status=1
  fi
done
exit $status
