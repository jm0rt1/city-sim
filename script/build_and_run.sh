#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_EXECUTABLE_NAME="CitySimNative"
PRODUCTION_BUNDLE_ID="com.jfmortensen.citysim"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/Native/CitySimNative"
DIST_DIR="$ROOT_DIR/dist"
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

if [[ "$BRANCH_NAME" == "master" ]]; then
  LANE_ID="master"
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
  BUNDLE_ID="$PRODUCTION_BUNDLE_ID.$LANE_ID"
  DISPLAY_NAME="CitySim [$(lane_display_name "$LANE_ID")]"
  APP_BUNDLE="$DIST_DIR/CitySim-$LANE_ID.app"
  DATA_ROOT="$DIST_DIR/test-data/$LANE_ID"
fi

APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_EXECUTABLE_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MANIFEST_DIR="$DIST_DIR/manifests"
MANIFEST_PATH="$MANIFEST_DIR/$LANE_ID.manifest"
MANIFEST_DATA_ROOT="${DATA_ROOT:-production-default}"

print_identity() {
  printf 'branch=%s\n' "$BRANCH_NAME"
  printf 'commit=%s\n' "$COMMIT_SHA"
  printf 'bundle_identifier=%s\n' "$BUNDLE_ID"
  printf 'display_name=%s\n' "$DISPLAY_NAME"
  printf 'data_root=%s\n' "$MANIFEST_DATA_ROOT"
  printf 'staged_bundle_path=%s\n' "$APP_BUNDLE"
  printf 'executable_path=%s\n' "$APP_BINARY"
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
bundle_identifier=$BUNDLE_ID
display_name=$DISPLAY_NAME
data_root=$MANIFEST_DATA_ROOT
launch_time=$launch_time
staged_bundle_path=$APP_BUNDLE
executable_path=$APP_BINARY
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

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_DIR/$APP_EXECUTABLE_NAME" "$APP_BINARY"
cp "$PACKAGE_DIR/Resources/CitySim-KeyArt.png" "$APP_RESOURCES/CitySim-KeyArt.png"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_EXECUTABLE_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>$DISPLAY_NAME</string>
<key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
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
