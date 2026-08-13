#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BLENDER=${CITYSIM_BLENDER_BIN:-/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender}
PYTHON=${CITYSIM_PYTHON_BIN:-/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3}
"$BLENDER" --background --factory-startup --python "$HERE/build_and_render.py"
PYTHONPATH=/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python "$PYTHON" "$HERE/package_evidence.py"
for blend in "$HERE"/assets/*/*.blend "$HERE"/preview/*.blend; do "$BLENDER" --background "$blend" --python "$HERE/validate_blend.py"; done
PYTHONPATH=/Users/James/.cache/codex-runtimes/codex-primary-runtime/dependencies/python "$PYTHON" "$HERE/validate.py"
