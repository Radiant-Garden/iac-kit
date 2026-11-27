#!/usr/bin/env bash
# Checks the example catalogs:
#   - examples/catalog/catalog.yml passes the JSON Schema;
#   - every examples/catalog/invalid/*.yml
#       fails `tofu plan` with the message in its "# expect-error:" header,
#       passes or fails the JSON Schema as its "# schema:" header says
#         (valid = only the module catches it: a cross-field rule),
#       and has a run in the module's tofu test file.
#
# Needs tofu, jq and check-jsonschema (CHECK_JSONSCHEMA overrides the command,
# e.g. "pipx run check-jsonschema==0.33.0").
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
examples="$repo/examples/catalog"
schema="$repo/schema/catalog.v1.schema.json"
tests="$repo/tofu/modules/catalog/tests/catalog.tftest.hcl"
read -r -a check_jsonschema <<<"${CHECK_JSONSCHEMA:-check-jsonschema}"

failures=0
stderr_file=$(mktemp)
trap 'rm -f "$stderr_file"' EXIT
fail() { echo "FAIL $*" >&2; failures=$((failures + 1)); }

header() { sed -n "s/^# $1: //p" "$2" | head -n 1; }

schema_ok() { "${check_jsonschema[@]}" --schemafile "$schema" "$1" >/dev/null 2>&1; }

tofu -chdir="$examples" init -input=false -backend=false >/dev/null

if schema_ok "$examples/catalog.yml"; then
  echo "ok   catalog.yml passes the schema"
else
  fail "catalog.yml does not pass the schema"
  "${check_jsonschema[@]}" --schemafile "$schema" "$examples/catalog.yml" || true
fi

for f in "$examples"/invalid/*.yml; do
  name=$(basename "$f")
  want_error=$(header expect-error "$f")
  want_output=$(header expect-output "$f")
  want_schema=$(header schema "$f")
  if [[ -z $want_error || -z $want_output || -z $want_schema ]]; then
    fail "$name: needs expect-error, expect-output and schema headers"
    continue
  fi

  # -json: diagnostics arrive unwrapped, so the message can be matched as is.
  # stdout is JSON lines; anything on stderr is kept apart and shown on failure.
  if out=$(tofu -chdir="$examples" plan -input=false -json -var "catalog_file=invalid/$name" 2>"$stderr_file"); then
    fail "$name: plan succeeded"
    continue
  fi
  details=$(jq -Rr 'fromjson? | select(.type == "diagnostic" and .diagnostic.severity == "error") | .diagnostic.detail' <<<"$out")
  [[ -s $stderr_file ]] && details+=$'\n'"$(cat "$stderr_file")"
  if grep -qF -- "$want_error" <<<"$details"; then
    echo "ok   $name fails the plan: $want_error"
  else
    fail "$name: expected \"$want_error\", got: $details"
  fi

  if schema_ok "$f"; then got_schema=valid; else got_schema=invalid; fi
  if [[ $got_schema == "$want_schema" ]]; then
    echo "ok   $name is $got_schema for the schema"
  else
    fail "$name: schema says $got_schema, header says $want_schema"
  fi

  run="invalid_$(basename "$name" .yml | tr - _)"
  if ! grep -q "run \"$run\"" "$tests" ||
    ! awk -v run="run \"$run\"" -v want="expect_failures = [output.$want_output]" \
      'index($0, run) { inside = 1 } inside && index($0, want) { found = 1 } inside && /^}/ { inside = 0 } END { exit !found }' "$tests"; then
    fail "$name: no run \"$run\" expecting output.$want_output in $(basename "$tests")"
  fi
done

if ((failures)); then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all example checks passed"
