#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

manifest_value() {
  local manifest="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$manifest"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TEST_ROOT="$(mktemp -d "/private/tmp/citysim-native-bundle-seal.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

DIST_DIR="$TEST_ROOT/dist"
BUILD_OUTPUT="$(CITYSIM_DIST_DIR="$DIST_DIR" "$ROOT_DIR/script/build_and_run.sh" --stage-only)"
MANIFEST_PATH="$(
  printf '%s\n' "$BUILD_OUTPUT" \
    | awk -F= '$1 == "manifest_path" { print substr($0, length($1) + 2); exit }'
)"
[[ -f "$MANIFEST_PATH" ]] || fail "staged manifest is missing"

APP_BUNDLE="$(manifest_value "$MANIFEST_PATH" staged_bundle_path)"
[[ -d "$APP_BUNDLE" ]] || fail "staged app bundle is missing"
[[ -f "$APP_BUNDLE/Contents/_CodeSignature/CodeResources" ]] \
  || fail "staged app-level CodeResources seal is missing"

codesign --verify --deep --strict --verbose=4 "$APP_BUNDLE"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1)"
[[ "$SIGNATURE_DETAILS" == *"Info.plist entries="* ]] \
  || fail "staged signature does not bind Info.plist"
[[ "$SIGNATURE_DETAILS" == *"Sealed Resources version="* ]] \
  || fail "staged signature does not report sealed resources"

printf 'CITYSIM_NATIVE_BUNDLE_SEAL status=PASS\n'
printf 'bundle=%s\n' "$APP_BUNDLE"
