#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SEALER="$SCRIPT_DIR/canonical_tree_digest.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/citysim-tree-digest.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

LEFT="$TEST_ROOT/left root/App.app"
RIGHT="$TEST_ROOT/right root/App.app"
mkdir -p "$LEFT/Contents/Resources/Nested" "$RIGHT/Contents/Resources/Nested"
printf 'binary-v1\n' >"$LEFT/Contents/MacOS"
printf 'asset-v1\n' >"$LEFT/Contents/Resources/Nested/asset.bin"
cp -R "$LEFT/." "$RIGHT/"

left_first="$(bash "$SEALER" "$LEFT")"
left_second="$(bash "$SEALER" "$LEFT")"
right_first="$(bash "$SEALER" "$RIGHT")"

[[ "$left_first" =~ ^[0-9a-f]{64}$ ]] \
  || { printf 'FAIL: digest is not SHA-256\n' >&2; exit 1; }
[[ "$left_first" == "$left_second" ]] \
  || { printf 'FAIL: repeated digest changed\n' >&2; exit 1; }
[[ "$left_first" == "$right_first" ]] \
  || { printf 'FAIL: absolute root leaked into digest\n' >&2; exit 1; }

printf 'asset-v2\n' >"$RIGHT/Contents/Resources/Nested/asset.bin"
right_changed="$(bash "$SEALER" "$RIGHT")"
[[ "$left_first" != "$right_changed" ]] \
  || { printf 'FAIL: byte change did not change digest\n' >&2; exit 1; }

cp "$LEFT/Contents/Resources/Nested/asset.bin" \
  "$RIGHT/Contents/Resources/Nested/renamed.bin"
rm "$RIGHT/Contents/Resources/Nested/asset.bin"
right_renamed="$(bash "$SEALER" "$RIGHT")"
[[ "$left_first" != "$right_renamed" ]] \
  || { printf 'FAIL: relative-path change did not change digest\n' >&2; exit 1; }

rg -q 'source "\$SCRIPT_DIR/canonical_tree_digest.sh"' "$SCRIPT_DIR/package_release.sh" \
  || { printf 'FAIL: release packager does not consume canonical producer\n' >&2; exit 1; }
if rg -q '^tree_digest\(\)' "$SCRIPT_DIR/package_release.sh"; then
  printf 'FAIL: release packager retains a competing local producer\n' >&2
  exit 1
fi
rg -q '"script/canonical_tree_digest.sh"' "$SCRIPT_DIR/package_release.sh" \
  || { printf 'FAIL: canonical producer is not a guarded release input\n' >&2; exit 1; }

printf 'PASS: canonical staged-app tree digest\n'
