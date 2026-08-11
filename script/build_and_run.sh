#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
PACKAGE_EXECUTABLE_NAME="CitySimNative"
RESOURCE_BUNDLE_NAME="CitySimNative_CitySimNative.bundle"
PRODUCTION_BUNDLE_ID="com.jfmortensen.citysim"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PACKAGE_DIR="$ROOT_DIR/Native/CitySimNative"
DEFAULT_DIST_DIR="$ROOT_DIR/dist"
REQUESTED_DIST_DIR="${CITYSIM_DIST_DIR:-$DEFAULT_DIST_DIR}"
DIST_PARENT="$(dirname "$REQUESTED_DIST_DIR")"
DIST_BASENAME="$(basename "$REQUESTED_DIST_DIR")"

if [[ "$REQUESTED_DIST_DIR" != /* ]] || [[ "$DIST_BASENAME" == "." || "$DIST_BASENAME" == ".." ]]; then
  echo "error: CITYSIM_DIST_DIR must resolve from an absolute directory path" >&2
  exit 1
fi
if [[ ! -d "$DIST_PARENT" ]]; then
  echo "error: CITYSIM_DIST_DIR parent does not exist: $DIST_PARENT" >&2
  exit 1
fi
DIST_DIR="$(cd "$DIST_PARENT" && pwd -P)/$DIST_BASENAME"
case "$DIST_DIR" in
  /|"$ROOT_DIR"|"$PACKAGE_DIR"|"$ROOT_DIR/.git"|"$ROOT_DIR/.git/"*)
    echo "error: unsafe CITYSIM_DIST_DIR: $DIST_DIR" >&2
    exit 1
    ;;
esac

BUNDLE_SHORT_VERSION="${CITYSIM_BUNDLE_SHORT_VERSION:-1.0.0}"
BUNDLE_VERSION="${CITYSIM_BUNDLE_VERSION:-1}"
VERSION_PATTERN='^[0-9]+(\.[0-9]+){0,2}$'
if [[ ! "$BUNDLE_SHORT_VERSION" =~ $VERSION_PATTERN ]]; then
  echo "error: CITYSIM_BUNDLE_SHORT_VERSION must contain one to three numeric components" >&2
  exit 1
fi
if [[ ! "$BUNDLE_VERSION" =~ $VERSION_PATTERN ]]; then
  echo "error: CITYSIM_BUNDLE_VERSION must contain one to three numeric components" >&2
  exit 1
fi
BRANCH_NAME="$(git -C "$ROOT_DIR" branch --show-current)"
COMMIT_SHA="$(git -C "$ROOT_DIR" rev-parse HEAD)"

if [[ -z "$BRANCH_NAME" ]]; then
  echo "error: staged app identity requires an attached branch" >&2
  exit 1
fi

sanitize_lane() {
  printf '%s' "$1" \
    | LC_ALL=C tr '[:upper:]_/' '[:lower:]--' \
    | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

lane_display_name() {
  case "$1" in
    gameplay-loop) printf 'Gameplay' ;;
    world-rendering) printf 'World' ;;
    ui-input) printf 'UI' ;;
    simulation-platform) printf 'Simulation' ;;
    playtest-quality) printf 'Quality' ;;
    *) printf '%s' "$1" ;;
  esac
}

worktree_token() {
  printf '%s' "$ROOT_DIR" | shasum -a 256 | awk '{ print "w" substr($1, 1, 12) }'
}

if [[ "$BRANCH_NAME" == "master" ]]; then
  LANE_ID="master"
  WORKTREE_TOKEN="production"
  CANDIDATE_ID="master"
  APP_EXECUTABLE_NAME="$PACKAGE_EXECUTABLE_NAME"
  BUNDLE_ID="$PRODUCTION_BUNDLE_ID"
  DISPLAY_NAME="CitySim"
  APP_BUNDLE="$DIST_DIR/CitySim.app"
  if [[ "${CITYSIM_TEST_ISOLATION:-0}" == "1" ]]; then
    DATA_ROOT="$DIST_DIR/test-data/master"
  else
    DATA_ROOT=""
  fi
else
  LANE_SOURCE="${BRANCH_NAME#codex/citysim-}"
  LANE_ID="$(sanitize_lane "$LANE_SOURCE")"
  if [[ -z "$LANE_ID" ]]; then
    echo "error: branch '$BRANCH_NAME' does not produce a safe lane identifier" >&2
    exit 1
  fi
  WORKTREE_TOKEN="$(worktree_token)"
  CANDIDATE_ID="$LANE_ID-$WORKTREE_TOKEN"
  APP_EXECUTABLE_NAME="$PACKAGE_EXECUTABLE_NAME-$WORKTREE_TOKEN"
  BUNDLE_ID="$PRODUCTION_BUNDLE_ID.$LANE_ID.$WORKTREE_TOKEN"
  DISPLAY_NAME="CitySim [$(lane_display_name "$LANE_ID") $WORKTREE_TOKEN]"
  APP_BUNDLE="$DIST_DIR/CitySim-$CANDIDATE_ID.app"
  DATA_ROOT="$DIST_DIR/test-data/$CANDIDATE_ID"
fi

APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE_NAME"
STAGED_RESOURCE_BUNDLE="$APP_RESOURCES/$RESOURCE_BUNDLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MANIFEST_DIR="$DIST_DIR/manifests"
MANIFEST_PATH="$MANIFEST_DIR/$CANDIDATE_ID.manifest"
MANIFEST_DATA_ROOT="${DATA_ROOT:-production-default}"

print_identity() {
  printf 'branch=%s\n' "$BRANCH_NAME"
  printf 'commit=%s\n' "$COMMIT_SHA"
  printf 'worktree_root=%s\n' "$ROOT_DIR"
  printf 'worktree_token=%s\n' "$WORKTREE_TOKEN"
  printf 'candidate_id=%s\n' "$CANDIDATE_ID"
  printf 'bundle_identifier=%s\n' "$BUNDLE_ID"
  printf 'preference_domain=%s\n' "$BUNDLE_ID"
  printf 'display_name=%s\n' "$DISPLAY_NAME"
  printf 'bundle_short_version=%s\n' "$BUNDLE_SHORT_VERSION"
  printf 'bundle_version=%s\n' "$BUNDLE_VERSION"
  printf 'data_root=%s\n' "$MANIFEST_DATA_ROOT"
  printf 'staged_bundle_path=%s\n' "$APP_BUNDLE"
  printf 'executable_path=%s\n' "$APP_BINARY"
  printf 'resource_bundle_path=%s\n' "$STAGED_RESOURCE_BUNDLE"
  printf 'manifest_path=%s\n' "$MANIFEST_PATH"
}

write_manifest() {
  local status="$1"
  local launch_time="$2"
  local process_id="$3"

  mkdir -p "$MANIFEST_DIR"
  cat >"$MANIFEST_PATH" <<MANIFEST
branch=$BRANCH_NAME
commit=$COMMIT_SHA
worktree_root=$ROOT_DIR
worktree_token=$WORKTREE_TOKEN
candidate_id=$CANDIDATE_ID
bundle_identifier=$BUNDLE_ID
preference_domain=$BUNDLE_ID
display_name=$DISPLAY_NAME
bundle_short_version=$BUNDLE_SHORT_VERSION
bundle_version=$BUNDLE_VERSION
data_root=$MANIFEST_DATA_ROOT
launch_time=$launch_time
staged_bundle_path=$APP_BUNDLE
executable_path=$APP_BINARY
resource_bundle_path=$STAGED_RESOURCE_BUNDLE
process_id=$process_id
status=$status
MANIFEST
}

exact_process_ids() {
  local process_id
  local process_command

  while read -r process_id process_command; do
    if [[ "$process_command" == "$APP_BINARY" ]]; then
      printf '%s\n' "$process_id"
    fi
  done < <(ps -axo pid=,command=)
}

stop_exact_processes() {
  local process_id
  local process_ids

  process_ids="$(exact_process_ids)"
  [[ -z "$process_ids" ]] && return

  while read -r process_id; do
    [[ -n "$process_id" ]] && kill -TERM "$process_id"
  done <<<"$process_ids"

  for _ in {1..20}; do
    [[ -z "$(exact_process_ids)" ]] && return
    sleep 0.1
  done

  echo "error: exact staged process did not terminate: $APP_BINARY" >&2
  exit 1
}

launch_app() {
  if [[ -n "$DATA_ROOT" ]]; then
    mkdir -p "$DATA_ROOT"
    /usr/bin/open -n --env "CITYSIM_DATA_ROOT=$DATA_ROOT" "$APP_BUNDLE"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

wait_for_exact_process() {
  local process_id

  for _ in {1..50}; do
    process_id="$(exact_process_ids | head -n 1)"
    if [[ -n "$process_id" ]]; then
      printf '%s\n' "$process_id"
      return
    fi
    sleep 0.1
  done

  echo "error: exact staged process did not remain alive: $APP_BINARY" >&2
  exit 1
}

if [[ "$MODE" == "--print-identity" || "$MODE" == "print-identity" ]]; then
  print_identity
  exit 0
fi

stop_exact_processes

swift build --package-path "$PACKAGE_DIR"
BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)"
SOURCE_RESOURCE_BUNDLE="$BUILD_DIR/$RESOURCE_BUNDLE_NAME"

if [[ ! -d "$SOURCE_RESOURCE_BUNDLE" ]]; then
  echo "error: SwiftPM resource bundle is missing: $SOURCE_RESOURCE_BUNDLE" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_DIR/$PACKAGE_EXECUTABLE_NAME" "$APP_BINARY"
cp "$PACKAGE_DIR/Resources/CitySim-KeyArt.png" "$APP_RESOURCES/CitySim-KeyArt.png"
cp -R "$SOURCE_RESOURCE_BUNDLE" "$STAGED_RESOURCE_BUNDLE"
chmod +x "$APP_BINARY"

if [[ -e "$APP_BUNDLE/$RESOURCE_BUNDLE_NAME" ]]; then
  echo "error: SwiftPM resource bundle must not remain at the app root" >&2
  exit 1
fi

if [[ ! -f "$STAGED_RESOURCE_BUNDLE/WorldAssets.atlas/manifest.json" ]]; then
  echo "error: staged world atlas manifest is missing from $STAGED_RESOURCE_BUNDLE" >&2
  exit 1
fi

if [[ ! -f "$STAGED_RESOURCE_BUNDLE/WorldAssets.atlas/terrain_grass_0.png" ]]; then
  echo "error: staged world atlas probe is missing from $STAGED_RESOURCE_BUNDLE" >&2
  exit 1
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_EXECUTABLE_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$DISPLAY_NAME</string>
<key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
<key>CFBundleShortVersionString</key><string>$BUNDLE_SHORT_VERSION</string>
<key>CFBundleVersion</key><string>$BUNDLE_VERSION</string>
<key>CFBundleIconFile</key><string>CitySim-KeyArt.png</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict></plist>
PLIST

write_manifest "staged" "not-launched" "not-running"

case "$MODE" in
  run)
    launch_app
    PROCESS_ID="$(wait_for_exact_process)"
    write_manifest "running" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$PROCESS_ID"
    print_identity
    printf 'process_id=%s\n' "$PROCESS_ID"
    ;;
  --stage-only|stage-only)
    print_identity
    ;;
  --debug|debug)
    write_manifest "debugging" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "lldb"
    if [[ -n "$DATA_ROOT" ]]; then
      env CITYSIM_DATA_ROOT="$DATA_ROOT" lldb -- "$APP_BINARY"
    else
      lldb -- "$APP_BINARY"
    fi
    ;;
  --logs|logs)
    launch_app
    PROCESS_ID="$(wait_for_exact_process)"
    write_manifest "running-with-logs" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$PROCESS_ID"
    /usr/bin/log stream --info --style compact --predicate "processIdentifier == $PROCESS_ID"
    ;;
  --telemetry|telemetry)
    launch_app
    PROCESS_ID="$(wait_for_exact_process)"
    write_manifest "running-with-telemetry" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$PROCESS_ID"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\" && processIdentifier == $PROCESS_ID"
    ;;
  --verify|verify)
    launch_app
    PROCESS_ID="$(wait_for_exact_process)"
    write_manifest "verified-running" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$PROCESS_ID"
    print_identity
    printf 'process_id=%s\n' "$PROCESS_ID"
    ;;
  *)
    echo "usage: $0 [run|--stage-only|--debug|--logs|--telemetry|--verify|--print-identity]" >&2
    exit 2
    ;;
esac
