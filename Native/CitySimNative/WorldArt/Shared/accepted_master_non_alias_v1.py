#!/usr/bin/env python3
"""Load CitySim's exact accepted-master decoded-RGBA rejection set."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, FrozenSet


SCHEMA = "citysim.integration.accepted-building-non-alias-input.v1"
INPUT_PATH = (
    "docs/production/evidence/INTEGRATION/"
    "industrial-l04-accepted-master-non-alias-input-v1.json"
)
INPUT_SHA256 = "c281dd8f3527363ad3ff56746f50e9110b2166898bdf4918ed628b5a429d27fb"
INVENTORY_SHA256 = "9a5f561327ba5ed3a5178c03caae19d79204401b9b7dfd5c53ac716d2e6ab3af"
FORBIDDEN_SET_SHA256 = (
    "265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea"
)
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_DECODER = {
    "implementation": "ImageIO/CoreGraphics",
    "colorSpace": "sRGB",
    "bitsPerComponent": 8,
    "alphaInfo": "premultipliedLast",
    "byteOrder": "32Big",
}
EXPECTED_ENTRY_PROJECTION = {
    "logicalId": "masters[].logicalID",
    "sourceFile": "masters[].file",
    "fileSha256": "masters[].sha256Before",
    "decodedRgbaSha256": "masters[].decodedRGBASHA256",
    "entryOrder": "logicalId_ascii_ascending",
    "forbiddenDecodedRgbaSha256Order":
        "lowercase_hex_ascii_ascending_one_per_line_final_lf",
}
EXPECTED_FAIL_CLOSED = [
    "authority_input_sha_drift",
    "acceptance_candidate_or_disposition_mismatch",
    "shipping_count_not_40",
    "accepted_source_only_l3_not_exactly_north_east_south_west",
    "total_or_uniqueness_not_44",
    "missing_or_out_of_root_source",
    "source_file_sha_mismatch",
    "decoded_rgba_sha_mismatch",
    "decoder_binding_mismatch",
    "noncanonical_order_or_hex",
    "forbidden_set_sha_mismatch",
    "candidate_decoded_rgba_intersects_forbidden_set",
    "new_accepted_family_without_integration_republication",
]
EXPECTED_GRANTS = {
    "sourceAcceptance": False,
    "rendererAdmission": False,
    "productionSelection": False,
    "shippingActivation": False,
}


class NonAliasAuthorityError(ValueError):
    """Fail-closed common-input validation error."""

    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def _fail(code: str, detail: str) -> None:
    raise NonAliasAuthorityError(code, detail)


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path: Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _require_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail("SCHEMA_DRIFT", f"{label} must be an object")
    actual = set(value)
    if actual != expected:
        _fail(
            "SCHEMA_DRIFT",
            f"{label} keys differ; missing={sorted(expected - actual)} "
            f"unexpected={sorted(actual - expected)}",
        )
    return value


def _require_sha(value: Any, label: str) -> str:
    if not isinstance(value, str) or HEX_64.fullmatch(value) is None:
        _fail("NONCANONICAL_SHA256", label)
    return value


def _resolve_owned(repo_root: Path, relative_path: Any, label: str) -> Path:
    if not isinstance(relative_path, str) or not relative_path:
        _fail("SCHEMA_DRIFT", f"{label} must be a nonempty relative path")
    candidate = Path(relative_path)
    if candidate.is_absolute():
        _fail("PATH_OUTSIDE_REPOSITORY", f"{label}: {relative_path}")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root)
    except ValueError:
        _fail("PATH_OUTSIDE_REPOSITORY", f"{label}: {relative_path}")
    if not resolved.is_file():
        _fail("MISSING_AUTHORITY_INPUT", f"{label}: {relative_path}")
    return resolved


def _verify_file(
    repo_root: Path,
    relative_path: Any,
    expected_sha256: Any,
    label: str,
) -> Path:
    path = _resolve_owned(repo_root, relative_path, label)
    expected = _require_sha(expected_sha256, f"{label}.sha256")
    actual = _sha256_file(path)
    if actual != expected:
        _fail("AUTHORITY_INPUT_SHA_DRIFT", f"{label}: {actual} != {expected}")
    return path


def _verify_accepted_commit(repo_root: Path, commit: Any) -> None:
    if not isinstance(commit, str) or re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        _fail("INVALID_ACCEPTED_COMMIT", str(commit))
    exists = subprocess.run(
        ["git", "-C", str(repo_root), "cat-file", "-e", f"{commit}^{{commit}}"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if exists.returncode != 0:
        _fail("MISSING_ACCEPTED_COMMIT", commit)
    ancestor = subprocess.run(
        ["git", "-C", str(repo_root), "merge-base", "--is-ancestor", commit, "HEAD"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if ancestor.returncode != 0:
        _fail("ACCEPTED_COMMIT_NOT_ANCESTOR", commit)


def load_forbidden_decoded_rgba(
    repo_root: Path,
    input_path: Path | None = None,
) -> FrozenSet[str]:
    """Validate every bound authority and return exactly 44 decoded-RGBA hashes."""

    root = repo_root.resolve()
    canonical_input = (root / INPUT_PATH).resolve()
    requested_input = (input_path or canonical_input).resolve()
    if requested_input != canonical_input:
        _fail("NONCANONICAL_INPUT_PATH", str(requested_input))
    if _sha256_file(requested_input) != INPUT_SHA256:
        _fail("COMMON_INPUT_SHA_DRIFT", str(requested_input))

    payload = json.loads(requested_input.read_text(encoding="utf-8"))
    root_object = _require_keys(
        payload,
        {
            "schema",
            "disposition",
            "authoritative",
            "authorityInputs",
            "decoder",
            "counts",
            "entryProjection",
            "forbiddenDecodedRgbaSha256Count",
            "forbiddenSetSha256",
            "failClosed",
            "grants",
        },
        "commonInput",
    )
    if root_object["schema"] != SCHEMA:
        _fail("SCHEMA_DRIFT", "commonInput.schema")
    if root_object["disposition"] != "derived-validation-input":
        _fail("DISPOSITION_DRIFT", str(root_object["disposition"]))
    if root_object["authoritative"] is not False:
        _fail("AUTHORITY_ESCALATION", "common input became authoritative")
    if root_object["decoder"] != EXPECTED_DECODER:
        _fail("DECODER_BINDING_DRIFT", repr(root_object["decoder"]))
    if root_object["entryProjection"] != EXPECTED_ENTRY_PROJECTION:
        _fail("ENTRY_PROJECTION_DRIFT", repr(root_object["entryProjection"]))
    if root_object["failClosed"] != EXPECTED_FAIL_CLOSED:
        _fail("FAIL_CLOSED_POLICY_DRIFT", repr(root_object["failClosed"]))
    if root_object["grants"] != EXPECTED_GRANTS:
        _fail("AUTHORITY_GRANT_DRIFT", repr(root_object["grants"]))

    authorities = _require_keys(
        root_object["authorityInputs"],
        {
            "shippingManifest",
            "acceptedSourceOnlyFamilies",
            "generator",
            "derivedInventory",
        },
        "authorityInputs",
    )
    shipping = _require_keys(
        authorities["shippingManifest"], {"path", "sha256"}, "shippingManifest"
    )
    _verify_file(root, shipping["path"], shipping["sha256"], "shippingManifest")

    generator = _require_keys(
        authorities["generator"], {"path", "sha256"}, "generator"
    )
    _verify_file(root, generator["path"], generator["sha256"], "generator")

    accepted_families = authorities["acceptedSourceOnlyFamilies"]
    if not isinstance(accepted_families, list) or len(accepted_families) != 1:
        _fail("ACCEPTED_SOURCE_SCOPE_DRIFT", "expected exactly Industrial L3")
    accepted = _require_keys(
        accepted_families[0],
        {
            "family",
            "manifestPath",
            "manifestSha256",
            "acceptancePath",
            "acceptanceSha256",
            "acceptedCommit",
        },
        "acceptedSourceOnlyFamilies[0]",
    )
    if accepted["family"] != "industrial_l03":
        _fail("ACCEPTED_SOURCE_SCOPE_DRIFT", str(accepted["family"]))
    _verify_file(
        root,
        accepted["manifestPath"],
        accepted["manifestSha256"],
        "acceptedSourceManifest",
    )
    _verify_file(
        root,
        accepted["acceptancePath"],
        accepted["acceptanceSha256"],
        "acceptedSourceRecord",
    )
    _verify_accepted_commit(root, accepted["acceptedCommit"])

    inventory_binding = _require_keys(
        authorities["derivedInventory"], {"path", "sha256"}, "derivedInventory"
    )
    if inventory_binding["sha256"] != INVENTORY_SHA256:
        _fail("INVENTORY_AUTHORITY_DRIFT", str(inventory_binding["sha256"]))
    inventory_path = _verify_file(
        root,
        inventory_binding["path"],
        inventory_binding["sha256"],
        "derivedInventory",
    )
    inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
    inventory_object = _require_keys(
        inventory,
        {
            "acceptedMasterCount",
            "allAdmissionPathsInvoked",
            "allByteIdentical",
            "allRejectedByVersionGate",
            "contract",
            "masters",
            "pipeline",
            "taskID",
        },
        "derivedInventory",
    )
    if inventory_object["acceptedMasterCount"] != 44:
        _fail("MASTER_COUNT_DRIFT", str(inventory_object["acceptedMasterCount"]))
    if (
        inventory_object["allAdmissionPathsInvoked"] is not True
        or inventory_object["allByteIdentical"] is not True
        or inventory_object["allRejectedByVersionGate"] is not True
    ):
        _fail("INVENTORY_GATE_DRIFT", "one or more inventory gates are false")
    masters = inventory_object["masters"]
    if not isinstance(masters, list) or len(masters) != 44:
        _fail("MASTER_COUNT_DRIFT", str(len(masters) if isinstance(masters, list) else -1))

    logical_ids: set[str] = set()
    source_hashes: set[str] = set()
    decoded_hashes: set[str] = set()
    for index, master in enumerate(masters):
        item = _require_keys(
            master,
            {
                "byteIdentical",
                "decodedRGBASHA256",
                "file",
                "logicalID",
                "matteV2Admission",
                "sha256After",
                "sha256Before",
            },
            f"masters[{index}]",
        )
        if item["byteIdentical"] is not True:
            _fail("SOURCE_BYTE_IDENTITY_DRIFT", str(item["logicalID"]))
        logical_id = item["logicalID"]
        if not isinstance(logical_id, str) or not logical_id:
            _fail("INVALID_LOGICAL_ID", str(logical_id))
        before = _require_sha(item["sha256Before"], f"{logical_id}.sha256Before")
        after = _require_sha(item["sha256After"], f"{logical_id}.sha256After")
        decoded = _require_sha(
            item["decodedRGBASHA256"], f"{logical_id}.decodedRGBASHA256"
        )
        if before != after:
            _fail("SOURCE_BYTE_IDENTITY_DRIFT", logical_id)
        matte = _require_keys(
            item["matteV2Admission"],
            {"admissionInvoked", "name", "reason", "rejected"},
            f"{logical_id}.matteV2Admission",
        )
        if matte != {
            "admissionInvoked": True,
            "name": logical_id,
            "reason": "matte-canonicalization-v2 rejected: decoded RGBA hash",
            "rejected": True,
        }:
            _fail("MATTE_ADMISSION_POLICY_DRIFT", logical_id)
        source_path = _resolve_owned(root, item["file"], f"{logical_id}.file")
        if _sha256_file(source_path) != before:
            _fail("SOURCE_FILE_SHA_DRIFT", logical_id)
        if logical_id in logical_ids:
            _fail("DUPLICATE_LOGICAL_ID", logical_id)
        if before in source_hashes:
            _fail("DUPLICATE_SOURCE_FILE_HASH", logical_id)
        if decoded in decoded_hashes:
            _fail("DUPLICATE_DECODED_RGBA_HASH", logical_id)
        logical_ids.add(logical_id)
        source_hashes.add(before)
        decoded_hashes.add(decoded)

    expected_prefix_counts = {
        "residential_": 16,
        "commercial_": 16,
        "industrial_l01_": 4,
        "industrial_l02_": 4,
        "industrial_l03_": 4,
    }
    for prefix, expected_count in expected_prefix_counts.items():
        actual_count = sum(value.startswith(prefix) for value in logical_ids)
        if actual_count != expected_count:
            _fail(
                "LOGICAL_SCOPE_DRIFT",
                f"{prefix}: {actual_count} != {expected_count}",
            )

    counts = _require_keys(
        root_object["counts"],
        {"shippingDirectionalMasters", "acceptedSourceOnlyMasters", "total"},
        "counts",
    )
    if counts != {
        "shippingDirectionalMasters": 40,
        "acceptedSourceOnlyMasters": 4,
        "total": 44,
    }:
        _fail("COUNT_DECLARATION_DRIFT", repr(counts))
    if root_object["forbiddenDecodedRgbaSha256Count"] != 44:
        _fail("FORBIDDEN_COUNT_DRIFT", str(root_object["forbiddenDecodedRgbaSha256Count"]))
    if root_object["forbiddenSetSha256"] != FORBIDDEN_SET_SHA256:
        _fail("FORBIDDEN_SET_DECLARATION_DRIFT", str(root_object["forbiddenSetSha256"]))
    canonical_set = "".join(f"{value}\n" for value in sorted(decoded_hashes)).encode()
    actual_set_sha = _sha256_bytes(canonical_set)
    if actual_set_sha != FORBIDDEN_SET_SHA256:
        _fail(
            "FORBIDDEN_SET_SHA_DRIFT",
            f"{actual_set_sha} != {FORBIDDEN_SET_SHA256}",
        )
    return frozenset(decoded_hashes)


def main() -> int:
    default_root = Path(__file__).resolve().parents[4]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=default_root)
    parser.add_argument("--input", type=Path)
    args = parser.parse_args()
    forbidden = load_forbidden_decoded_rgba(args.repo_root, args.input)
    print(
        json.dumps(
            {
                "schema": SCHEMA,
                "result": "PASS",
                "forbiddenDecodedRgbaSha256Count": len(forbidden),
                "forbiddenSetSha256": FORBIDDEN_SET_SHA256,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
