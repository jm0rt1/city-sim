#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BLENDER_BIN=${CITYSIM_BLENDER_BIN:-/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender}

"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$HERE/build_and_render.py"
"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$HERE/validate_outputs.py"
