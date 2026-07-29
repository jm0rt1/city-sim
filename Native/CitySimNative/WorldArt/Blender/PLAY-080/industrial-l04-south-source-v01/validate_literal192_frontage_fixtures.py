#!/usr/bin/env python3
"""Validate South literal-192/frontage fixtures without DCC or pixel APIs."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import stat
from typing import Any


SOURCE_DIR = Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_DIR.parents[5]
DEFAULT_FIXTURES = SOURCE_DIR / "literal192-frontage-adversarial-fixtures-v01.json"
HEX_12 = re.compile(r"^[0-9a-f]{12}$")
HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")

EXPECTED_INPUT_ROLES = {
    "acceptedSouthMaterials",
    "acceptedSouthScene",
    "literal192Proof",
    "runnerContract",
    "zeroPixelHandoff",
}
EXPECTED_CASES = {
    "south-socket-drift": (
        "SOUTH_SOCKET_DRIFT",
        "/registration/canonicalCitySimSouthSocket",
    ),
    "registration-error-above-0.001": (
        "REGISTRATION_ERROR_ABOVE_TOLERANCE",
        "/registration/maximumErrorSourcePixels",
    ),
    "portal-occlusion": (
        "PORTAL_OCCLUSION",
        "/literal192/processOcclusionPixels",
    ),
    "insufficient-silhouette-structure": (
        "INSUFFICIENT_SILHOUETTE_STRUCTURE",
        "/literal192/silhouetteBreaks",
    ),
    "wrong-bridge-basis": (
        "WRONG_BRIDGE_BASIS",
        "/bridgeBasis/matrixRows",
    ),
    "malformed-toolchain-fingerprint": (
        "MALFORMED_TOOLCHAIN_FINGERPRINT",
        "/toolchainFingerprint/blenderExecutableSha256",
    ),
}


class FixtureRejected(RuntimeError):
    """A fail-closed fixture or semantic rejection."""

    def __init__(self, code: str, details: Any = None):
        super().__init__(code)
        self.code = code
        self.details = details


def reject(code: str, details: Any = None) -> None:
    raise FixtureRejected(code, details)


def reject_nonfinite(value: str) -> None:
    reject("NONFINITE_JSON_NUMBER", value)


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            reject("DUPLICATE_JSON_KEY", key)
        result[key] = value
    return result


def load_json_bytes(raw: bytes, label: str) -> dict[str, Any]:
    try:
        value = json.loads(
            raw.decode("utf-8"),
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_nonfinite,
        )
    except UnicodeDecodeError as error:
        reject("INVALID_UTF8", {"label": label, "error": str(error)})
    except json.JSONDecodeError as error:
        reject("MALFORMED_JSON", {"label": label, "error": str(error)})
    if not isinstance(value, dict):
        reject("JSON_ROOT_NOT_OBJECT", label)
    return value


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def require_exact_keys(
    value: dict[str, Any], expected: set[str], label: str
) -> None:
    actual = set(value)
    if actual != expected:
        reject(
            "OBJECT_KEYS_MISMATCH",
            {
                "label": label,
                "missing": sorted(expected - actual),
                "extra": sorted(actual - expected),
            },
        )


def safe_regular_repo_file(display_path: str) -> tuple[Path, bytes]:
    if not isinstance(display_path, str):
        reject("UNSAFE_INPUT_PATH", display_path)
    pure = PurePosixPath(display_path)
    if (
        pure.is_absolute()
        or not pure.parts
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        reject("UNSAFE_INPUT_PATH", display_path)

    current = REPOSITORY_ROOT
    for index, part in enumerate(pure.parts):
        current = current / part
        try:
            mode = os.lstat(current).st_mode
        except FileNotFoundError:
            reject("INPUT_MISSING", display_path)
        if stat.S_ISLNK(mode):
            reject("INPUT_SYMLINK", current.relative_to(REPOSITORY_ROOT).as_posix())
        if index < len(pure.parts) - 1 and not stat.S_ISDIR(mode):
            reject("INPUT_PARENT_NOT_DIRECTORY", display_path)
    if not stat.S_ISREG(os.lstat(current).st_mode):
        reject("INPUT_NOT_REGULAR", display_path)
    return current, current.read_bytes()


def require_number(value: Any, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        reject("INVALID_NUMBER", label)
    number = float(value)
    if not math.isfinite(number):
        reject("NONFINITE_NUMBER", label)
    return number


def require_vector(value: Any, expected: list[float], code: str) -> None:
    if (
        not isinstance(value, list)
        or len(value) != len(expected)
        or any(
            require_number(actual, code) != expected[index]
            for index, actual in enumerate(value)
        )
    ):
        reject(code, {"expected": expected, "actual": value})


def derive_baseline(inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    runner = inputs["runnerContract"]
    proof = inputs["literal192Proof"]
    handoff = inputs["zeroPixelHandoff"]
    bridge = runner["coordinateBridge"]
    registration = runner["invariants"]["registration"]
    render = runner["invariants"]["render"]
    metrics = proof["metrics"]
    thresholds = proof["thresholds"]
    camera = handoff["cameraAndSocket"]

    return {
        "boundary": {
            "blenderProcessLaunches": proof["blenderProcessLaunches"],
            "blenderRenderApiCalls": proof["blenderRenderApiCalls"],
            "contactSheetInvocations": proof["contactSheetInvocations"],
            "imageGenInvocations": proof["imageGenInvocations"],
            "normalizerInvocations": proof["normalizerInvocations"],
            "pixelFiles": proof["pixelFiles"],
            "processA": proof["processA"],
            "processB": proof["processB"],
            "processC": proof["processC"],
            "productionSelected": proof["productionSelected"],
            "renderInvocations": proof["renderInvocations"],
            "sourceReady": proof["sourceReady"],
        },
        "bridgeBasis": {
            "axisOrder": bridge["citysimToBlenderAxisOrder"],
            "axisSigns": bridge["citysimToBlenderAxisSigns"],
            "determinant": bridge["determinant"],
            "formula": bridge["formula"],
            "matrixRows": bridge["matrixRows"],
            "sourceOrder": bridge["sourceOrder"],
        },
        "direction": runner["direction"],
        "literal192": {
            "frameMinimumThicknessPixels": metrics[
                "frameMinimumThicknessPixels"
            ],
            "freightOpeningMinimumWidthPixels": thresholds[
                "literal192FreightOpeningMinimumWidthPixels"
            ],
            "freightOpeningWidthsPixels": metrics[
                "freightOpeningWidthsPixels"
            ],
            "maximumProcessOcclusionPixels": thresholds[
                "maximumProcessOcclusionPixels"
            ],
            "minimumSilhouetteBreaks": thresholds["minimumSilhouetteBreaks"],
            "primaryPortalMinimumPixels": thresholds[
                "literal192PrimaryPortalMinimumPixels"
            ],
            "primaryPortalPixels": metrics["primaryPortalPixels"],
            "processOcclusionPixels": metrics["processOcclusionPixels"],
            "requiredFrameMinimumThicknessPixels": thresholds[
                "literal192FrameMinimumThicknessPixels"
            ],
            "silhouetteBreaks": metrics["silhouetteBreaks"],
        },
        "registration": {
            "blenderNativeSouthSocket": bridge[
                "blenderNativeDirectionalSocket"
            ],
            "canonicalCitySimSouthSocket": bridge[
                "canonicalCitySimSouthSocket"
            ],
            "expectedSourceSocketPixels": registration[
                "sourceProjectionObservation"
            ]["socketPixels"],
            "maximumErrorSourcePixels": camera["maximumDeltaSourcePixels"],
            "observedSourceSocketPixels": camera[
                "actualSourceSocketPixels"
            ],
            "toleranceSourcePixels": camera["toleranceSourcePixels"],
        },
        "toolchainFingerprint": {
            "adaptiveSampling": render["adaptiveSampling"],
            "blenderBuildHash": render["blenderBuildHash"],
            "blenderExecutableSha256": render["blenderExecutableSha256"],
            "blenderVersion": render["blenderVersion"],
            "denoising": render["denoising"],
            "device": render["device"],
            "engine": render["engine"],
            "motionBlur": render["motionBlur"],
            "threads": render["threads"],
            "threadsMode": render["threadsMode"],
            "transparentFilm": render["transparentFilm"],
        },
    }


def validate_candidate(candidate: dict[str, Any]) -> None:
    require_exact_keys(
        candidate,
        {
            "boundary",
            "bridgeBasis",
            "direction",
            "literal192",
            "registration",
            "toolchainFingerprint",
        },
        "candidate",
    )
    if candidate["direction"] != "south":
        reject("WRONG_DIRECTION", candidate["direction"])

    registration = candidate["registration"]
    require_vector(
        registration.get("canonicalCitySimSouthSocket"),
        [0, 0, 28],
        "SOUTH_SOCKET_DRIFT",
    )
    require_vector(
        registration.get("blenderNativeSouthSocket"),
        [28, 0, 0],
        "SOUTH_SOCKET_DRIFT",
    )
    require_vector(
        registration.get("expectedSourceSocketPixels"),
        [640, 832],
        "SOUTH_SOCKET_DRIFT",
    )
    error = require_number(
        registration.get("maximumErrorSourcePixels"),
        "maximumErrorSourcePixels",
    )
    tolerance = require_number(
        registration.get("toleranceSourcePixels"),
        "toleranceSourcePixels",
    )
    if tolerance != 0.001 or error > tolerance:
        reject(
            "REGISTRATION_ERROR_ABOVE_TOLERANCE",
            {"error": error, "tolerance": tolerance},
        )
    observed = registration.get("observedSourceSocketPixels")
    expected = registration.get("expectedSourceSocketPixels")
    if not isinstance(observed, list) or len(observed) != 2:
        reject("REGISTRATION_MEASUREMENT_MALFORMED", observed)
    measured_error = max(
        abs(require_number(observed[index], "observedSourceSocketPixels") - expected[index])
        for index in range(2)
    )
    if not math.isclose(measured_error, error, abs_tol=1e-15):
        reject(
            "REGISTRATION_MEASUREMENT_INCONSISTENT",
            {"declared": error, "measured": measured_error},
        )

    bridge = candidate["bridgeBasis"]
    expected_bridge = {
        "axisOrder": [2, 0, 1],
        "axisSigns": [1, 1, 1],
        "determinant": 1,
        "formula": "B(CitySim[x,y,z])=Blender[z,x,y]",
        "matrixRows": [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
        "sourceOrder": [0, 1, 2, 3],
    }
    if bridge != expected_bridge:
        reject("WRONG_BRIDGE_BASIS", {"expected": expected_bridge, "actual": bridge})

    literal = candidate["literal192"]
    portal = literal.get("primaryPortalPixels")
    portal_minimum = literal.get("primaryPortalMinimumPixels")
    if (
        not isinstance(portal, list)
        or not isinstance(portal_minimum, list)
        or len(portal) != 2
        or len(portal_minimum) != 2
        or any(
            require_number(portal[index], "primaryPortalPixels")
            < require_number(portal_minimum[index], "primaryPortalMinimumPixels")
            for index in range(2)
        )
    ):
        reject("PRIMARY_PORTAL_SCALE_INSUFFICIENT", portal)
    freight = literal.get("freightOpeningWidthsPixels")
    freight_minimum = require_number(
        literal.get("freightOpeningMinimumWidthPixels"),
        "freightOpeningMinimumWidthPixels",
    )
    if (
        not isinstance(freight, list)
        or len(freight) != 3
        or min(require_number(value, "freightOpeningWidthsPixels") for value in freight)
        < freight_minimum
    ):
        reject("FREIGHT_OPENING_SCALE_INSUFFICIENT", freight)
    if require_number(
        literal.get("frameMinimumThicknessPixels"),
        "frameMinimumThicknessPixels",
    ) < require_number(
        literal.get("requiredFrameMinimumThicknessPixels"),
        "requiredFrameMinimumThicknessPixels",
    ):
        reject("PORTAL_FRAME_SCALE_INSUFFICIENT")
    if require_number(
        literal.get("processOcclusionPixels"), "processOcclusionPixels"
    ) > require_number(
        literal.get("maximumProcessOcclusionPixels"),
        "maximumProcessOcclusionPixels",
    ):
        reject("PORTAL_OCCLUSION", literal.get("processOcclusionPixels"))
    if require_number(
        literal.get("silhouetteBreaks"), "silhouetteBreaks"
    ) < require_number(
        literal.get("minimumSilhouetteBreaks"), "minimumSilhouetteBreaks"
    ):
        reject(
            "INSUFFICIENT_SILHOUETTE_STRUCTURE",
            literal.get("silhouetteBreaks"),
        )

    fingerprint = candidate["toolchainFingerprint"]
    if (
        not isinstance(fingerprint, dict)
        or not HEX_12.fullmatch(str(fingerprint.get("blenderBuildHash", "")))
        or not HEX_64.fullmatch(
            str(fingerprint.get("blenderExecutableSha256", ""))
        )
    ):
        reject("MALFORMED_TOOLCHAIN_FINGERPRINT", fingerprint)
    expected_fingerprint = {
        "adaptiveSampling": False,
        "blenderBuildHash": "84afd5f785f7",
        "blenderExecutableSha256": (
            "8485107307b16bd0899f3c259261494b0"
            "c80e383db239c04e2c9fcd14d305fb4"
        ),
        "blenderVersion": "4.5.12 LTS",
        "denoising": False,
        "device": "CPU",
        "engine": "CYCLES",
        "motionBlur": False,
        "threads": 1,
        "threadsMode": "FIXED",
        "transparentFilm": True,
    }
    if fingerprint != expected_fingerprint:
        reject(
            "TOOLCHAIN_FINGERPRINT_MISMATCH",
            {"expected": expected_fingerprint, "actual": fingerprint},
        )

    expected_boundary = {
        "blenderProcessLaunches": 0,
        "blenderRenderApiCalls": 0,
        "contactSheetInvocations": 0,
        "imageGenInvocations": 0,
        "normalizerInvocations": 0,
        "pixelFiles": 0,
        "processA": "not_run",
        "processB": "not_run",
        "processC": "not_run",
        "productionSelected": False,
        "renderInvocations": 0,
        "sourceReady": False,
    }
    if candidate["boundary"] != expected_boundary:
        reject("ZERO_PIXEL_BOUNDARY_VIOLATION", candidate["boundary"])


def apply_mutation(
    baseline: dict[str, Any], mutation: dict[str, Any]
) -> dict[str, Any]:
    require_exact_keys(mutation, {"path", "value"}, "mutation")
    pointer = mutation["path"]
    if not isinstance(pointer, str) or not pointer.startswith("/"):
        reject("INVALID_MUTATION_PATH", pointer)
    parts = pointer[1:].split("/")
    if not parts or any(not part or part in {".", ".."} for part in parts):
        reject("INVALID_MUTATION_PATH", pointer)
    candidate = copy.deepcopy(baseline)
    target: Any = candidate
    for part in parts[:-1]:
        if not isinstance(target, dict) or part not in target:
            reject("INVALID_MUTATION_PATH", pointer)
        target = target[part]
    if not isinstance(target, dict) or parts[-1] not in target:
        reject("INVALID_MUTATION_PATH", pointer)
    target[parts[-1]] = mutation["value"]
    return candidate


def validate_fixture_document(fixtures_path: Path) -> dict[str, Any]:
    fixture_raw = fixtures_path.read_bytes()
    fixture = load_json_bytes(fixture_raw, str(fixtures_path))
    require_exact_keys(
        fixture,
        {
            "adversarialCases",
            "baseline",
            "claimSha256",
            "direction",
            "inputBindings",
            "mode",
            "publishedBase",
            "schema",
            "taskId",
        },
        "fixture",
    )
    if (
        fixture["schema"]
        != "citysim.play-080.literal192-frontage-adversarial-fixtures.v1"
        or fixture["taskId"] != "PLAY-080"
        or fixture["direction"] != "south"
        or fixture["mode"] != "pure-data-zero-pixel"
        or not HEX_40.fullmatch(str(fixture["publishedBase"]))
        or not HEX_64.fullmatch(str(fixture["claimSha256"]))
    ):
        reject("FIXTURE_IDENTITY_MISMATCH")

    bindings = fixture["inputBindings"]
    if not isinstance(bindings, list) or len(bindings) != len(EXPECTED_INPUT_ROLES):
        reject("INPUT_BINDINGS_MALFORMED")
    loaded: dict[str, dict[str, Any]] = {}
    binding_results: list[dict[str, Any]] = []
    roles: set[str] = set()
    for binding in bindings:
        if not isinstance(binding, dict):
            reject("INPUT_BINDING_MALFORMED", binding)
        require_exact_keys(binding, {"path", "role", "sha256"}, "inputBinding")
        role = binding["role"]
        if role not in EXPECTED_INPUT_ROLES or role in roles:
            reject("INPUT_ROLE_MISMATCH", role)
        roles.add(role)
        path, raw = safe_regular_repo_file(binding["path"])
        actual_sha = sha256_bytes(raw)
        if not HEX_64.fullmatch(str(binding["sha256"])) or actual_sha != binding["sha256"]:
            reject(
                "INPUT_HASH_MISMATCH",
                {"role": role, "expected": binding["sha256"], "actual": actual_sha},
            )
        if role not in {"acceptedSouthScene", "acceptedSouthMaterials"}:
            loaded[role] = load_json_bytes(raw, binding["path"])
        binding_results.append(
            {
                "path": path.relative_to(REPOSITORY_ROOT).as_posix(),
                "role": role,
                "sha256": actual_sha,
            }
        )
    if roles != EXPECTED_INPUT_ROLES:
        reject("INPUT_ROLE_MISMATCH", sorted(roles))

    derived = derive_baseline(loaded)
    if fixture["baseline"] != derived:
        reject(
            "BASELINE_DOES_NOT_MATCH_BOUND_SOUTH_EVIDENCE",
            {"expected": derived, "actual": fixture["baseline"]},
        )
    validate_candidate(fixture["baseline"])

    cases = fixture["adversarialCases"]
    if not isinstance(cases, list) or len(cases) != len(EXPECTED_CASES):
        reject("ADVERSARIAL_CASE_SET_MISMATCH")
    seen: set[str] = set()
    case_results: list[dict[str, Any]] = []
    for case in cases:
        if not isinstance(case, dict):
            reject("ADVERSARIAL_CASE_MALFORMED", case)
        require_exact_keys(
            case, {"expectedRejection", "id", "mutation"}, "adversarialCase"
        )
        case_id = case["id"]
        if case_id not in EXPECTED_CASES or case_id in seen:
            reject("ADVERSARIAL_CASE_SET_MISMATCH", case_id)
        seen.add(case_id)
        expected_code, expected_path = EXPECTED_CASES[case_id]
        if (
            case["expectedRejection"] != expected_code
            or case["mutation"].get("path") != expected_path
        ):
            reject("ADVERSARIAL_CASE_CONTRACT_MISMATCH", case_id)
        candidate = apply_mutation(fixture["baseline"], case["mutation"])
        try:
            validate_candidate(candidate)
        except FixtureRejected as error:
            if error.code != expected_code:
                reject(
                    "WRONG_REJECTION_CODE",
                    {
                        "case": case_id,
                        "expected": expected_code,
                        "actual": error.code,
                    },
                )
        else:
            reject("ADVERSARIAL_CASE_FAILED_OPEN", case_id)
        case_results.append(
            {
                "id": case_id,
                "mutationPath": expected_path,
                "result": "PASS_FAIL_CLOSED",
                "rejectionCode": expected_code,
            }
        )
    if seen != set(EXPECTED_CASES):
        reject("ADVERSARIAL_CASE_SET_MISMATCH", sorted(seen))

    return {
        "adversarialCases": case_results,
        "baseline": {
            "literal192": fixture["baseline"]["literal192"],
            "registration": fixture["baseline"]["registration"],
            "result": "PASS",
        },
        "inputBindings": binding_results,
    }


def canonical_bytes(value: dict[str, Any]) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixtures", type=Path, default=DEFAULT_FIXTURES)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    try:
        first = validate_fixture_document(args.fixtures)
        second = validate_fixture_document(args.fixtures)
        first_bytes = canonical_bytes(first)
        second_bytes = canonical_bytes(second)
        first_sha = sha256_bytes(first_bytes)
        second_sha = sha256_bytes(second_bytes)
        if first_bytes != second_bytes:
            reject(
                "NONDETERMINISTIC_REPLAY",
                {"firstSha256": first_sha, "secondSha256": second_sha},
            )
        report = {
            "activity": {
                "blenderProcessLaunches": 0,
                "blenderRenderApiCalls": 0,
                "contactSheetInvocations": 0,
                "imageGenInvocations": 0,
                "normalizerInvocations": 0,
                "pixelFiles": 0,
                "renderInvocations": 0,
                "sourcePackets": 0,
            },
            "direction": "south",
            "fixture": {
                "path": args.fixtures.resolve()
                .relative_to(REPOSITORY_ROOT)
                .as_posix(),
                "sha256": sha256_bytes(args.fixtures.read_bytes()),
            },
            "grants": {
                "admissionAuthorized": False,
                "pixelProductionAuthorized": False,
                "productionReceiptAuthorized": False,
                "productionSelected": False,
                "sourceReady": False,
            },
            "mode": "pure-data-zero-pixel",
            "replay": {
                "identical": True,
                "payloadSha256": [first_sha, second_sha],
                "runs": 2,
            },
            "result": "PASS",
            "schema": (
                "citysim.play-080.literal192-frontage-"
                "adversarial-validation.v1"
            ),
            "taskId": "PLAY-080",
            "validation": first,
            "validator": {
                "path": Path(__file__).resolve()
                .relative_to(REPOSITORY_ROOT)
                .as_posix(),
                "sha256": sha256_bytes(Path(__file__).read_bytes()),
            },
        }
        output = canonical_bytes(report)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(output)
        print(
            json.dumps(
                {
                    "adversarialCases": len(first["adversarialCases"]),
                    "outputSha256": sha256_bytes(output),
                    "replayIdentical": True,
                    "result": "PASS",
                },
                sort_keys=True,
            )
        )
        return 0
    except FixtureRejected as error:
        print(
            json.dumps(
                {
                    "code": error.code,
                    "details": error.details,
                    "reportWritten": False,
                    "result": "REJECTED",
                },
                sort_keys=True,
            )
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
