#!/usr/bin/env bash
# Self-test: the template must lint clean, the fixture must not.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
lint="$here/../skills/aip-audit/scripts/aip-lint.sh"
out="$(mktemp -d)"
fail=0

"$lint" -o "$out/good.json" "$here/../skills/aip-design/assets" 2>/dev/null
[[ $? -eq 0 ]] || { echo "FAIL: template has findings:"; cat "$out/good.json"; fail=1; }

"$lint" -o "$out/bad.json" "$here/fixtures/violations" 2>/dev/null
[[ $? -eq 1 ]] || { echo "FAIL: fixture should exit 1"; fail=1; }
for rule in core::0126::unspecified core::0131::synonyms core::0142::time-field-names \
            core::0158::request-page-token-field core::0140::lower-snake; do
  grep -q "\"$rule\"" "$out/bad.json" || { echo "FAIL: expected $rule"; fail=1; }
done

# --against: a renumbered field is a breaking change (exit 1); a bad ref is an error (exit 2).
if command -v buf >/dev/null && command -v git >/dev/null; then
  repo="$out/repo"
  mkdir -p "$repo/proto"
  cp -r "$here/../skills/aip-design/assets/acme" "$repo/proto/"
  printf 'version: v2\ndeps:\n  - buf.build/googleapis/googleapis\n' > "$repo/proto/buf.yaml"
  (cd "$repo/proto" && buf dep update >/dev/null 2>&1) || { echo "FAIL: buf dep update"; fail=1; }
  (cd "$repo" && git init -q -b main && git add -A \
    && git -c user.name=t -c user.email=t@t commit -qm base)
  sed -i.bak 's/string author = 3/string author = 7/' "$repo/proto/acme/library/v1/library.proto"
  rm -f "$repo/proto/acme/library/v1/library.proto.bak"
  (cd "$repo" && "$lint" -o "$out/brk.json" --against '.git#branch=main,subdir=proto' proto 2>/dev/null)
  [[ $? -eq 1 ]] || { echo "FAIL: breaking change should exit 1"; fail=1; }
  (cd "$repo" && "$lint" -o "$out/brk.json" --against '.git#branch=nope' proto 2>/dev/null)
  [[ $? -eq 2 ]] || { echo "FAIL: bad --against ref should exit 2"; fail=1; }
else
  echo "SKIP: --against tests (need buf and git)"
fi

# Docs: coverage map, Appendix A and item/rule counts must match the checklist and the linter.
linter_bin="${API_LINTER:-$(command -v api-linter || echo "$(go env GOPATH 2>/dev/null)/bin/api-linter")}"
python3 "$here/check_docs.py" "$linter_bin" || fail=1

[[ $fail -eq 0 ]] && echo "OK: all checks passed"
exit $fail
