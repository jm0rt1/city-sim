#!/bin/sh
set -eu

PIPELINE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CITYSIM_BLENDER_BIN=${CITYSIM_BLENDER_BIN:-/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender}

"$CITYSIM_BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$PIPELINE_DIR/build_and_render.py"
"$CITYSIM_BLENDER_BIN" --background "$PIPELINE_DIR/example/copper_finch_house.blend" --python-exit-code 1 --python "$PIPELINE_DIR/validate_pipeline.py"
