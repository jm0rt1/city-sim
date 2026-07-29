#!/usr/bin/env python3
"""Emit a deterministic PLAY-075 fixture-materialization plan receipt.

This tool never creates or modifies a CitySim save. It validates exact,
caller-declared candidate and packet identities, binds them to the immutable
L3 fixture, and writes one preparation-only receipt beneath a caller-supplied
PLAY-075 evidence root.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, NoReturn


PREREG_ROOT = Path(__file__).resolve().parent.parent
PLAY075_ROOT = PREREG_ROOT.parent
FIXTURE_PATH = PREREG_ROOT / "fixtures" / "industrial-l03-directional-mature-city-v1.json"
MANIFEST_PATH = (
    PREREG_ROOT
    / "fixtures"
    / "industrial-l03-directional-mature-city-manifest-v1.json"
)
FIXTURE_RELATIVE_PATH = (
    "docs/production/evidence/PLAY-075/"
    "industrial-l4-family-preregistration-v1/fixtures/"
    "industrial-l03-directional-mature-city-v1.json"
)
FIXTURE_SHA256 = "b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5"
FIXTURE_STATE_DIGEST = "dbe6860011f43063a39e228531db4b49303d64a918e7884301b3de80360dd97f"
BRIDGE_AUTHORITY = "3e01ca6738d7574718f9aeff4b66771eee109feb"
BRIDGE_MAPPING_SHA256 = (
    "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
)
PUBLISHED_MASTER = "72a4c15f7ca747e4c6bc3c7fcf80b0e865b7ccc4"
ARRIVAL_AUTHORITY = (
    "docs/production/evidence/INTEGRATION/"
    "INDUSTRIAL-L04-ARRIVAL-GATE-PREP-AUTHORITY.md"
)
RECEIPT_NAME = "FIXTURE-MATERIALIZATION-RECEIPT.json"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
REQUEST_ID = re.compile(r"^[a-z0-9][a-z0-9._-]{2,127}$")
DIRECTIONS = ("north", "east", "south", "west")
SOURCE_SOCKETS = {
    "north": [896, 704],
    "east": [896, 832],
    "south": [640, 832],
    "west": [640, 704],
}


class MaterializerError(Exception):
    """A fail-closed request or output error with a stable code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def fail(code: str, message: str) -> NoReturn:
    raise MaterializerError(code, message)


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require_object(value: Any, label: str) -> Dict[str, Any]:
    if not isinstance(value, dict):
        fail("SCHEMA_DRIFT", f"{label} must be an object")
    return value


def require_exact_keys(
    value: Dict[str, Any], required: Iterable[str], label: str
) -> None:
    required_set = set(required)
    actual_set = set(value)
    if actual_set != required_set:
        missing = sorted(required_set - actual_set)
        extra = sorted(actual_set - required_set)
        fail(
            "SCHEMA_DRIFT",
            f"{label} keys differ; missing={missing}, extra={extra}",
        )


def require_hex(value: Any, pattern: re.Pattern[str], label: str) -> str:
    if not isinstance(value, str) or not pattern.fullmatch(value):
        fail("MUTABLE_OR_INEXACT_IDENTITY", f"{label} must be exact lowercase hex")
    return value


def verify_frozen_fixture() -> Dict[str, Any]:
    if sha256_file(FIXTURE_PATH) != FIXTURE_SHA256:
        fail("FROZEN_FIXTURE_DRIFT", "immutable L3 fixture SHA-256 changed")
    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail("FROZEN_FIXTURE_DRIFT", f"fixture manifest unreadable: {error}")
    if (
        manifest.get("fixture_sha256") != FIXTURE_SHA256
        or manifest.get("state_digest") != FIXTURE_STATE_DIGEST
    ):
        fail("FROZEN_FIXTURE_DRIFT", "fixture manifest identity changed")
    placements = manifest.get("placements")
    if not isinstance(placements, list) or len(placements) != 4:
        fail("FROZEN_FIXTURE_DRIFT", "fixture manifest must contain four placements")
    observed = {
        item.get("direction"): item.get("source_pixel_socket")
        for item in placements
        if isinstance(item, dict)
    }
    if observed != SOURCE_SOCKETS:
        fail("FROZEN_FIXTURE_DRIFT", "runtime direction/socket mapping changed")
    return manifest


def validate_request(request: Any) -> Dict[str, Any]:
    request = require_object(request, "request")
    require_exact_keys(
        request,
        (
            "schemaVersion",
            "mode",
            "requestId",
            "baseFixture",
            "rendererCandidate",
            "directionBridge",
            "packets",
        ),
        "request",
    )
    if request["schemaVersion"] != 1:
        fail("SCHEMA_DRIFT", "schemaVersion must equal 1")
    if request["mode"] not in ("candidate_bound", "contract_rehearsal"):
        fail("SCHEMA_DRIFT", "mode must be candidate_bound or contract_rehearsal")
    if not isinstance(request["requestId"], str) or not REQUEST_ID.fullmatch(
        request["requestId"]
    ):
        fail("MUTABLE_OR_INEXACT_IDENTITY", "requestId is not immutable")

    base = require_object(request["baseFixture"], "baseFixture")
    require_exact_keys(
        base, ("path", "sha256", "stateDigest", "immutable"), "baseFixture"
    )
    if (
        base["path"] != FIXTURE_RELATIVE_PATH
        or base["sha256"] != FIXTURE_SHA256
        or base["stateDigest"] != FIXTURE_STATE_DIGEST
        or base["immutable"] is not True
    ):
        fail("FROZEN_FIXTURE_DRIFT", "request does not bind the immutable fixture")

    candidate = require_object(request["rendererCandidate"], "rendererCandidate")
    require_exact_keys(
        candidate,
        (
            "commit",
            "admittedCommit",
            "admissionAuthorityCommit",
            "clean",
            "exact",
            "stale",
        ),
        "rendererCandidate",
    )
    candidate_commit = require_hex(candidate["commit"], HEX40, "candidate commit")
    admitted_commit = require_hex(
        candidate["admittedCommit"], HEX40, "admitted candidate commit"
    )
    require_hex(
        candidate["admissionAuthorityCommit"], HEX40, "admission authority commit"
    )
    if candidate_commit != admitted_commit or candidate["stale"] is not False:
        fail("STALE_CANDIDATE", "candidate differs from exact admitted candidate")
    if candidate["clean"] is not True or candidate["exact"] is not True:
        fail("MUTABLE_OR_INEXACT_IDENTITY", "candidate must be exact and clean")

    bridge = require_object(request["directionBridge"], "directionBridge")
    require_exact_keys(
        bridge,
        (
            "acceptedSourceAuthority",
            "mappingSha256",
            "coordinateSystem",
            "sourceOrder",
            "perDirectionTransforms",
            "dccLabelsUsed",
        ),
        "directionBridge",
    )
    if (
        bridge["acceptedSourceAuthority"] != BRIDGE_AUTHORITY
        or bridge["mappingSha256"] != BRIDGE_MAPPING_SHA256
        or bridge["coordinateSystem"] != "citysim_source_pixels_v1"
        or bridge["sourceOrder"] != [0, 1, 2, 3]
    ):
        fail("STALE_OR_UNBOUND_BRIDGE", "bridge identity or source order differs")
    if bridge["perDirectionTransforms"] is not False:
        fail("PER_DIRECTION_TRANSFORM", "per-direction transforms are forbidden")
    if bridge["dccLabelsUsed"] is not False:
        fail("DCC_LABEL_INPUT", "DCC or Blender labels are forbidden")

    packets = request["packets"]
    if not isinstance(packets, list) or len(packets) != 4:
        fail("ATOMIC_4_OF_4_REQUIRED", "exactly four direction packets are required")
    by_direction: Dict[str, Dict[str, Any]] = {}
    packet_commits: List[str] = []
    packet_hashes: List[str] = []
    for index, item in enumerate(packets):
        packet = require_object(item, f"packets[{index}]")
        require_exact_keys(
            packet,
            (
                "direction",
                "packetCommit",
                "packetSha256",
                "boundPacketSha256",
                "rendererCandidateCommit",
                "coordinateLabelSystem",
                "sourcePixelSocket",
                "aliasOf",
                "fallback",
                "perDirectionTransform",
            ),
            f"packets[{index}]",
        )
        direction = packet["direction"]
        if direction not in DIRECTIONS or direction in by_direction:
            fail("ATOMIC_4_OF_4_REQUIRED", "directions must be unique exact N/E/S/W")
        packet_commit = require_hex(
            packet["packetCommit"], HEX40, f"{direction} packet commit"
        )
        packet_hash = require_hex(
            packet["packetSha256"], HEX64, f"{direction} packet SHA-256"
        )
        bound_hash = require_hex(
            packet["boundPacketSha256"], HEX64, f"{direction} bound packet SHA-256"
        )
        if packet_hash != bound_hash:
            fail("UNBOUND_PACKET_HASH", f"{direction} packet hash is unbound")
        if packet["rendererCandidateCommit"] != candidate_commit:
            fail("STALE_CANDIDATE", f"{direction} packet binds another candidate")
        if packet["coordinateLabelSystem"] != "runtime_cardinal":
            fail("DCC_LABEL_INPUT", f"{direction} uses a non-runtime direction label")
        if packet["sourcePixelSocket"] != SOURCE_SOCKETS[direction]:
            fail("RUNTIME_SOCKET_MISMATCH", f"{direction} source socket differs")
        if packet["aliasOf"] is not None or packet["fallback"] is not False:
            fail("ALIAS_OR_FALLBACK", f"{direction} packet is alias/fallback")
        if packet["perDirectionTransform"] is not False:
            fail("PER_DIRECTION_TRANSFORM", f"{direction} transform is forbidden")
        by_direction[direction] = packet
        packet_commits.append(packet_commit)
        packet_hashes.append(packet_hash)
    if tuple(by_direction) != DIRECTIONS:
        fail("ATOMIC_4_OF_4_REQUIRED", "packet order must be N/E/S/W")
    if len(set(packet_commits)) != 4 or len(set(packet_hashes)) != 4:
        fail("ALIAS_OR_FALLBACK", "packet commits and hashes must be unique")

    verify_frozen_fixture()
    return request


def expected_capture_tree() -> List[str]:
    paths: List[str] = []
    per_direction = (
        "city-color.png",
        "city-grayscale.png",
        "neighborhood-color.png",
        "neighborhood-grayscale.png",
        "block-color.png",
        "block-grayscale.png",
        "selected-pointer.png",
        "selected-keyboard.png",
        "details.ax.txt",
    )
    for width in ("regular", "compact"):
        for direction in DIRECTIONS:
            for name in per_direction:
                paths.append(f"live/{width}/{direction}/{name}")
    paths.extend(
        (
            "live/regular/family-city.png",
            "live/compact/family-city.png",
            "live/regular/construction-north.png",
            "live/compact/construction-north.png",
            "live/regular/condition-west.png",
            "live/compact/condition-west.png",
            "live/regular/demolished.png",
            "live/regular/undo-restored.png",
            "live/reduce-motion/compact-three-lods.png",
            "live/accessibility/fka.png",
            "live/accessibility/voiceover.txt",
            "live/comparison/l3-vs-l4-regular.png",
            "live/comparison/l3-vs-l4-compact.png",
            "live/comparison/l3-vs-l4-grayscale.png",
        )
    )
    return paths


def build_receipt(request: Dict[str, Any]) -> Dict[str, Any]:
    manifest = verify_frozen_fixture()
    candidate = request["rendererCandidate"]["commit"]
    packets = [
        {
            "direction": packet["direction"],
            "packetCommit": packet["packetCommit"],
            "packetSha256": packet["packetSha256"],
            "rendererCandidateCommit": packet["rendererCandidateCommit"],
            "coordinateLabelSystem": packet["coordinateLabelSystem"],
            "sourcePixelSocket": packet["sourcePixelSocket"],
        }
        for packet in request["packets"]
    ]
    completed_changes = [
        {
            "direction": placement["direction"],
            "stateCoordinate": placement["state_coordinate"],
            "fromLevel": 3,
            "toLevel": 4,
        }
        for placement in manifest["placements"]
    ]
    plan_common = {
        "baseFixtureSha256": FIXTURE_SHA256,
        "rendererCandidateCommit": candidate,
        "packetSha256ByDirection": {
            packet["direction"]: packet["packetSha256"] for packet in packets
        },
    }
    plans = []
    for name, additional_change in (
        ("completed", None),
        (
            "construction",
            {
                "direction": "north",
                "field": "constructionProgress",
                "value": 0.5,
            },
        ),
        (
            "condition",
            {"direction": "west", "field": "condition", "value": 0.3},
        ),
    ):
        plan = {
            **plan_common,
            "name": name,
            "levelChanges": completed_changes,
            "additionalChange": additional_change,
            "saveBytesCreated": False,
            "actualFixtureIdentity": "NOT_MATERIALIZED",
        }
        plan["bindingSha256"] = sha256_bytes(canonical_bytes(plan))
        plans.append(plan)

    request_hash = sha256_bytes(canonical_bytes(request))
    receipt: Dict[str, Any] = {
        "schemaVersion": 1,
        "receiptType": "PLAY-075_CANDIDATE_NEUTRAL_FIXTURE_MATERIALIZATION_PLAN",
        "disposition": "PREPARATION_RECEIPT_ONLY",
        "mode": request["mode"],
        "request": {
            "requestId": request["requestId"],
            "canonicalSha256": request_hash,
        },
        "authority": {
            "publishedMaster": PUBLISHED_MASTER,
            "arrivalGateAuthority": ARRIVAL_AUTHORITY,
            "claim": "PLAY-075",
        },
        "baseFixture": {
            "path": FIXTURE_RELATIVE_PATH,
            "sha256": FIXTURE_SHA256,
            "stateDigest": FIXTURE_STATE_DIGEST,
            "immutable": True,
        },
        "rendererCandidate": {
            "commit": candidate,
            "admittedCommit": request["rendererCandidate"]["admittedCommit"],
            "admissionAuthorityCommit": request["rendererCandidate"][
                "admissionAuthorityCommit"
            ],
            "declaredInputSyntacticallyExactAndNonStale": True,
            "candidateOrPacketExistenceVerified": False,
            "eligibleForFutureFixtureMaterialization": request["mode"]
            == "candidate_bound",
            "gitOrProductInspectionPerformed": False,
        },
        "directionBridge": {
            "acceptedSourceAuthority": BRIDGE_AUTHORITY,
            "mappingSha256": BRIDGE_MAPPING_SHA256,
            "coordinateSystem": "citysim_source_pixels_v1",
            "sourceOrder": [0, 1, 2, 3],
            "perDirectionTransforms": False,
            "dccLabelsUsed": False,
        },
        "atomicDirectionGate": {
            "requiredDirections": list(DIRECTIONS),
            "receivedDirections": [packet["direction"] for packet in packets],
            "status": "INPUT_IDENTITIES_BOUND_4_OF_4",
            "oneThroughThreeDirectionsAccepted": False,
            "packets": packets,
        },
        "derivativePlans": plans,
        "expectedCaptureTree": expected_capture_tree(),
        "sideEffects": {
            "fixtureFilesWritten": [],
            "sourceFixtureMutated": False,
            "productOrResourcesMutated": False,
            "appBuiltStagedRunOrScored": False,
            "qaDispositionDeclared": False,
        },
    }
    receipt["canonicalPayloadSha256"] = sha256_bytes(canonical_bytes(receipt))
    return receipt


def ensure_task_owned_output(output_root: Path) -> Path:
    task_root = PLAY075_ROOT.resolve()
    resolved = output_root.resolve(strict=False)
    if resolved != task_root and task_root not in resolved.parents:
        fail(
            "OUTPUT_OUTSIDE_TASK_ROOT",
            f"output must be beneath caller-owned {task_root}",
        )
    resolved.mkdir(parents=True, exist_ok=True)
    if resolved.is_symlink():
        fail("OUTPUT_OUTSIDE_TASK_ROOT", "output root may not be a symlink")
    if resolved != task_root and task_root not in resolved.resolve().parents:
        fail("OUTPUT_OUTSIDE_TASK_ROOT", "resolved output escaped task root")
    return resolved


def write_receipt(receipt: Dict[str, Any], output_root: Path) -> Path:
    root = ensure_task_owned_output(output_root)
    path = root / RECEIPT_NAME
    payload = canonical_bytes(receipt)
    if path.exists():
        if path.read_bytes() != payload:
            fail("OUTPUT_CONFLICT", f"existing receipt differs: {path}")
        return path
    path.write_bytes(payload)
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        request = json.loads(args.request.read_text(encoding="utf-8"))
        validated = validate_request(request)
        receipt = build_receipt(validated)
        output = write_receipt(receipt, args.output_root)
    except (OSError, json.JSONDecodeError) as error:
        print(
            json.dumps({"status": "REJECTED", "code": "INPUT_ERROR", "error": str(error)}),
            file=sys.stderr,
        )
        return 2
    except MaterializerError as error:
        print(
            json.dumps(
                {"status": "REJECTED", "code": error.code, "error": str(error)},
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2
    print(
        json.dumps(
            {
                "status": "PREPARATION_RECEIPT_ONLY",
                "output": str(output),
                "sha256": sha256_file(output),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
