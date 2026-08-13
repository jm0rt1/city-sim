#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BLENDER_BIN=${CITYSIM_BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}

"$BLENDER_BIN" --background --factory-startup --python "$HERE/build_assets.py"
"$BLENDER_BIN" --background --factory-startup --python "$HERE/validate_assets.py"

RERENDER_DIR=$(mktemp -d /tmp/citysim-commercial-industrial-rerender.XXXXXX)
CITYSIM_OUTPUT_DIR="$RERENDER_DIR" "$BLENDER_BIN" --background --factory-startup --python "$HERE/build_assets.py"
python3 "$HERE/compare_renders.py" "$HERE" "$RERENDER_DIR"
rm -rf "$RERENDER_DIR"
printf '%s\n' 'COMMERCIAL_INDUSTRIAL_PRODUCTION_PASS'

