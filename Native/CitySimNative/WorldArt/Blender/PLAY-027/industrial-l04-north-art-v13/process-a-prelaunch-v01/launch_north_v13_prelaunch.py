"""Retired North v13 prelaunch surface.

The former fixture authority, schedule, lease, signer, validator, and worker
launcher were retired as one sealed boundary.  This module is deliberately
inert: importing it performs no work and no callable can construct authority,
consume an attempt, start a child, write evidence, or touch a path.
"""

from __future__ import annotations


RETIREMENT_STATE = "retired"
SOURCE_AUTHORITY = False
PRODUCTION_SELECTED = False


def main(argv: list[str] | None = None) -> int:
    """Reject every historical invocation before any side effect."""
    del argv
    raise RuntimeError(
        "North v13 process-a-prelaunch-v01 is retired; no authority, consumer, "
        "launcher, child, or writer is available"
    )


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(str(exc))
        raise SystemExit(78)
