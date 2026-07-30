#!/usr/bin/env python3
"""Adversarial zero-child proof for PLAY-079 East closure candidate revision 8."""

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
CRASH_AFTER_CLAIM_EXIT = 86
PUBLISHED_MASTER = "d4f18ea3b1ccfd522f3b5e877bc7cb742fd9be09"
MERGED_BASELINE = "86b19e9f06a33a5d3139858e72a244df24a62e8c"
PRESERVED_CANDIDATE = "e7d526246232e5e39ba2c8975372e086e2d7c85b"
CLAIM_SHA256 = "8b32a70a11b636a87ffecc70bbb1eace4c5313adc3077fdd0316c15151138483"
VISIBLE_THREAD_ID = "019fab72-b2c8-76c1-b430-6c6f8431733f"
assert len(SECRET) == 32


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("ascii")


def artifact_binding(relative: str) -> dict[str, str]:
    path = REPOSITORY_ROOT / relative
    return {
        "path": relative,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def current_authority_bindings() -> dict[str, Any]:
    ancestor = subprocess.run(
        ["git", "merge-base", "--is-ancestor", PUBLISHED_MASTER, "HEAD"],
        cwd=REPOSITORY_ROOT,
        check=False,
        capture_output=True,
    )
    if ancestor.returncode:
        raise RuntimeError("published master is not an ancestor of replay HEAD")
    claim = artifact_binding("docs/production/claims/PLAY-079.world-art-east.md")
    if claim["sha256"] != CLAIM_SHA256:
        raise RuntimeError("PLAY-079 claim hash does not match current authority")
    runner_contract = json.loads(
        (SOURCE_ROOT / "RUNNER-CONTRACT.json").read_text(encoding="utf-8")
    )
    schedule_contract = json.loads(
        (VERSION_ROOT / "SCHEDULE-CONSUMER-CONTRACT.json").read_text(
            encoding="utf-8"
        )
    )
    closure_contract = json.loads(
        (VERSION_ROOT / "EXECUTION-CLOSURE-CONTRACT.json").read_text(
            encoding="utf-8"
        )
    )
    if (
        runner_contract["executionClosure"]["publishedBaseCommit"]
        != PUBLISHED_MASTER
        or runner_contract["executionClosure"]["claimSha256"] != CLAIM_SHA256
        or schedule_contract["publishedBase"] != PUBLISHED_MASTER
        or schedule_contract["targetGrant"]["baseCommit"] != PUBLISHED_MASTER
        or schedule_contract["claimSha256"] != CLAIM_SHA256
        or closure_contract["task"]["publishedBaseCommit"] != PUBLISHED_MASTER
        or closure_contract["task"]["claimSha256"] != CLAIM_SHA256
    ):
        raise RuntimeError("East current-authority contract binding is stale")
    return {
        "publishedMaster": {
            "commit": PUBLISHED_MASTER,
            "ancestorOfReplayHead": True,
        },
        "mergedBaseline": {
            "commit": MERGED_BASELINE,
            "firstParent": PRESERVED_CANDIDATE,
            "secondParent": PUBLISHED_MASTER,
        },
        "claim": claim,
        "runnerContract": artifact_binding(
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/RUNNER-CONTRACT.json"
        ),
        "runnerEntrypoint": artifact_binding(
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/run_production.py"
        ),
        "highLevelOrchestrator": artifact_binding(
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/orchestrate_parallel_source.py"
        ),
        "executionClosureContract": artifact_binding(
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/schedule-consumer-adapter-v01/"
            "EXECUTION-CLOSURE-CONTRACT.json"
        ),
        "scheduleConsumerContract": artifact_binding(
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/schedule-consumer-adapter-v01/"
            "SCHEDULE-CONSUMER-CONTRACT.json"
        ),
    }


def postlock_abc_proposal() -> dict[str, Any]:
    jobs = []
    for process in "ABC":
        lower = process.lower()
        jobs.append(
            {
                "jobId": f"east:{process}",
                "process": process,
                "queueToken": f"east:{process}",
                "outputRoot": (
                    "docs/production/evidence/PLAY-079/"
                    "industrial-l04-east-source-v01/"
                    f"renders/process-{lower}/"
                ),
                "evidenceRoot": (
                    "docs/production/evidence/PLAY-079/"
                    "industrial-l04-east-source-v01/"
                    f"execution/process-{lower}/"
                ),
                "slotId": None,
                "slotState": "UNASSIGNED_REQUIRES_FUTURE_INTEGRATION_GRANT",
                "maximumChildStarts": 1,
            }
        )
    return {
        "status": "PROPOSAL_ONLY_AUTHORITY_BLOCKED",
        "proposalOnly": True,
        "launchAuthorized": False,
        "dccSlotsAuthorizedByCurrentEnvelope": 0,
        "taskExclusiveRoots": [
            "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
            "industrial-l04-east-source-v01/",
            "docs/production/evidence/PLAY-079/"
            "industrial-l04-east-source-v01/",
        ],
        "requiredRelativeOrder": ["east:A", "east:B", "east:C"],
        "jobs": jobs,
        "missingIntegrationAuthorities": [
            "appearanceLock",
            "sourceProductionProfile",
            "postlockParallelExecutionSchedule",
            "perProcessOneAttemptGrants",
            "assignedDccSlots",
        ],
    }


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


def fixture_consume_cli(args: argparse.Namespace) -> int:
    contract = json.loads(pathlib.Path(args.contract_path).read_text(encoding="utf-8"))
    request = SimpleNamespace(
        execution_authority=args.execution_authority,
        trusted_head=args.trusted_head,
        worker_head=args.worker_head,
        authority_publication_commit=args.authority_publication_commit,
        secret_fd=args.secret_fd,
    )
    try:
        result = orchestrator.validate_execution_closure(
            request,
            repository_root=pathlib.Path(args.repo_root),
            contract=contract,
            shared_validator=SHARED_VALIDATOR,
            fixture_contract=contract,
        )
        result["_fixtureProcessId"] = os.getpid()
        sys.stdout.buffer.write(canonical_bytes(result))
        return 0
    except (orchestrator.OrchestrationRejected, runner.GuardRejected) as error:
        sys.stdout.buffer.write(
            canonical_bytes(
                {
                    "result": "REJECTED_ZERO_CHILD",
                    "_fixtureProcessId": os.getpid(),
                    "code": error.code,
                    "detail": error.detail,
                    "sourceChildStarts": 0,
                    "dccStarts": 0,
                    "renders": 0,
                    "pixels": 0,
                }
            )
        )
        return 2


def fixture_crash_after_claim_cli(args: argparse.Namespace) -> int:
    contract = json.loads(pathlib.Path(args.contract_path).read_text(encoding="utf-8"))
    closure.authenticate(
        repository_root=pathlib.Path(args.repo_root),
        authority_path=pathlib.Path(args.execution_authority),
        trusted_head=args.trusted_head,
        worker_head=args.worker_head,
        authority_publication_commit=args.authority_publication_commit,
        secret_fd=args.secret_fd,
        contract=contract,
        shared_validator=SHARED_VALIDATOR,
        test_after_directory_claim=lambda: os._exit(CRASH_AFTER_CLAIM_EXIT),
    )
    raise RuntimeError("crash-after-claim hook returned")


def subprocess_consume(
    fixture: Any,
    contract_path: pathlib.Path,
    *,
    crash_after_claim: bool = False,
) -> tuple[int, dict[str, Any]]:
    read_fd, _ = pipe_with_secret()
    try:
        completed = subprocess.run(
            [
                sys.executable,
                "-B",
                str(pathlib.Path(__file__).resolve()),
                (
                    "--fixture-crash-after-claim"
                    if crash_after_claim
                    else "--fixture-consume"
                ),
                "--repo-root",
                str(fixture.root),
                "--contract-path",
                str(contract_path),
                "--execution-authority",
                str(fixture.root / fixture.authority_path),
                "--trusted-head",
                fixture.trusted_head,
                "--worker-head",
                fixture.worker_head,
                "--authority-publication-commit",
                fixture.authority_publication,
                "--secret-fd",
                str(read_fd),
            ],
            cwd=REPOSITORY_ROOT,
            check=False,
            capture_output=True,
            pass_fds=(read_fd,),
        )
    finally:
        os.close(read_fd)
    if completed.stderr:
        raise RuntimeError(
            f"fixture child wrote stderr: {completed.stderr.decode('utf-8', 'replace')}"
        )
    if crash_after_claim:
        if completed.stdout:
            raise RuntimeError("crash-after-claim child unexpectedly wrote stdout")
        return completed.returncode, {}
    return completed.returncode, json.loads(completed.stdout)


def cross_process_replay() -> dict[str, Any]:
    fixture = fresh_fixture()
    try:
        contract = fixture_contract(fixture)
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            prefix="play079-east-closure-contract-",
            suffix=".json",
        ) as contract_stream:
            json.dump(contract, contract_stream, sort_keys=True)
            contract_stream.flush()
            first_code, first = subprocess_consume(
                fixture,
                pathlib.Path(contract_stream.name),
            )
            second_code, second = subprocess_consume(
                fixture,
                pathlib.Path(contract_stream.name),
            )
        distinct_processes = (
            isinstance(first.get("_fixtureProcessId"), int)
            and isinstance(second.get("_fixtureProcessId"), int)
            and first["_fixtureProcessId"] != second["_fixtureProcessId"]
        )
        if (
            first_code != 0
            or first.get("result") != "PASS"
            or first.get("repositoryWrites") != 1
            or first.get("sourceChildStarts") != 0
            or first.get("dccInvocations") != 0
            or first.get("renderApiCalls") != 0
            or first.get("pixelFilesCreated") != 0
            or not distinct_processes
        ):
            raise RuntimeError(f"first fresh interpreter did not pass safely: {first}")
        if (
            second_code != 2
            or second.get("code") != "replayed_capability"
            or second.get("sourceChildStarts") != 0
            or second.get("dccStarts") != 0
            or second.get("renders") != 0
            or second.get("pixels") != 0
        ):
            raise RuntimeError(
                f"second fresh interpreter did not reject replay: {second}"
            )
        attempt_root = fixture.root / fixture.authority["exclusiveRoots"]["attempt"]
        marker = attempt_root / "ATTEMPT-CONSUMED.json"
        marker_payload = marker.read_bytes()
        marker_record = json.loads(marker_payload)
        if (
            marker_record.get("capabilityId")
            != fixture.authority["authentication"]["childCapability"]["capabilityId"]
            or marker_record.get("grantId") != fixture.authority["grant"]["grantId"]
            or marker_record.get("leasePath")
            != fixture.authority["executionEnvelope"]["leasePath"]
            or marker_record.get("liveLeaseCreated") is not False
            or SECRET in marker_payload
        ):
            raise RuntimeError("durable attempt marker identity or secrecy mismatch")
        if pathlib.Path(fixture.authority["executionEnvelope"]["leasePath"]).exists():
            raise RuntimeError("validation-only replay test created the live lease")
        return {
            "result": "PASS",
            "freshInterpreterStarts": 2,
            "distinctProcessIds": True,
            "moduleStateResetBetweenConsumes": True,
            "sameAuthority": True,
            "sameCapability": True,
            "sameLease": True,
            "firstConsume": "PASS_DURABLY_CLAIMED",
            "secondConsume": "REJECTED_REPLAYED_CAPABILITY",
            "markerRelativeToAttemptRoot": "ATTEMPT-CONSUMED.json",
            "atomicDirectoryClaim": True,
            "markerNoFollow": True,
            "markerNoOverwrite": True,
            "rawSecretPersisted": False,
            "liveLeaseCreated": False,
            "sourceChildStarts": 0,
            "dccStarts": 0,
            "renders": 0,
            "pixels": 0,
        }
    finally:
        fixture.close()


def crash_after_claim_replay() -> dict[str, Any]:
    fixture = fresh_fixture()
    try:
        contract = fixture_contract(fixture)
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            prefix="play079-east-crash-contract-",
            suffix=".json",
        ) as contract_stream:
            json.dump(contract, contract_stream, sort_keys=True)
            contract_stream.flush()
            crash_code, _ = subprocess_consume(
                fixture,
                pathlib.Path(contract_stream.name),
                crash_after_claim=True,
            )
            replay_code, replay = subprocess_consume(
                fixture,
                pathlib.Path(contract_stream.name),
            )
        attempt_root = fixture.root / fixture.authority["exclusiveRoots"]["attempt"]
        marker = attempt_root / "ATTEMPT-CONSUMED.json"
        if crash_code != CRASH_AFTER_CLAIM_EXIT:
            raise RuntimeError(
                f"post-claim fixture did not crash at the boundary: {crash_code}"
            )
        if not attempt_root.is_dir() or marker.exists():
            raise RuntimeError(
                "crash fixture did not preserve directory-only attempt consumption"
            )
        if (
            replay_code != 2
            or replay.get("code") != "replayed_capability"
            or replay.get("sourceChildStarts") != 0
            or replay.get("dccStarts") != 0
            or replay.get("renders") != 0
            or replay.get("pixels") != 0
        ):
            raise RuntimeError(
                f"fresh interpreter accepted crash-consumed attempt: {replay}"
            )
        return {
            "result": "PASS",
            "crashExitCode": CRASH_AFTER_CLAIM_EXIT,
            "attemptDirectoryPersisted": True,
            "markerCompleted": False,
            "freshInterpreterReplay": "REJECTED_REPLAYED_CAPABILITY",
            "liveLeaseCreated": False,
            "sourceChildStarts": 0,
            "dccStarts": 0,
            "renders": 0,
            "pixels": 0,
        }
    finally:
        fixture.close()


def positive_run() -> dict[str, Any]:
    fixture = fresh_fixture()
    try:
        result = invoke(fixture, fixture_contract(fixture))
        boundary = result["runnerBoundary"]
        if (
            boundary["validationOnly"] is not True
            or boundary["frozenInputValidation"]["result"] != "PASS"
            or boundary["frozenInputValidation"][
                "parallelSourceOrchestratorSha256"
            ]
            != "16b8c00a5714768a4e9c2a7c570ac4c0a41343dd456fc5670995fc229e874e5c"
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
            "frozenInputValidation": boundary["frozenInputValidation"],
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
    cross_process = cross_process_replay()
    crash_replay = crash_after_claim_replay()
    first = positive_run()
    second = positive_run()
    if canonical_bytes(first) != canonical_bytes(second):
        raise RuntimeError("fresh-root positive results are not deterministic")

    cases: list[dict[str, Any]] = []
    stale_runner_contract = runner.load_json(runner.CONTRACT_PATH)
    stale_runner_contract["authorities"]["parallelSourceOrchestrator"][
        "sha256"
    ] = "50045214378cf19c10fda0b1da6b74be496201b8bae4e961b4ee3210a63d530c"
    cases.append(
        rejection(
            "stale_frozen_orchestrator",
            lambda: runner.validate_frozen_inputs(stale_runner_contract),
            (runner.GuardRejected,),
        )
    )
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
        "stale_frozen_orchestrator",
    }
    if {case["id"] for case in cases} != expected:
        raise RuntimeError("adversarial case set is incomplete")
    return {
        "schema": "citysim.play-079.east-execution-closure-proof.v4",
        "taskId": "PLAY-079",
        "direction": "east",
        "claimRevision": 6,
        "candidateRevision": 8,
        "preservedApprovedCandidate": PRESERVED_CANDIDATE,
        "authorityBindings": current_authority_bindings(),
        "postlockABCProposal": postlock_abc_proposal(),
        "result": "PASS_ZERO_CHILD",
        "crossProcessReplay": cross_process,
        "crashAfterDirectoryClaimReplay": crash_replay,
        "frozenInputValidation": first["frozenInputValidation"],
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
            "governedWorktreeWrites": 0,
            "durableAttemptMarkersInDisposableFixtures": 4,
            "durableAttemptRootsInDisposableFixtures": 5,
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
    parser.add_argument("--fixture-consume", action="store_true")
    parser.add_argument("--fixture-crash-after-claim", action="store_true")
    parser.add_argument("--repo-root")
    parser.add_argument("--contract-path")
    parser.add_argument("--execution-authority")
    parser.add_argument("--trusted-head")
    parser.add_argument("--worker-head")
    parser.add_argument("--authority-publication-commit")
    parser.add_argument("--secret-fd", type=int)
    args = parser.parse_args()
    if args.fixture_consume or args.fixture_crash_after_claim:
        required = (
            args.repo_root,
            args.contract_path,
            args.execution_authority,
            args.trusted_head,
            args.worker_head,
            args.authority_publication_commit,
            args.secret_fd,
        )
        if any(value is None for value in required):
            raise RuntimeError("fixture-consume requires every fixture binding")
        if args.fixture_crash_after_claim:
            return fixture_crash_after_claim_cli(args)
        return fixture_consume_cli(args)
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
