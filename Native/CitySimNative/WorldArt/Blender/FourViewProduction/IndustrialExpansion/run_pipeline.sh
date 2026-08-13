#!/bin/sh
set -eu

BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

"$BLENDER" --background --python "$HERE/build_and_render.py"
"$BLENDER" --background --python "$HERE/validate.py" -- --report "$HERE/validation/validator-output.txt"
