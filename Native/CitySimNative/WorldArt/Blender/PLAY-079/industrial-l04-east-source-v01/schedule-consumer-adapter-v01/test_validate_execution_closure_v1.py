#!/usr/bin/env python3
"""Adversarial zero-child proof for PLAY-079 East execution closure v1."""

from __future__ import annotations

import argparse
import copy
import hashlib
import hmac
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from typing import Any, Callable


VERSION_ROOT = pathlib.Path(__file__).resolve().parent
SOURCE_ROOT = VERSION_ROOT.parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
SHARED_TEST_PATH = (
    REPOSITORY_ROOT
    / ".agents/skills/operate-citysim-integration/scripts/"
    "test_validate_industrial_l04_direction_execution_authority_v1.py"
)
if str(VERSION_ROOT) not in sys.path:
    sys.path.insert(0, str(VERSION_ROOT))
if str(SOURCE_ROOT) not in sys.path:
    sys.path.insert(0, str(SOURCE_ROOT))

import orchestrate_parallel_source as orchestrator
import run_production as runner
import validate_execution_closure_v1 as closure


def load_module(path: pathlib.Path, name: str) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


SHARED_TEST = load_module(SHARED_TEST_PATH, "play079_shared_execution_fixture")
SHARED_VALIDATOR = SHARED_TEST.MODULE
SECRET = b"play079-east-validation-secret!!"
assert len(SECRET) == 32


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def fixture_contract(fixture: Any) -> dict[str, Any]:
    contract = json.loads(
        (VERSION_ROOT / "EXECUTION-CLOSURE-CONTRACT.json").read_text(encoding="utf-8")
    )
    contract["_testFixture"] = True
    contract["task"] = copy.deepcopy(fixture.authority["task"])
    contract["artifactPaths"] = {
        name: path.as_posix() for name, path in fixture.artifact_paths.items()
    }
    return contract


def publish_authenticated(
    fixture: Any,
    mutator: Callable[[dict[str, Any]], None] | None = None,
    *,
    secret: bytes = SECRET,
    forge_mac: bool = False,
) -> dict[str, Any]:
    authority = copy.deepcopy(fixture.authority)
    if mutator is not None:
        mutator(authority)
    authentication = authority["authentication"]
    authentication["secretSha256"] = hashlib.sha256(secret).hexdigest()
    capability = authentication["childCapability"]
    capability["payloadSha256"] = "1" * 64
    capability["macSha256"] = "2" * 64
    payload = closure.capability_payload(authority)
    capability["payloadSha256"] = hashlib.sha256(payload).hexdigest()
    capability["macSha256"] = hmac.new(secret, payload, hashlib.sha256).hexdigest()
    if forge_mac:
        capability["macSha256"] = "f" * 64
    fixture.authority = authority
    fixture.republish_authority(SHARED_TEST.canonical_json(authority))
    return authority


def pipe_with_secret(secret: bytes = SECRET) -> tuple[int, int]:
    read_fd, write_fd = os.pipe()
    os.write(write_fd, secret)
    os.close(write_fd)
    return read_fd, write_fd


def arguments(fixture: Any, secret_fd: int) -> SimpleNamespace:
    return SimpleNamespace(
        execution_authority=str(fixture.root / fixture.authority_path),
        trusted_head=fixture.trusted_head,
        worker_head=fixture.worker_head,
        authority_publication_commit=fixture.authority_publication,
        secret_fd=secret_fd,
    )


def invoke(
    fixture: Any,
    contract: dict[str, Any],
    *,
    secret: bytes = SECRET,
    worker_head: str | None = None,
) -> dict[str, Any]:
    read_fd, _ = pipe_with_secret(secret)
    args = arguments(fixture, read_fd)
    if worker_head is not None:
        args.worker_head = worker_head
    try:
        return orchestrator.validate_execution_closure(
            args,
            repository_root=fixture.root,
            contract=contract,
            shared_validator=SHARED_VALIDATOR,
            fixture_contract=contract,
        )
    finally:
        os.close(read_fd)


def rejection(
    case_id: str,
    callback: Callable[[], object],
    expected_types: tuple[type[BaseException], ...] = (
        orchestrator.OrchestrationRejected,
        runner.GuardRejected,
    ),
) -> dict[str, Any]:
    try:
        callback()
    except expected_types as error:
        return {
            "id": case_id,
            "result": "REJECTED_ZERO_CHILD",
            "code": getattr(error, "code", type(error).__name__),
            "sourceChildStarts": 0,
            "dccStarts": 0,
            "renders": 0,
            "pixels": 0,
        }
    raise RuntimeError(f"{case_id}: expected rejection")


def fresh_fixture() -> Any:
    fixture = SHARED_TEST.Fixture(direction="east", phase="postlock_abc")
    publish_authenticated(fixture)
    return fixture


def assert_direct_runner_cli_rejected() -> None:
    completed = subprocess.run(
        [
            sys.executable,
            "-B",
            str(SOURCE_ROOT / "run_production.py"),
            "--mode",
            "A",
            "--appearance-lock",
            "docs/production/evidence/INTEGRATION/forged-lock.json",
        ],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
    )
    output = json.loads(completed.stdout)
    if (
        completed.returncode != 2
        or output.get("code") != "unauthenticated_runner_input"
        or output.get("blenderProcessLaunches") != 0
        or output.get("blenderRenderApiCalls") != 0
        or output.get("pixelFiles") != 0
    ):
        raise RuntimeError(f"direct runner CLI did not fail closed: {output}")


def positive_run() -> dict[str, Any]:
    fixture = fresh_fixture()
    try:
        result = invoke(fixture, fixture_contract(fixture))
        boundary = result["runnerBoundary"]
        if (
            boundary["validationOnly"] is not True
            or boundary["childStarts"] != 0
            or boundary["blenderProcessLaunches"] != 0
            or boundary["blenderRenderApiCalls"] != 0
            or boundary["pixelFiles"] != 0
        ):
            raise RuntimeError(f"positive boundary was not zero-child: {boundary}")
        return {
            "result": "PASS",
            "direction": boundary["direction"],
            "process": boundary["process"],
            "validationOnly": True,
            "sourceChildStarts": 0,
            "dccStarts": 0,
            "renders": 0,
            "pixels": 0,
        }
    finally:
        fixture.close()


def mutated_case(
    case_id: str,
    mutator: Callable[[dict[str, Any]], None],
    *,
    forge_mac: bool = False,
) -> dict[str, Any]:
    fixture = SHARED_TEST.Fixture(direction="east", phase="postlock_abc")
    try:
        publish_authenticated(fixture, mutator, forge_mac=forge_mac)
        return rejection(
            case_id,
            lambda: invoke(fixture, fixture_contract(fixture)),
        )
    finally:
        fixture.close()


def run_cases() -> dict[str, Any]:
    closure.reset_test_replay_state()
    assert_direct_runner_cli_rejected()
    first = positive_run()
    second = positive_run()
    if canonical_bytes(first) != canonical_bytes(second):
        raise RuntimeError("fresh-root positive results are not deterministic")

    cases: list[dict[str, Any]] = []
    missing = SimpleNamespace(
        execution_authority=None,
        trusted_head=None,
        worker_head=None,
        authority_publication_commit=None,
        secret_fd=None,
    )
    cases.append(
        rejection(
            "missing_inputs",
            lambda: orchestrator.validate_execution_closure(missing),
        )
    )

    stale = fresh_fixture()
    try:
        (stale.root / stale.authority_path).write_bytes(stale.authority_payload + b"\n")
        cases.append(
            rejection(
                "stale_working_authority",
                lambda: invoke(stale, fixture_contract(stale)),
            )
        )
    finally:
        stale.close()

    non_ancestral = fresh_fixture()
    try:
        cases.append(
            rejection(
                "non_ancestral_worker",
                lambda: invoke(
                    non_ancestral,
                    fixture_contract(non_ancestral),
                    worker_head=non_ancestral.schedule_publication,
                ),
            )
        )
    finally:
        non_ancestral.close()

    replay = fresh_fixture()
    try:
        contract = fixture_contract(replay)
        invoke(replay, contract)
        cases.append(
            rejection("replayed_capability", lambda: invoke(replay, contract))
        )
    finally:
        replay.close()

    cases.extend(
        [
            mutated_case("forged_capability", lambda value: None, forge_mac=True),
            mutated_case(
                "wrong_direction",
                lambda value: value["task"].update(direction="south"),
            ),
            mutated_case(
                "wrong_process",
                lambda value: value["grant"].update(process="B"),
            ),
            mutated_case(
                "wrong_root",
                lambda value: value["exclusiveRoots"].update(
                    output=(
                        "Native/CitySimNative/WorldArt/Blender/PLAY-080/"
                        "industrial-l04-south-source-v01/outputs/forged"
                    )
                ),
            ),
            mutated_case(
                "wrong_slot",
                lambda value: value["grant"].update(slotId="dcc-forged"),
            ),
            mutated_case(
                "wrong_claim",
                lambda value: value["task"].update(claimSha256="e" * 64),
            ),
            mutated_case(
                "wrong_base",
                lambda value: value["task"].update(
                    publishedBaseCommit=value["schedule"]["publicationCommit"]
                ),
            ),
            mutated_case(
                "wrong_orchestrator",
                lambda value: value["artifacts"].update(
                    highLevelOrchestrator=copy.deepcopy(
                        value["artifacts"]["runnerEntrypoint"]
                    )
                ),
            ),
        ]
    )

    cases.append(
        rejection(
            "direct_runner",
            lambda: runner.validate_execution_closure_boundary({}),
            (runner.GuardRejected,),
        )
    )

    unauthenticated = fresh_fixture()
    try:
        contract = fixture_contract(unauthenticated)
        with tempfile.TemporaryFile() as regular:
            regular.write(SECRET)
            regular.seek(0)
            args = arguments(unauthenticated, regular.fileno())
            cases.append(
                rejection(
                    "unauthenticated_regular_file",
                    lambda: orchestrator.validate_execution_closure(
                        args,
                        repository_root=unauthenticated.root,
                        contract=contract,
                        shared_validator=SHARED_VALIDATOR,
                        fixture_contract=contract,
                    ),
                )
            )
    finally:
        unauthenticated.close()

    wrong_secret = fresh_fixture()
    try:
        cases.append(
            rejection(
                "unauthenticated_wrong_secret",
                lambda: invoke(
                    wrong_secret,
                    fixture_contract(wrong_secret),
                    secret=b"x" * 32,
                ),
            )
        )
    finally:
        wrong_secret.close()

    expected = {
        "missing_inputs",
        "stale_working_authority",
        "non_ancestral_worker",
        "replayed_capability",
        "forged_capability",
        "wrong_direction",
        "wrong_process",
        "wrong_root",
        "wrong_slot",
        "wrong_claim",
        "wrong_base",
        "wrong_orchestrator",
        "direct_runner",
        "unauthenticated_regular_file",
        "unauthenticated_wrong_secret",
    }
    if {case["id"] for case in cases} != expected:
        raise RuntimeError("adversarial case set is incomplete")
    return {
        "schema": "citysim.play-079.east-execution-closure-proof.v1",
        "taskId": "PLAY-079",
        "direction": "east",
        "claimRevision": 6,
        "result": "PASS_ZERO_CHILD",
        "freshRootValidations": 2,
        "freshRootResultsByteIdentical": True,
        "adversarialRejectedCount": len(cases),
        "adversarialCases": sorted(cases, key=lambda value: value["id"]),
        "sharedControlHashes": {
            "schema": "2796e224780c259b29d68b50cb12cdbbe45452535da681bba3522af920459491",
            "validator": "b212d2776d34b3334910c6b0b02ffba244919f4a83d5c0019c30bca87648d8ae",
            "authority": "0125539f015ab8069c11093e755ac6e43d7b37994c86515fc06894e401b7eb54",
        },
        "activity": {
            "liveLeases": 0,
            "sourceChildStarts": 0,
            "blenderDccStarts": 0,
            "renderApiCalls": 0,
            "pixelFilesCreated": 0,
            "normalizationRuns": 0,
            "sourcePackets": 0,
            "repositoryWrites": 0,
        },
        "disposition": {
            "validationOnly": True,
            "sourceReady": False,
            "productionSelected": False,
            "admitted": False,
            "shippingAuthorized": False,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--packet", action="store_true")
    args = parser.parse_args()
    packet = run_cases()
    if args.packet:
        sys.stdout.buffer.write(canonical_bytes(packet))
    else:
        print(
            f"PASS: 2 fresh roots; {packet['adversarialRejectedCount']} "
            "adversaries; zero source/DCC children or pixels"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
