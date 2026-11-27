#!/usr/bin/env bash
# Tests bin/catalog against the examples:
#   - `json` on the example catalog equals expected.json;
#   - `check` fails on every invalid catalog and shows its expected message;
#   - a few lookups give the answers a reader of catalog.yml would expect.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
catalog="$repo/bin/catalog"
examples="$repo/examples/catalog"
failures=0
fail() { echo "FAIL $*" >&2; failures=$((failures + 1)); }
run() { "$catalog" -f "$examples/catalog.yml" "$@"; }

if diff <(run json | jq -S .) <(jq -S . "$examples/expected.json") >/dev/null; then
  echo "ok   json equals expected.json"
else
  fail "json differs from expected.json"
  diff <(run json | jq -S .) <(jq -S . "$examples/expected.json") | head -20 >&2 || true
fi

for f in "$examples"/invalid/*.yml; do
  want=$(sed -n 's/^# expect-error: //p' "$f" | head -n 1)
  if out=$("$catalog" -f "$f" check 2>&1); then
    fail "$(basename "$f"): check succeeded"
  elif ! grep -qF -- "$want" <<<"$out"; then
    fail "$(basename "$f"): expected \"$want\", got: $out"
  fi
done
echo "ok   check fails on every invalid catalog with its message"

expect() { # expect <description> <needle> <command...>
  local what=$1 needle=$2; shift 2
  if out=$(run "$@" 2>&1) && grep -qF -- "$needle" <<<"$out"; then
    echo "ok   $what"
  else
    fail "$what: \"$needle\" not in output of '$*': $out"
  fi
}

expect "check summarises" "ok: 4 apps, 7 instances, 12 names, 4 sign-in registrations" check
expect "host lists a second instance on the same host" "wiki-02-prod" host apps-01
expect "host finds guests by node" "resolver-01-prod" host pve-01
expect "a short alias resolves to its instance" "alias → wiki-01-prod.svc.example.org" name wiki
expect "an instance name points at its peer" "the NetBird peer wiki-01-prod" name wiki-01-prod
expect "instance shows the ACME target" "_acme-challenge → tracker-staging-svc-example-org.acme.example.com" instance tracker-01-staging
expect "access lists what a group reaches" "staff, contractors to app-tracker (tcp)" access contractors
expect "sign-in lists redirect URIs" "https://wiki-next.svc.example.org/oauth/callback" sign-in wiki
expect "hosts lists guest nodes" "pve-02 (guest node)" hosts
expect "--json answers in JSON" '"vm_id": 202' --json instance resolver-02-prod

if out=$(run app nope 2>&1); then fail "app nope: succeeded"; else echo "ok   unknown names fail: $out"; fi

if ((failures)); then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all lookup checks passed"
