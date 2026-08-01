"""Integration-owned child contract placeholder.

The worker can validate this entrypoint's identity, but direct execution is
always rejected.  Integration's later direct launcher is the only legal owner
of child construction, schedule/receipt consumption, and DCC execution.
"""

from __future__ import annotations

import sys


def main() -> int:
    raise RuntimeError("direct Process-A child invocation forbidden; Integration direct launch required")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(78)
