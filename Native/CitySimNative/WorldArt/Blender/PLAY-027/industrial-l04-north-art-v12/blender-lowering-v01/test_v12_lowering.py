#!/usr/bin/env python3
"""Focused pure-data adversaries for the PLAY-027 v12 lowering boundary."""

from __future__ import annotations

import argparse
import copy
import json
import os
import tempfile
from pathlib import Path
from typing import Any, Callable

from lower_v12_scene import (
    RUN_NEUTRAL_FILES,
    canonical_bytes,
    ensure_absent_output_root,
    exclusive_write_json,
    load_json,
    lower_scene,
    sha256,
    sha256_bytes,
    split_t_junction_edges,
)


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    return parser.parse_args()


def copy_bound_inputs(
    source_root: Path,
    destination_root: Path,
    contract: dict[str, Any],
) -> None:
    for key in (
        "claim", "authority", "scene", "materials", "bridge",
        "compoundAuditTool", "analyticReplayIdentity", "compoundAudit",
        "compoundAdversaries", "compoundDisposition", "replayPreservation",
    ):
        relative = Path(contract[key]["file"])
        destination = destination_root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes((source_root / relative).read_bytes())


def run_adversary(
    repository_root: Path,
    contract: dict[str, Any],
    name: str,
    mutate: Callable[[dict[str, Any], dict[str, Any]], None],
    expected_fragment: str,
) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(
        prefix=f"citysim-play027-v12-{name}-",
        dir="/private/tmp",
    ) as temporary:
        root = Path(temporary)
        local_contract = copy.deepcopy(contract)
        copy_bound_inputs(repository_root, root, local_contract)
        scene_path = root / local_contract["scene"]["file"]
        material_path = root / local_contract["materials"]["file"]
        scene = load_json(scene_path)
        materials = load_json(material_path)
        mutate(scene, materials)
        scene_path.write_bytes(canonical_bytes(scene))
        material_path.write_bytes(canonical_bytes(materials))
        local_contract["scene"]["sha256"] = sha256(scene_path)
        local_contract["materials"]["sha256"] = sha256(material_path)
        try:
            lower_scene(root, local_contract)
        except RuntimeError as error:
            message = str(error)
            if expected_fragment not in message:
                raise RuntimeError(
                    f"{name}: wrong failure: expected {expected_fragment!r}, "
                    f"got {message!r}"
                ) from error
            return {
                "name": name,
                "expectedFailure": expected_fragment,
                "actualFailure": message,
                "passed": True,
            }
        raise RuntimeError(f"{name}: adversary was accepted")


def component(scene: dict[str, Any], identifier: str) -> dict[str, Any]:
    return next(item for item in scene["components"] if item["id"] == identifier)


def expected_failure(
    name: str,
    operation: Callable[[], None],
    expected_fragment: str,
) -> dict[str, Any]:
    try:
        operation()
    except RuntimeError as error:
        message = str(error)
        if expected_fragment not in message:
            raise RuntimeError(
                f"{name}: wrong failure: expected {expected_fragment!r}, "
                f"got {message!r}"
            ) from error
        return {
            "name": name,
            "expectedFailure": expected_fragment,
            "actualFailure": expected_fragment,
            "passed": True,
        }
    raise RuntimeError(f"{name}: adversary was accepted")


def main() -> None:
    options = arguments()
    repository_root = Path(options.repository_root).resolve(strict=True)
    contract_path = Path(options.contract).resolve(strict=True)
    contract = load_json(contract_path)
    evidence_root = repository_root / contract["evidenceRoot"]
    pure_a = evidence_root / "pure-a"
    pure_b = evidence_root / "pure-b"
    if not pure_a.is_dir() or not pure_b.is_dir():
        raise RuntimeError("both sealed pure replay roots are required")
    first = {name: sha256(pure_a / name) for name in RUN_NEUTRAL_FILES}
    second = {name: sha256(pure_b / name) for name in RUN_NEUTRAL_FILES}
    if first != second:
        raise RuntimeError("pure replay inventory mismatch")

    cases = [
        run_adversary(
            repository_root, contract, "unsupported-shape",
            lambda scene, _: component(
                scene, "north-v09-foundation"
            ).update({"shape": "sphere"}),
            "unsupported physical shape",
        ),
        run_adversary(
            repository_root, contract, "extra-component-field",
            lambda scene, _: component(
                scene, "north-v09-foundation"
            ).update({"unauthorized": True}),
            "unsupported or extra component fields",
        ),
        run_adversary(
            repository_root, contract, "prism-face-order",
            lambda scene, _: component(
                scene, "v12-west-pier-camera-reveal"
            )["faces"][0].reverse(),
            "authorized triangular-prism mesh/order drift",
        ),
        run_adversary(
            repository_root, contract, "duplicate-physical-id",
            lambda scene, _: scene["components"][1].update({
                "id": scene["components"][0]["id"]
            }),
            "duplicate physical component ID",
        ),
        run_adversary(
            repository_root, contract, "unresolved-material",
            lambda scene, _: component(
                scene, "north-v09-foundation"
            ).update({"materialID": "missing-material"}),
            "unresolved materials",
        ),
        run_adversary(
            repository_root, contract, "semantic-owner-split",
            lambda scene, _: component(
                scene, "v12-west-pier-camera-reveal"
            ).update({"semanticOwnerID": "unauthorized-owner"}),
            "semantic owner drift",
        ),
        run_adversary(
            repository_root, contract, "compound-interface-gap",
            lambda scene, _: component(
                scene, "v12-portal-inset-west-lower"
            ).update({"position": [14.25, 5.5, -9.9]}),
            "exactly one interface face required",
        ),
        run_adversary(
            repository_root, contract, "compound-interface-overlap",
            lambda scene, _: component(
                scene, "v12-portal-inset-west-lower"
            ).update({"dimensions": [4.5, 10.0, 0.5]}),
            "removed area drift",
        ),
        run_adversary(
            repository_root, contract, "nonfinite-coordinate",
            lambda scene, _: component(
                scene, "north-v09-foundation"
            )["position"].__setitem__(0, float("nan")),
            "non-finite coordinate",
        ),
        run_adversary(
            repository_root, contract, "compound-material-split",
            lambda scene, _: component(
                scene, "v12-portal-inset-west-lower"
            ).update({"materialID": "v09-charcoal-steel"}),
            "semantic compound material split",
        ),
    ]
    # The basis adversary changes the task-local contract rather than source JSON.
    basis_contract = copy.deepcopy(contract)
    basis_contract["bridge"]["formula"] = "B(x,y,z)=(x,y,z)"
    cases.append(expected_failure(
        "coordinate-basis-drift",
        lambda: lower_scene(repository_root, basis_contract),
        "coordinate basis contract drift",
    ))
    vertices = [[0.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.0, 1.0, 0.0]]
    _, non_manifold = split_t_junction_edges(vertices, [[0, 1, 2]])
    if non_manifold != 3:
        raise RuntimeError("non-manifold unit adversary did not localize 3 edges")
    cases.append({
        "name": "non-manifold-open-triangle",
        "expectedFailure": "non-manifold edge count greater than zero",
        "actualFailure": f"non-manifold edge count {non_manifold}",
        "passed": True,
    })
    with tempfile.TemporaryDirectory(
        prefix="citysim-play027-v12-writer-",
        dir="/private/tmp",
    ) as temporary:
        root = Path(temporary)
        cases.append(expected_failure(
            "unexpected-generated-file",
            lambda: exclusive_write_json(root, "UNEXPECTED.json", {}),
            "unapproved pure output",
        ))
        preexisting = root / "preexisting"
        preexisting.mkdir()
        cases.append(expected_failure(
            "preexisting-output-root",
            lambda: ensure_absent_output_root(preexisting),
            "output root must be absent",
        ))
        target = root / "target"
        target.mkdir()
        symlink = root / "symlink"
        symlink.symlink_to(target, target_is_directory=True)
        cases.append(expected_failure(
            "symlink-output-root",
            lambda: ensure_absent_output_root(symlink),
            "output root must be absent",
        ))
        cases.append(expected_failure(
            "relative-output-root",
            lambda: ensure_absent_output_root(Path("relative-output")),
            "absolute output root required",
        ))
    result = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": contract["stage"],
        "pureReplayCount": 2,
        "pureReplayFileCount": len(RUN_NEUTRAL_FILES),
        "pureReplayInventoriesEqual": True,
        "pureReplayInventory": first,
        "adversarialCaseCount": len(cases),
        "adversaries": cases,
        "allAdversariesRejected": all(case["passed"] for case in cases),
        "renderInvocationCount": 0,
        "pixelFiles": [],
        "sourceAuthority": False,
        "candidateReadyForIndependentReview": False,
        "productionSelected": False,
    }
    output = evidence_root / "ADVERSARIAL-RESULTS.json"
    if output.exists() or output.is_symlink():
        raise RuntimeError("adversarial evidence output must be absent")
    descriptor = os.open(
        output,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL
        | (os.O_NOFOLLOW if hasattr(os, "O_NOFOLLOW") else 0),
        0o644,
    )
    try:
        os.write(descriptor, canonical_bytes(result))
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    print(json.dumps({
        "adversarialCaseCount": len(cases),
        "allAdversariesRejected": True,
        "outputSHA256": sha256_bytes(canonical_bytes(result)),
        "pureReplayInventoriesEqual": True,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
