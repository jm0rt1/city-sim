#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -n "${CITYSIM_BLENDER_BIN:-}" ]; then
  BLENDER_BIN="$CITYSIM_BLENDER_BIN"
elif [ -x /Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender ]; then
  BLENDER_BIN=/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender
else
  BLENDER_BIN=/usr/local/bin/blender
fi

"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$SCRIPT_DIR/build_and_render.py"
"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$SCRIPT_DIR/validate.py" -- --report "$SCRIPT_DIR/validation/validator-output.txt"
