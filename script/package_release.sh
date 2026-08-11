#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

sha256_file() {
  shasum -a 256 "$1" | awk '{ print $1 }'
}

tree_digest() {
  local root="$1"

  (
    cd "$root"
    find . -type f -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 shasum -a 256 \
      | shasum -a 256 \
      | awk '{ print $1 }'
  )
}

manifest_value() {
  local key="$1"
  local manifest="$2"
  local value

  if ! value="$(awk -v key="$key" '
    index($0, key "=") == 1 {
      count += 1
      value = substr($0, length(key) + 2)
    }
    END {
      if (count != 1) exit 2
      print value
    }
  ' "$manifest")"; then
    fail "manifest must contain exactly one $key entry: $manifest"
  fi
  printf '%s' "$value"
}

require_equal() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" != "$expected" ]]; then
    fail "$label mismatch: expected '$expected', observed '$actual'"
  fi
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PACKAGE_DIR="$ROOT_DIR/Native/CitySimNative"
BUILD_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
RESOURCE_BUNDLE_NAME="CitySimNative_CitySimNative.bundle"
DEFAULT_DIST_DIR="$ROOT_DIR/dist"
DEFAULT_APP="$DEFAULT_DIST_DIR/CitySim.app"
DEFAULT_MANIFEST="$DEFAULT_DIST_DIR/manifests/master.manifest"

if ! BRANCH_NAME="$(git -C "$ROOT_DIR" symbolic-ref --quiet --short HEAD)"; then
  fail "release packaging requires an attached branch"
fi
require_equal "branch" "master" "$BRANCH_NAME"

HEAD_SHA="$(git -C "$ROOT_DIR" rev-parse --verify 'HEAD^{commit}')"

if ! git -C "$ROOT_DIR" diff --quiet -- Native/CitySimNative script/build_and_run.sh; then
  fail "Native/CitySimNative and script/build_and_run.sh must match the index"
fi
if ! git -C "$ROOT_DIR" diff --cached --quiet -- Native/CitySimNative script/build_and_run.sh; then
  fail "Native/CitySimNative and script/build_and_run.sh must match HEAD in the index"
fi
UNTRACKED_INPUTS="$(
  git -C "$ROOT_DIR" ls-files --others --exclude-standard -- \
    Native/CitySimNative script/build_and_run.sh
)"
if [[ -n "$UNTRACKED_INPUTS" ]]; then
  fail "untracked release inputs are not allowed: $UNTRACKED_INPUTS"
fi

VERSION="${CITYSIM_BUNDLE_SHORT_VERSION:-1.0.0}"
BUILD_VERSION="${CITYSIM_BUNDLE_VERSION:-1}"
VERSION_PATTERN='^[0-9]+(\.[0-9]+){0,2}$'
if [[ ! "$VERSION" =~ $VERSION_PATTERN ]]; then
  fail "CITYSIM_BUNDLE_SHORT_VERSION must contain one to three numeric components"
fi
if [[ ! "$BUILD_VERSION" =~ $VERSION_PATTERN ]]; then
  fail "CITYSIM_BUNDLE_VERSION must contain one to three numeric components"
fi

ARCHITECTURE="$(uname -m)"
SHORT_HEAD="${HEAD_SHA:0:12}"
OUTPUT_BASE_REQUESTED="${CITYSIM_RELEASE_OUTPUT_DIR:-$DEFAULT_DIST_DIR/releases}"
if [[ "$OUTPUT_BASE_REQUESTED" != /* ]]; then
  fail "CITYSIM_RELEASE_OUTPUT_DIR must be an absolute path"
fi

mkdir -p "$OUTPUT_BASE_REQUESTED"
OUTPUT_BASE="$(cd "$OUTPUT_BASE_REQUESTED" && pwd -P)"
case "$OUTPUT_BASE" in
  /|"$ROOT_DIR"|"$PACKAGE_DIR"|"$ROOT_DIR/.git"|"$ROOT_DIR/.git/"*|"$DEFAULT_DIST_DIR")
    fail "unsafe release output directory: $OUTPUT_BASE"
    ;;
  "$ROOT_DIR"/*)
    case "$OUTPUT_BASE" in
      "$DEFAULT_DIST_DIR/releases"|"$DEFAULT_DIST_DIR/releases/"*) ;;
      *) fail "repository-local release output must remain under dist/releases" ;;
    esac
    ;;
esac

RELEASE_NAME="CitySim-$VERSION-$BUILD_VERSION-$ARCHITECTURE-$SHORT_HEAD"
RELEASE_DIR="$OUTPUT_BASE/$RELEASE_NAME"
STAGE_ROOT="$RELEASE_DIR/stage"
VERIFY_ROOT="$RELEASE_DIR/verification"
APP_BUNDLE="$STAGE_ROOT/CitySim.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/CitySimNative"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
RESOURCE_BUNDLE="$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE_NAME"
STAGE_MANIFEST="$STAGE_ROOT/manifests/master.manifest"

if [[ -e "$RELEASE_DIR" ]]; then
  fail "release output already exists; refusing overwrite: $RELEASE_DIR"
fi
mkdir "$RELEASE_DIR"
if [[ -e "$STAGE_ROOT" || -e "$VERIFY_ROOT" ]]; then
  fail "stage and verification roots must be fresh"
fi

DEFAULT_APP_DIGEST_BEFORE=""
DEFAULT_MANIFEST_SHA_BEFORE=""
if [[ -d "$DEFAULT_APP" ]]; then
  DEFAULT_APP_DIGEST_BEFORE="$(tree_digest "$DEFAULT_APP")"
fi
if [[ -f "$DEFAULT_MANIFEST" ]]; then
  DEFAULT_MANIFEST_SHA_BEFORE="$(sha256_file "$DEFAULT_MANIFEST")"
fi

CITYSIM_DIST_DIR="$STAGE_ROOT" \
CITYSIM_BUNDLE_SHORT_VERSION="$VERSION" \
CITYSIM_BUNDLE_VERSION="$BUILD_VERSION" \
  bash "$BUILD_SCRIPT" --stage-only

[[ -f "$STAGE_MANIFEST" ]] || fail "stage manifest is missing: $STAGE_MANIFEST"
[[ -x "$EXECUTABLE" ]] || fail "staged executable is missing: $EXECUTABLE"
[[ -d "$RESOURCE_BUNDLE" ]] || fail "nested SwiftPM resource bundle is missing"
[[ ! -e "$APP_BUNDLE/$RESOURCE_BUNDLE_NAME" ]] \
  || fail "SwiftPM resource bundle must not remain at the app root"

require_equal "manifest branch" "master" "$(manifest_value branch "$STAGE_MANIFEST")"
require_equal "manifest commit" "$HEAD_SHA" "$(manifest_value commit "$STAGE_MANIFEST")"
require_equal "manifest version" "$VERSION" \
  "$(manifest_value bundle_short_version "$STAGE_MANIFEST")"
require_equal "manifest build" "$BUILD_VERSION" \
  "$(manifest_value bundle_version "$STAGE_MANIFEST")"
require_equal "manifest app path" "$APP_BUNDLE" \
  "$(manifest_value staged_bundle_path "$STAGE_MANIFEST")"
require_equal "manifest executable path" "$EXECUTABLE" \
  "$(manifest_value executable_path "$STAGE_MANIFEST")"
require_equal "manifest resource path" "$RESOURCE_BUNDLE" \
  "$(manifest_value resource_bundle_path "$STAGE_MANIFEST")"
require_equal "manifest process" "not-running" \
  "$(manifest_value process_id "$STAGE_MANIFEST")"
require_equal "manifest status" "staged" "$(manifest_value status "$STAGE_MANIFEST")"

require_equal "Info.plist version" "$VERSION" \
  "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
require_equal "Info.plist build" "$BUILD_VERSION" \
  "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)"
SOURCE_RESOURCE_BUNDLE="$BUILD_DIR/$RESOURCE_BUNDLE_NAME"
[[ -d "$SOURCE_RESOURCE_BUNDLE" ]] \
  || fail "committed SwiftPM resource bundle is missing: $SOURCE_RESOURCE_BUNDLE"

ASSET_PATHS=(
  "WorldAssets.atlas/generated-v4-manifest.json"
  "WorldAssets.atlas/pages/block/page-00.png"
  "WorldAssets.atlas/pages/block/page-01.png"
  "WorldAssets.atlas/pages/block/page-02.png"
  "WorldAssets.atlas/pages/city/page-00.png"
  "WorldAssets.atlas/pages/neighborhood/page-00.png"
)

SOURCE_PAGE_COUNT="$(
  find "$SOURCE_RESOURCE_BUNDLE/WorldAssets.atlas/pages" -type f -name '*.png' \
    | wc -l \
    | tr -d '[:space:]'
)"
STAGED_PAGE_COUNT="$(
  find "$RESOURCE_BUNDLE/WorldAssets.atlas/pages" -type f -name '*.png' \
    | wc -l \
    | tr -d '[:space:]'
)"
require_equal "SwiftPM atlas page count" "5" "$SOURCE_PAGE_COUNT"
require_equal "staged atlas page count" "5" "$STAGED_PAGE_COUNT"

PAGE_HASH_PAIRS=()
for relative_path in "${ASSET_PATHS[@]}"; do
  source_path="$SOURCE_RESOURCE_BUNDLE/$relative_path"
  staged_path="$RESOURCE_BUNDLE/$relative_path"
  [[ -f "$source_path" ]] || fail "SwiftPM resource is missing: $relative_path"
  [[ -f "$staged_path" ]] || fail "staged resource is missing: $relative_path"
  cmp -s "$source_path" "$staged_path" \
    || fail "staged resource differs from SwiftPM bytes: $relative_path"
  PAGE_HASH_PAIRS+=("$relative_path=$(sha256_file "$staged_path")")
done

xattr -cr "$APP_BUNDLE"

SIGN_IDENTITY="${CITYSIM_SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  SIGNING_MODE="ad_hoc"
  SIGNING_IDENTITY_LABEL="ad-hoc"
else
  SIGNING_MODE="identity"
  SIGNING_IDENTITY_LABEL="$SIGN_IDENTITY"
fi

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=4 "$APP_BUNDLE"
SIGNATURE_CDHASH="$(
  codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 \
    | awk -F= '$1 == "CDHash" { print $2; exit }'
)"
[[ -n "$SIGNATURE_CDHASH" ]] || fail "signed app did not expose a CDHash"

RESOURCE_DIGEST="$(tree_digest "$RESOURCE_BUNDLE")"
APP_DIGEST="$(tree_digest "$APP_BUNDLE")"
STAGE_MANIFEST_SHA="$(sha256_file "$STAGE_MANIFEST")"
EXECUTABLE_SHA="$(sha256_file "$EXECUTABLE")"
INFO_PLIST_SHA="$(sha256_file "$INFO_PLIST")"
GENERATED_MANIFEST_SHA="$(sha256_file "$RESOURCE_BUNDLE/WorldAssets.atlas/generated-v4-manifest.json")"

if [[ "$SIGNING_MODE" == "ad_hoc" ]]; then
  ARCHIVE_BASENAME="CitySim-$VERSION-$ARCHITECTURE-local-signed.zip"
else
  ARCHIVE_BASENAME="CitySim-$VERSION-$ARCHITECTURE-signed.zip"
fi
ARCHIVE_PATH="$RELEASE_DIR/$ARCHIVE_BASENAME"
CHECKSUM_PATH="$ARCHIVE_PATH.sha256"

[[ ! -e "$ARCHIVE_PATH" ]] || fail "archive path must be fresh: $ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$ARCHIVE_BASENAME" >"$ARCHIVE_BASENAME.sha256"
  shasum -a 256 -c "$ARCHIVE_BASENAME.sha256"
)
ARCHIVE_SHA="$(sha256_file "$ARCHIVE_PATH")"

mkdir "$VERIFY_ROOT"
ditto -x -k "$ARCHIVE_PATH" "$VERIFY_ROOT"
EXTRACTED_APP="$VERIFY_ROOT/CitySim.app"
[[ -d "$EXTRACTED_APP" ]] || fail "archive did not extract CitySim.app"
codesign --verify --deep --strict --verbose=4 "$EXTRACTED_APP"

EXTRACTED_RESOURCE_BUNDLE="$EXTRACTED_APP/Contents/Resources/$RESOURCE_BUNDLE_NAME"
[[ -d "$EXTRACTED_RESOURCE_BUNDLE" ]] \
  || fail "extracted app is missing its nested resource bundle"
[[ ! -e "$EXTRACTED_APP/$RESOURCE_BUNDLE_NAME" ]] \
  || fail "extracted app contains a root-level resource bundle"
require_equal "extracted resource digest" "$RESOURCE_DIGEST" \
  "$(tree_digest "$EXTRACTED_RESOURCE_BUNDLE")"
require_equal "extracted app digest" "$APP_DIGEST" "$(tree_digest "$EXTRACTED_APP")"

if [[ -d "$DEFAULT_APP" ]]; then
  require_equal "default app preservation" "$DEFAULT_APP_DIGEST_BEFORE" \
    "$(tree_digest "$DEFAULT_APP")"
fi
if [[ -f "$DEFAULT_MANIFEST" ]]; then
  require_equal "default manifest preservation" "$DEFAULT_MANIFEST_SHA_BEFORE" \
    "$(sha256_file "$DEFAULT_MANIFEST")"
fi

RELEASE_MANIFEST="$RELEASE_DIR/release-manifest.json"
python3 - "$RELEASE_MANIFEST" "$HEAD_SHA" "$VERSION" "$BUILD_VERSION" \
  "$ARCHITECTURE" "$SIGNING_MODE" "$SIGNING_IDENTITY_LABEL" \
  "$STAGE_MANIFEST" "$STAGE_MANIFEST_SHA" "$APP_BUNDLE" "$EXECUTABLE_SHA" \
  "$INFO_PLIST_SHA" "$GENERATED_MANIFEST_SHA" "$RESOURCE_DIGEST" "$APP_DIGEST" \
  "$ARCHIVE_PATH" "$ARCHIVE_SHA" "$CHECKSUM_PATH" "$EXTRACTED_APP" \
  "$SIGNATURE_CDHASH" "$DEFAULT_APP_DIGEST_BEFORE" "$DEFAULT_MANIFEST_SHA_BEFORE" \
  "${PAGE_HASH_PAIRS[@]}" <<'PY'
import json
import sys

(
    output_path,
    head,
    version,
    build,
    architecture,
    signing_mode,
    signing_identity,
    stage_manifest_path,
    stage_manifest_sha256,
    app_path,
    executable_sha256,
    info_plist_sha256,
    generated_manifest_sha256,
    resource_tree_sha256,
    app_tree_sha256,
    archive_path,
    archive_sha256,
    checksum_path,
    extracted_app_path,
    signature_cdhash,
    default_app_tree_sha256,
    default_manifest_sha256,
    *page_pairs,
) = sys.argv[1:]

atlas_pages = dict(pair.split("=", 1) for pair in page_pairs[1:])
generated_manifest_pair = page_pairs[0].split("=", 1)

payload = {
    "schemaVersion": 1,
    "product": "CitySim",
    "head": head,
    "version": version,
    "build": build,
    "architecture": architecture,
    "signing": {
        "mode": signing_mode,
        "identity": signing_identity,
        "cdhash": signature_cdhash,
        "strictDeepVerified": True,
        "notarization": "not_requested",
    },
    "paths": {
        "app": app_path,
        "stageManifest": stage_manifest_path,
        "archive": archive_path,
        "archiveChecksum": checksum_path,
        "extractedApp": extracted_app_path,
    },
    "hashes": {
        "stageManifestSha256": stage_manifest_sha256,
        "executableSha256": executable_sha256,
        "infoPlistSha256": info_plist_sha256,
        "generatedManifestSha256": generated_manifest_sha256,
        "resourceTreeSha256": resource_tree_sha256,
        "appTreeSha256": app_tree_sha256,
        "archiveSha256": archive_sha256,
        "atlasPages": atlas_pages,
        "defaultAppTreeBeforeAndAfterSha256": default_app_tree_sha256,
        "defaultManifestBeforeAndAfterSha256": default_manifest_sha256,
    },
    "generatedManifest": {
        "path": generated_manifest_pair[0],
        "sha256": generated_manifest_pair[1],
    },
    "verification": {
        "resourceBundleLocation": "Contents/Resources/CitySimNative_CitySimNative.bundle",
        "rootResourceBundleAbsent": True,
        "extractedResourceDigestMatches": True,
        "extractedAppDigestMatches": True,
    },
}

with open(output_path, "x", encoding="utf-8") as output:
    json.dump(payload, output, sort_keys=True, separators=(",", ":"))
    output.write("\n")
PY

RELEASE_MANIFEST_SHA="$(sha256_file "$RELEASE_MANIFEST")"

printf 'release_dir=%s\n' "$RELEASE_DIR"
printf 'head=%s\n' "$HEAD_SHA"
printf 'version=%s\n' "$VERSION"
printf 'build=%s\n' "$BUILD_VERSION"
printf 'signing_mode=%s\n' "$SIGNING_MODE"
printf 'app_path=%s\n' "$APP_BUNDLE"
printf 'app_tree_sha256=%s\n' "$APP_DIGEST"
printf 'resource_tree_sha256=%s\n' "$RESOURCE_DIGEST"
printf 'archive_path=%s\n' "$ARCHIVE_PATH"
printf 'archive_sha256=%s\n' "$ARCHIVE_SHA"
printf 'checksum_path=%s\n' "$CHECKSUM_PATH"
printf 'release_manifest=%s\n' "$RELEASE_MANIFEST"
printf 'release_manifest_sha256=%s\n' "$RELEASE_MANIFEST_SHA"
printf 'extracted_app=%s\n' "$EXTRACTED_APP"
