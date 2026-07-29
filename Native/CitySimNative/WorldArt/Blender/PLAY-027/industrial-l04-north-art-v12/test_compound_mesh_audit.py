#!/usr/bin/env python3
"""Focused no-render tests for the PLAY-027 v12 compound mesh audit."""

from __future__ import annotations

import json
from pathlib import Path

import audit_compound_mesh as audit


def main() -> None:
    source_root = Path(__file__).resolve().parent
    scene = json.loads((source_root / "SCENE.json").read_text(encoding="utf-8"))
    canonical = audit.audit_scene(scene)
    if not canonical["passed"]:
        raise RuntimeError("canonical compound mesh audit failed")
    if canonical["remainingInternalFaceArea"] != 0.0:
        raise RuntimeError("canonical internal face area remains")
    if canonical["removedInternalFaceFragmentCount"] != 6:
        raise RuntimeError("expected six removed opposing face fragments")
    adversarial = audit.run_adversarial(scene)
    if not adversarial["allAdversarialCasesRejected"]:
        raise RuntimeError("an adversarial geometry was accepted")
    if not adversarial["literalTrueCannotPass"]:
        raise RuntimeError("literal true bypassed the mechanical audit")
    print(
        "PASS",
        canonical["removedInternalFaceArea"],
        adversarial["caseCount"],
    )


if __name__ == "__main__":
    main()
