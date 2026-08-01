"""Retired North v13 child surface; import and invocation are inert."""

from __future__ import annotations


RETIREMENT_STATE = "retired"


def main(argv: list[str] | None = None) -> int:
    """Reject direct or caller-authored child invocation before any side effect."""
    del argv
    raise RuntimeError(
        "North v13 process-a-prelaunch-v01 child is retired; no DCC child exists"
    )


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as exc:
        print(str(exc))
        raise SystemExit(78)
