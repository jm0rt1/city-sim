#!/bin/sh
set -eu

PIPELINE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CITYSIM_BLENDER_BIN=${CITYSIM_BLENDER_BIN:-/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender}
ASSET_ID=brickline_rowhouse_apartments
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/citysim-residential-expansion.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT HUP INT TERM

"$CITYSIM_BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$PIPELINE_DIR/build_and_render.py"
"$CITYSIM_BLENDER_BIN" --background "$PIPELINE_DIR/$ASSET_ID/$ASSET_ID.blend" --python-exit-code 1 --python "$PIPELINE_DIR/validate.py"
CITYSIM_OUTPUT_DIR="$TEMP_DIR" "$CITYSIM_BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$PIPELINE_DIR/build_and_render.py"

for view in camNE camSE camSW camNW; do
  cmp "$PIPELINE_DIR/$ASSET_ID/renders/${ASSET_ID}_${view}.png" "$TEMP_DIR/$ASSET_ID/renders/${ASSET_ID}_${view}.png"
done

echo "RESIDENTIAL_EXPANSION_DETERMINISTIC_PASS 4"
