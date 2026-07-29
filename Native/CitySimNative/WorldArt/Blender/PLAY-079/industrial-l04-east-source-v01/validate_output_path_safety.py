#!/usr/bin/env python3
"""Disposable zero-pixel redirect tests for every PLAY-079 writer class."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import pathlib
import tempfile
from typing import Any

import east_output_safety as safety


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
EVIDENCE_PATH = (
    REPOSITORY_ROOT
    / "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
    "OUTPUT-PATH-SAFETY-VALIDATION.json"
)
PIXEL_EXTENSIONS = {
    ".bmp",
    ".exr",
    ".gif",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
}


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_file(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pixel_inventory() -> list[str]:
    roots = (SOURCE_ROOT, REPOSITORY_ROOT / safety.EVIDENCE_PREFIX)
    return sorted(
        str(path.relative_to(REPOSITORY_ROOT))
        for root in roots
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in PIXEL_EXTENSIONS
    )


def expect_code(callable_value: Any, code: str) -> dict[str, str]:
    try:
        callable_value()
    except safety.OutputSafetyRejected as error:
        if error.code != code:
            raise RuntimeError(
                f"expected {code}, got {error.code}: {error.detail}"
            ) from error
        return {"result": "REJECTED", "code": error.code}
    raise RuntimeError(f"expected rejection {code}")


def class_fixture(writer_class: str, root: pathlib.Path) -> tuple[safety.OutputPolicy, pathlib.Path]:
    relative = f"repo/{writer_class}/artifact.bin"
    policy = safety.OutputPolicy(root, {writer_class: frozenset({relative})})
    return policy, root / relative


def writer_class_negatives(writer_class: str, root: pathlib.Path) -> dict[str, Any]:
    payload = b"synthetic-zero-pixel-output-safety-fixture\n"

    parent_case = root / f"{writer_class}-parent"
    parent_case.mkdir()
    parent_policy, parent_target = class_fixture(writer_class, parent_case)
    redirect = parent_case / "redirect"
    redirect.mkdir()
    component = parent_case / "repo" / writer_class
    component.parent.mkdir(parents=True)
    component.symlink_to(redirect, target_is_directory=True)
    parent_symlink = expect_code(
        lambda: parent_policy.write_bytes_exclusive(parent_target, payload, writer_class),
        "output_symlink_component",
    )

    leaf_case = root / f"{writer_class}-leaf"
    leaf_case.mkdir()
    leaf_policy, leaf_target = class_fixture(writer_class, leaf_case)
    leaf_target.parent.mkdir(parents=True)
    leaf_target.symlink_to(leaf_case / "missing-target")
    dangling_leaf = expect_code(
        lambda: leaf_policy.write_bytes_exclusive(leaf_target, payload, writer_class),
        "output_symlink_component",
    )

    overwrite_case = root / f"{writer_class}-overwrite"
    overwrite_case.mkdir()
    overwrite_policy, overwrite_target = class_fixture(writer_class, overwrite_case)
    overwrite_target.parent.mkdir(parents=True)
    overwrite_target.write_bytes(b"preserve-me\n")
    overwrite = expect_code(
        lambda: overwrite_policy.write_bytes_exclusive(
            overwrite_target,
            payload,
            writer_class,
        ),
        "output_already_exists",
    )
    if overwrite_target.read_bytes() != b"preserve-me\n":
        raise RuntimeError(f"{writer_class}: overwrite target changed")

    race_case = root / f"{writer_class}-race"
    race_case.mkdir()
    race_policy, race_target = class_fixture(writer_class, race_case)
    race_target.parent.mkdir(parents=True)
    race_redirect = race_case / "redirect"
    race_redirect.mkdir()

    def redirect_after_first_check() -> None:
        os.rmdir(race_target.parent)
        race_target.parent.symlink_to(race_redirect, target_is_directory=True)

    prewrite_redirect = expect_code(
        lambda: race_policy.write_bytes_exclusive(
            race_target,
            payload,
            writer_class,
            pre_write_hook=redirect_after_first_check,
        ),
        "output_symlink_component",
    )
    if any(race_redirect.iterdir()):
        raise RuntimeError(f"{writer_class}: raced redirect received bytes")

    success_case = root / f"{writer_class}-success"
    success_case.mkdir()
    success_policy, success_target = class_fixture(writer_class, success_case)
    success_policy.write_bytes_exclusive(success_target, payload, writer_class)
    if success_target.read_bytes() != payload:
        raise RuntimeError(f"{writer_class}: descriptor-relative write mismatch")

    result = {
        "writerClass": writer_class,
        "parentSymlinkRedirect": parent_symlink,
        "danglingLeafSymlink": dangling_leaf,
        "preexistingLeafNoOverwrite": overwrite,
        "prewriteRedirectRecheck": prewrite_redirect,
        "positiveDescriptorRelativeWrite": "PASS",
    }
    if writer_class == "run_production":
        reserve_case = root / "run-production-reserve"
        reserve_case.mkdir()
        reserve_policy, reserve_target = class_fixture(writer_class, reserve_case)
        with reserve_policy.reserve_external_output(
            reserve_target,
            writer_class,
        ) as reserved_path:
            with reserved_path.open("r+b") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
        if reserve_target.read_bytes() != payload:
            raise RuntimeError("run_production: external reservation write mismatch")

        reserve_redirect_case = root / "run-production-reserve-redirect"
        reserve_redirect_case.mkdir()
        redirect_policy, redirect_target = class_fixture(
            writer_class,
            reserve_redirect_case,
        )
        redirect_target.parent.mkdir(parents=True)
        external_redirect = reserve_redirect_case / "redirect"
        external_redirect.mkdir()

        def redirect_external_before_reservation() -> None:
            os.rmdir(redirect_target.parent)
            redirect_target.parent.symlink_to(external_redirect, target_is_directory=True)

        def enter_redirected_reservation() -> None:
            with redirect_policy.reserve_external_output(
                redirect_target,
                writer_class,
                pre_write_hook=redirect_external_before_reservation,
            ):
                raise RuntimeError("redirected external reservation unexpectedly opened")

        result["externalWriterPrewriteRedirect"] = expect_code(
            enter_redirected_reservation,
            "output_symlink_component",
        )
        if any(external_redirect.iterdir()):
            raise RuntimeError("run_production: external redirect received bytes")
        result["externalWriterReservation"] = "PASS"
    return result


def static_writer_audit() -> dict[str, Any]:
    implementations = [
        (
            "prepare_launch_bound",
            "prepare_launch_bound.py",
            {"write_bytes_exclusive", "remove_created_output"},
        ),
        (
            "run_production",
            "run_production.py",
            {
            "ensure_output_parent",
            "reserve_external_output",
            "write_bytes_exclusive",
            },
        ),
        ("validation", "validate_launch_bound_cli.py", {"write_bytes_exclusive"}),
        ("validation", "validate_prelock.py", {"write_bytes_exclusive"}),
        ("source_candidate", "validate_source_outputs.py", {"write_bytes_exclusive"}),
    ]
    audited: list[dict[str, Any]] = []
    for writer_class, name, required_calls in implementations:
        path = SOURCE_ROOT / name
        tree = ast.parse(path.read_text(encoding="utf-8"))
        calls = {
            node.func.attr
            for node in ast.walk(tree)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
        }
        missing = sorted(required_calls - calls)
        if missing:
            raise RuntimeError(f"{name}: missing safety calls {missing}")
        audited.append(
            {
                "writerClass": writer_class,
                "path": str(path.relative_to(REPOSITORY_ROOT)),
                "requiredSafetyCalls": sorted(required_calls),
                "result": "PASS",
            }
        )
    return {
        "result": "PASS",
        "implementations": audited,
        "reservedOnlyClasses": [
            "normalization",
            "receipt",
            "review",
            "rejection",
        ],
        "reservedOnlyRule": "future implementations must use exact class identity through east_output_safety",
    }


def validate_production_identities() -> dict[str, Any]:
    expected_classes = {
        "prepare_launch_bound",
        "run_production",
        "validation",
        "normalization",
        "receipt",
        "review",
        "rejection",
        "source_candidate",
    }
    if set(safety.WRITER_IDENTITIES) != expected_classes:
        raise RuntimeError(
            f"writer class drift: {sorted(safety.WRITER_IDENTITIES)}"
        )
    records = [
        {
            "writerClass": writer_class,
            "path": relative,
            "identitySha256": hashlib.sha256(relative.encode("utf-8")).hexdigest(),
        }
        for writer_class, relatives in sorted(safety.WRITER_IDENTITIES.items())
        for relative in sorted(relatives)
    ]
    for record in records:
        safety._parts(record["path"])
        if not record["path"].startswith(safety.EVIDENCE_PREFIX):
            raise RuntimeError(f"output outside East evidence root: {record}")
    return {
        "result": "PASS",
        "writerClasses": sorted(expected_classes),
        "exactIdentityRecords": len(records),
        "records": records,
    }


def build_proof(repair_commit: str | None = None) -> dict[str, Any]:
    pixels_before = pixel_inventory()
    if pixels_before:
        raise RuntimeError(f"preexisting pixel files under East roots: {pixels_before}")
    with tempfile.TemporaryDirectory(prefix="play079-east-output-safety-") as temporary:
        sandbox = pathlib.Path(temporary)
        negatives = [
            writer_class_negatives(writer_class, sandbox)
            for writer_class in sorted(safety.WRITER_IDENTITIES)
        ]
    pixels_after = pixel_inventory()
    if pixels_after:
        raise RuntimeError(f"pixel files under East roots after tests: {pixels_after}")
    return {
        "schema": "citysim.play-079.east-output-path-safety-validation.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "branch": "codex/citysim-world-art-east",
        "result": "PASS",
        "authority": {
            "frozenStartingCandidate": "649ce1eb7ac4d76c89e0a7da9074f0dad3b91f23",
            "publishedMasterObservedWithoutSync": "9e5b4a59f7346cd89e7b9e9cd3bbc65643d66a24",
            "repairCommit": repair_commit,
            "authorityExpansion": False,
        },
        "codeBindings": {
            str((SOURCE_ROOT / "east_output_safety.py").relative_to(REPOSITORY_ROOT)): sha256_file(
                SOURCE_ROOT / "east_output_safety.py"
            ),
            str((SOURCE_ROOT / "prepare_launch_bound.py").relative_to(REPOSITORY_ROOT)): sha256_file(
                SOURCE_ROOT / "prepare_launch_bound.py"
            ),
            str((SOURCE_ROOT / "run_production.py").relative_to(REPOSITORY_ROOT)): sha256_file(
                SOURCE_ROOT / "run_production.py"
            ),
            str((SOURCE_ROOT / "validate_launch_bound_cli.py").relative_to(REPOSITORY_ROOT)): sha256_file(
                SOURCE_ROOT / "validate_launch_bound_cli.py"
            ),
            str((SOURCE_ROOT / "validate_prelock.py").relative_to(REPOSITORY_ROOT)): sha256_file(
                SOURCE_ROOT / "validate_prelock.py"
            ),
            str((SOURCE_ROOT / "validate_source_outputs.py").relative_to(REPOSITORY_ROOT)): sha256_file(
                SOURCE_ROOT / "validate_source_outputs.py"
            ),
        },
        "policy": {
            "exactLexicalIdentity": True,
            "approvedRoots": [safety.SOURCE_PREFIX, safety.EVIDENCE_PREFIX],
            "lstatEveryExistingComponent": True,
            "danglingLeafRejected": True,
            "directoryDescriptorTraversal": True,
            "noFollow": True,
            "noOverwrite": True,
            "preWriteRecheck": True,
            "externalWriterInodeVerification": True,
        },
        "identityAudit": validate_production_identities(),
        "staticWriterAudit": static_writer_audit(),
        "disposableRedirectTests": negatives,
        "invocations": {
            "blenderProcessLaunches": 0,
            "blenderRenderApiCalls": 0,
            "dccInvocations": 0,
            "imageGenInvocations": 0,
            "normalizerInvocations": 0,
            "contactSheetInvocations": 0,
            "renderInvocations": 0,
        },
        "pixelFiles": {"before": pixels_before, "after": pixels_after, "created": 0},
        "authorityExpansion": False,
        "sourceReady": False,
        "integrationAdmitted": False,
        "productionSelected": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-evidence", action="store_true")
    parser.add_argument("--check-evidence", action="store_true")
    parser.add_argument("--repair-commit")
    args = parser.parse_args()
    if args.write_evidence and args.check_evidence:
        raise RuntimeError("choose one evidence mode")
    if (args.write_evidence or args.check_evidence) and (
        args.repair_commit is None
        or len(args.repair_commit) != 40
        or any(character not in "0123456789abcdef" for character in args.repair_commit)
    ):
        raise RuntimeError("evidence mode requires exact --repair-commit")
    proof = build_proof(args.repair_commit)
    payload = canonical_bytes(proof)
    if args.write_evidence:
        safety.write_bytes_exclusive(EVIDENCE_PATH, payload, "validation")
    elif args.check_evidence:
        if EVIDENCE_PATH.read_bytes() != payload:
            raise RuntimeError(
                f"output safety evidence drift: {sha256_file(EVIDENCE_PATH)}"
            )
    print(payload.decode("utf-8"), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
