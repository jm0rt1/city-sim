#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: $0 <candidate-worktree-one> <candidate-worktree-two>" >&2
  exit 64
}

[[ "$#" -eq 2 ]] || usage

canonical_root() {
  (cd "$1" && pwd -P)
}

manifest_value() {
  local manifest="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$manifest"
}

output_value() {
  local output="$1"
  local key="$2"
  printf '%s\n' "$output" | awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }'
}

require_value() {
  local label="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "error: missing $label" >&2
    exit 1
  fi
}

assert_equal() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "error: $label mismatch: expected '$expected', found '$actual'" >&2
    exit 1
  fi
}

assert_distinct() {
  local label="$1"
  local first="$2"
  local second="$3"
  require_value "first $label" "$first"
  require_value "second $label" "$second"
  if [[ "$first" == "$second" ]]; then
    echo "error: candidate identity collision for $label: '$first'" >&2
    exit 1
  fi
}

verify_manifest() {
  local expected_root="$1"
  local manifest="$2"
  local bundle_path executable_path process_id plist bundle_id display_name executable_name

  [[ -f "$manifest" ]] || {
    echo "error: candidate manifest does not exist: $manifest" >&2
    exit 1
  }

  assert_equal "manifest worktree root" "$expected_root" "$(manifest_value "$manifest" worktree_root)"

  bundle_path="$(manifest_value "$manifest" staged_bundle_path)"
  executable_path="$(manifest_value "$manifest" executable_path)"
  process_id="$(manifest_value "$manifest" process_id)"
  plist="$bundle_path/Contents/Info.plist"
  require_value "staged bundle path" "$bundle_path"
  require_value "executable path" "$executable_path"
  require_value "process id" "$process_id"
  [[ -d "$bundle_path" ]] || {
    echo "error: staged bundle does not exist: $bundle_path" >&2
    exit 1
  }
  [[ -x "$executable_path" ]] || {
    echo "error: staged executable does not exist: $executable_path" >&2
    exit 1
  }
  [[ -f "$plist" ]] || {
    echo "error: Info.plist does not exist: $plist" >&2
    exit 1
  }

  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")"
  display_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$plist")"
  executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
  assert_equal "bundle identifier" "$(manifest_value "$manifest" bundle_identifier)" "$bundle_id"
  assert_equal "preference domain" "$bundle_id" "$(manifest_value "$manifest" preference_domain)"
  assert_equal "display name" "$(manifest_value "$manifest" display_name)" "$display_name"
  assert_equal "executable name" "$(basename "$executable_path")" "$executable_name"

  kill -0 "$process_id" 2>/dev/null || {
    echo "error: candidate process is not alive: $process_id" >&2
    exit 1
  }
  assert_equal "exact process command" "$executable_path" "$(ps -p "$process_id" -o command= | sed 's/^[[:space:]]*//')"
}

ROOT_ONE="$(canonical_root "$1")"
ROOT_TWO="$(canonical_root "$2")"
assert_distinct "worktree root" "$ROOT_ONE" "$ROOT_TWO"

for candidate_root in "$ROOT_ONE" "$ROOT_TWO"; do
  [[ -x "$candidate_root/script/build_and_run.sh" ]] || {
    echo "error: missing executable build script in $candidate_root" >&2
    exit 1
  }
done

OUTPUT_ONE="$("$ROOT_ONE/script/build_and_run.sh" --verify)"
printf '%s\n' "$OUTPUT_ONE"
MANIFEST_ONE="$(output_value "$OUTPUT_ONE" manifest_path)"
require_value "first manifest path" "$MANIFEST_ONE"

OUTPUT_TWO="$("$ROOT_TWO/script/build_and_run.sh" --verify)"
printf '%s\n' "$OUTPUT_TWO"
MANIFEST_TWO="$(output_value "$OUTPUT_TWO" manifest_path)"
require_value "second manifest path" "$MANIFEST_TWO"

verify_manifest "$ROOT_ONE" "$MANIFEST_ONE"
verify_manifest "$ROOT_TWO" "$MANIFEST_TWO"

assert_equal "candidate branch" "$(manifest_value "$MANIFEST_ONE" branch)" "$(manifest_value "$MANIFEST_TWO" branch)"
assert_equal "candidate commit" "$(manifest_value "$MANIFEST_ONE" commit)" "$(manifest_value "$MANIFEST_TWO" commit)"
if [[ "$(manifest_value "$MANIFEST_ONE" branch)" == "master" ]]; then
  echo "error: production master keeps its canonical identity; isolation proof requires a worker branch" >&2
  exit 1
fi

for key in worktree_token candidate_id bundle_identifier preference_domain display_name data_root staged_bundle_path executable_path; do
  assert_distinct "$key" "$(manifest_value "$MANIFEST_ONE" "$key")" "$(manifest_value "$MANIFEST_TWO" "$key")"
done
assert_distinct "manifest_path" "$MANIFEST_ONE" "$MANIFEST_TWO"
assert_distinct "process_id" "$(manifest_value "$MANIFEST_ONE" process_id)" "$(manifest_value "$MANIFEST_TWO" process_id)"

printf 'CITYSIM_CANDIDATE_ISOLATION status=PASS\n'
printf 'candidate_one=%s pid=%s manifest=%s\n' \
  "$(manifest_value "$MANIFEST_ONE" candidate_id)" \
  "$(manifest_value "$MANIFEST_ONE" process_id)" \
  "$MANIFEST_ONE"
printf 'candidate_two=%s pid=%s manifest=%s\n' \
  "$(manifest_value "$MANIFEST_TWO" candidate_id)" \
  "$(manifest_value "$MANIFEST_TWO" process_id)" \
  "$MANIFEST_TWO"
