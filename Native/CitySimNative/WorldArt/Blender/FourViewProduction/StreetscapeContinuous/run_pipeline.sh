#!/bin/sh
set -eu

BLENDER="${BLENDER:-/Applications/Blender-4.5.12-arm64.app/Contents/MacOS/Blender}"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

"$BLENDER" --background --factory-startup --python-exit-code 1 --python "$HERE/build_and_render.py"
"$BLENDER" --background --factory-startup --python-exit-code 1 --python "$HERE/validate.py" -- --report "$HERE/validation/validator-output.txt"
