#!/usr/bin/env bash
# aip-lint.sh — run Google's api-linter (the official AIP linter) over a proto tree.
#
# Usage:
#   aip-lint.sh [options] <proto_root> [file.proto ...]
#
# Options:
#   -o FILE          Write the JSON report to FILE (default: <tmp>/aip-lint-report.json)
#   --strict         Ignore `(-- api-linter: ... --)` disable comments in the protos
#   --against REF    Also run `buf breaking` against REF (needs buf and a buf.yaml in <proto_root>).
#                    Local paths (.git, ./x, ../x) are relative to the current directory. If
#                    <proto_root> is a subdirectory of the repo, add it: '.git#branch=main,subdir=proto'
#
# Environment:
#   API_LINTER       Path to api-linter (default: api-linter on PATH, then $(go env GOPATH)/bin)
#   AIP_GOOGLEAPIS   Directory with google/api/*.proto (default: ~/.cache/aip-proto/googleapis,
#                    fetched once with `buf export buf.build/googleapis/googleapis`)
#
# Exit codes: 0 = no findings, 1 = findings or breaking changes, 2 = setup, compile or buf error.
set -euo pipefail

die() { echo "aip-lint: $*" >&2; exit 2; }

report="${TMPDIR:-/tmp}/aip-lint-report.json"
strict=()
against=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) report="$2"; shift 2 ;;
    --strict) strict=(--ignore-comment-disables); shift ;;
    --against) against="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) break ;;
  esac
done
[[ $# -ge 1 ]] || die "missing <proto_root>; see --help"
# Resolve local --against inputs before we cd into the root.
[[ "$against" =~ ^(\.git|\./|\.\./) ]] && against="$PWD/$against"
root="$(cd "$1" && pwd)" || die "proto_root not found: $1"
shift
report="$(cd "$(dirname "$report")" && pwd)/$(basename "$report")"

# 1. Locate api-linter.
linter="${API_LINTER:-$(command -v api-linter || true)}"
if [[ -z "$linter" ]] && command -v go >/dev/null; then
  candidate="$(go env GOPATH)/bin/api-linter"
  [[ -x "$candidate" ]] && linter="$candidate"
fi
[[ -n "$linter" ]] || die "api-linter not found. Install it with:
  go install github.com/googleapis/api-linter/v2/cmd/api-linter@latest"

# 2. Make sure the google/api/* protos are importable.
gapis="${AIP_GOOGLEAPIS:-$HOME/.cache/aip-proto/googleapis}"
if [[ ! -f "$gapis/google/api/annotations.proto" ]]; then
  command -v buf >/dev/null || die "googleapis protos missing in $gapis and buf is not installed.
  Install buf (https://buf.build/docs/installation) or set AIP_GOOGLEAPIS to a googleapis checkout."
  echo "aip-lint: fetching googleapis protos into $gapis ..." >&2
  mkdir -p "$gapis"
  buf export buf.build/googleapis/googleapis -o "$gapis" >&2 || die "buf export failed"
fi

# 3. Collect files, relative to the root so package/directory rules (AIP-191) apply.
cd "$root"
files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  while IFS= read -r f; do files+=("$f"); done < <(
    find . -name '*.proto' \
      -not -path '*/google/*' -not -path '*/third_party/*' \
      -not -path '*/node_modules/*' -not -path '*/vendor/*' | sed 's|^\./||' | sort)
fi
[[ ${#files[@]} -gt 0 ]] || die "no .proto files under $root"

config=()
for c in .api-linter.yaml api-linter.yaml .api-linter.json api-linter.json; do
  [[ -f "$c" ]] && { config=(--config "$c"); break; }
done

# 4. Run the linter.
"$linter" -I . -I "$gapis" "${config[@]}" "${strict[@]}" \
  --output-format json -o "$report" "${files[@]}" || die "api-linter failed (compile error?)"
"$linter" -I . -I "$gapis" "${config[@]}" "${strict[@]}" \
  --output-format summary "${files[@]}" >&2 || true

findings="$( (grep -o '"rule_id"' "$report" || true) | wc -l | tr -d ' ')"
echo "aip-lint: ${#files[@]} file(s), $findings finding(s). Report: $report" >&2

# 5. Optional wire/source compatibility check (AIP-180).
breaking=0
if [[ -n "$against" ]]; then
  command -v buf >/dev/null || die "--against needs buf on PATH"
  [[ -f buf.yaml ]] || die "--against needs a buf.yaml in $root"
  status=0
  buf breaking --against "$against" >&2 || status=$?
  case "$status" in
    0) ;;
    100) breaking=1 ;;   # buf: breaking changes found
    *) die "buf breaking failed (exit $status); check the --against input" ;;
  esac
fi

[[ "$findings" -eq 0 && "$breaking" -eq 0 ]]
