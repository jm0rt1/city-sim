#!/bin/sh
set -eu
PIPELINE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BLENDER_BIN=${CITYSIM_BLENDER_BIN:-blender}
"$BLENDER_BIN" --background --factory-startup --python-exit-code 1 --python "$PIPELINE_DIR/render_expansion.py" -- --aggregate
for manifest in "$PIPELINE_DIR"/assets/*/manifest.json; do
  asset_dir=$(dirname "$manifest")
  "$BLENDER_BIN" --background "$asset_dir"/*.blend --python-exit-code 1 --python "$PIPELINE_DIR/validate_asset.py" -- "${asset_dir#$PIPELINE_DIR/}"
done
