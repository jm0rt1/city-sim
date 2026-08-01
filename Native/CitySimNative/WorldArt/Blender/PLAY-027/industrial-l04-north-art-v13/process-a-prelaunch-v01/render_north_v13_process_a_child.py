"""Sealed future child entrypoint.

This module intentionally has no Blender/bpy/subprocess/render imports.  A live
Process-A child may only be admitted by a later Integration-owned launcher and
grant; direct invocation is a hard failure before any output is touched.
"""

from __future__ import annotations

import sys


def main(argv: list[str] | None = None) -> int:
    del argv
    raise RuntimeError(
        "direct North v13 Process-A child invocation forbidden: "
        "Integration schedule, one-attempt lease, and authenticated grant are absent"
    )


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(78)
