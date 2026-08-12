#!/usr/bin/env python3
"""Focused adversarial tests for the CitySim model-route contract."""

from __future__ import annotations

import copy
import hashlib
import json
import plistlib
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import validate_model_route_v1 as validator


class ModelRouteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.email", "route@test.invalid"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.name", "Route Test"], check=True)
        (self.repo / "claims").mkdir()
        (self.repo / "inputs").mkdir()
        (self.repo / "owned" / "evidence").mkdir(parents=True)
        (self.repo / "script").mkdir()
        (self.repo / "claims" / "PLAY-999.md").write_text(
            "# PLAY-999\nOwn `owned/` and `owned/evidence/`.\n", encoding="utf-8"
        )
        (self.repo / "inputs" / "authority.txt").write_text("frozen\n", encoding="utf-8")
        (self.repo / "inputs" / "swift-runner.py").write_text("# frozen runner\n", encoding="utf-8")
        (self.repo / "inputs" / "route-validator.py").write_text("# frozen validator\n", encoding="utf-8")
        subprocess.run(
            ["git", "-C", str(self.repo), "commit", "--allow-empty", "-qm", "baseline"],
            check=True,
        )
        self.baseline = subprocess.check_output(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True
        ).strip()
        subprocess.run(["git", "-C", str(self.repo), "add", "claims", "inputs"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "commit", "-qm", "fixture"], check=True)
        self.head = subprocess.check_output(["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()
        self.claim = self._binding("claims/PLAY-999.md")
        self.input = self._binding("inputs/authority.txt")
        source_root = Path(__file__).resolve().parents[4]
        shutil.copyfile(
            source_root / "script" / "canonical_tree_digest.sh",
            self.repo / "script" / "canonical_tree_digest.sh",
        )
        self.producer = self._binding("script/canonical_tree_digest.sh")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _binding(self, rel: str) -> dict[str, str]:
        return {"path": rel, "sha256": hashlib.sha256((self.repo / rel).read_bytes()).hexdigest()}

    def route(self, classification: str = "LUNA_IMPLEMENTATION", packet_kind: str = "implementation") -> dict:
        model, effort = validator.ROUTES[classification]
        assignment_thread = "worker-thread"
        route = {
            "schema": 2,
            "routeId": f"PLAY-999:{classification.lower()}:v1",
            "taskId": "PLAY-999",
            "packetKind": packet_kind,
            "classification": classification,
            "model": model,
            "effort": effort,
            "rationale": "A bounded contract-complete test packet.",
            "authority": {
                "authorityCommit": self.head,
                "baseCommit": self.head,
                "claim": copy.deepcopy(self.claim),
                "immutableInputs": [copy.deepcopy(self.input)],
            },
            "assignment": {
                "threadId": assignment_thread,
                "branch": "master",
                "worktree": str(self.repo),
                "expectedHead": self.head,
                "featureAuthorThreadId": None,
                "sharedAuthorityOwnership": False,
                "finalQAOwnership": False,
                "subjectiveJudgmentRequired": False,
            },
            "pathPolicy": {
                "claimOwnedRoots": ["owned"],
                "allowed": ["owned/evidence"],
                "forbidden": ["claims"],
            },
            "boundedDeliverable": "Produce one deterministic evidence packet.",
            "proofPolicy": {
                "architectureState": "frozen_reference",
                "referenceImplementation": copy.deepcopy(self.input),
                "deliverableClaims": ["static_structure"],
                "focusedProofLevel": "static_only",
                "fullProofLevel": "static_only",
                "behavioralCommands": [],
                "prohibitedSubstitutions": sorted(
                    validator.PROHIBITED_EVIDENCE_SUBSTITUTIONS
                ),
            },
            "validation": {
                "focusedGateOwner": {"threadId": assignment_thread, "role": "lane_focused_gate"},
                "focusedCommands": ["python3 focused_check.py"],
                "fullGateOwner": {
                    "threadId": "integration-thread",
                    "role": "aggregate_full_gate",
                    "model": "gpt-5.6-sol",
                    "effort": "high",
                },
                "fullCommands": ["aggregate full Swift suite and staged build"],
            },
            "expectedResult": {
                "evidencePaths": ["owned/evidence"],
                "commitRequired": True,
                "commitMessagePattern": "PLAY-999:",
            },
            "escalationTriggers": sorted(validator.TRIGGERS),
            "stopCondition": "Stop after one coherent packet or any escalation trigger.",
            "independentReviewer": {
                "required": True,
                "threadId": "review-thread",
                "model": "gpt-5.6-sol",
                "effort": "high",
            },
            "context": {
                "mode": "full_authority_read",
                "packet": None,
                "verifiedHashes": [copy.deepcopy(self.input)],
            },
        }
        if classification == "FRONTIER_AUTHORITY":
            route["independentReviewer"] = {"required": False, "threadId": None, "model": None, "effort": None}
        return route

    def assert_valid(self, route: dict) -> None:
        self.assertEqual([], validator.validate_route(route, self.repo))

    def assert_invalid(self, route: dict, fragment: str) -> None:
        errors = validator.validate_route(route, self.repo)
        self.assertTrue(any(fragment in error for error in errors), errors)

    def add_composition_contract(self, route: dict, candidate: str | None) -> None:
        command = "python3 aggregate_composed_screen.py"
        contract = {
            "schema": 1,
            "kind": "composed_screen_contract",
            "taskId": route["taskId"],
            "routeId": route["routeId"],
            "comparisonRequired": True,
            "baselineCommit": self.baseline,
            "candidateCommit": candidate,
            "fixtureSha256": "a" * 64,
            "viewports": [
                {
                    "id": "regular", "width": 1280, "height": 800,
                    "minMapFraction": 0.60, "maxGuidanceLayers": 1,
                },
                {
                    "id": "compact", "width": 900, "height": 600,
                    "minMapFraction": 0.50, "maxGuidanceLayers": 1,
                },
            ],
            "candidateAssetProfileSha256": "b" * 64,
            "aggregateCommand": command,
        }
        path = self.repo / "inputs" / "composed-screen.json"
        path.write_text(json.dumps(contract), encoding="utf-8")
        binding = self._binding("inputs/composed-screen.json")
        route["compositionContract"] = {**binding, "aggregateCommand": command}
        route["authority"]["immutableInputs"].append(copy.deepcopy(binding))
        route["validation"]["fullCommands"].append(command)

    def add_swift_execution(
        self,
        route: dict,
        raw_command: str = "swift test --package-path Native/CitySimNative --filter FocusedTests",
        *,
        attempt: int = 1,
        prior: dict | None = None,
    ) -> str:
        build_root = str((self.repo / "swift-build").resolve())
        lock_dir = str((self.repo / "swift-locks").resolve())
        log_path = str((self.repo / "swift-proof.log").resolve())
        receipt_path = str((self.repo / "swift-proof.json").resolve())
        lease_id = f"{route['routeId']}:focused"
        command = shlex.join([
            "python3", "inputs/swift-runner.py",
            "--lease-id", lease_id,
            "--build-root", build_root,
            "--lock-dir", lock_dir,
            "--log", log_path,
            "--metadata", receipt_path,
            "--validator", "inputs/route-validator.py",
            "--", *shlex.split(raw_command),
        ])
        route["validation"]["focusedCommands"] = [command]
        route["swiftExecution"] = {
            "schema": 1,
            "runner": self._binding("inputs/swift-runner.py"),
            "resultValidator": self._binding("inputs/route-validator.py"),
            "terminalPolicy": validator.SWIFT_TERMINAL_POLICY,
            "executions": [{
                "command": command,
                "leaseId": lease_id,
                "buildRoot": build_root,
                "lockDir": lock_dir,
                "attempt": attempt,
                "logPath": log_path,
                "receiptPath": receipt_path,
                "priorAttemptReceipt": prior,
            }],
        }
        return command

    def add_writer_execution(self, route: dict) -> tuple[Path, Path, str]:
        root = (self.repo / "writer-output").resolve()
        root.mkdir()
        required = root / "inputs" / "source.json"
        required.parent.mkdir()
        required.write_text('{"source":true}\n', encoding="utf-8")
        output = root / "materialized" / "successor.json"
        receipt = root / "receipts" / "writer.json"
        command = shlex.join([
            "env", "CITYSIM_WRITER_MODE=successor", "CITYSIM_SEED=131",
            "python3", "inputs/writer.py", "--output-root", str(root),
        ])
        route["validation"]["focusedCommands"].append(command)
        route["writerExecution"] = {
            "schema": 1,
            "generatedOutputRoot": str(root),
            "writers": [{
                "writerId": "successor-corpus",
                "command": command,
                "environment": {
                    "CITYSIM_WRITER_MODE": "successor",
                    "CITYSIM_SEED": "131",
                },
                "artifacts": [
                    {
                        "phase": "required_input",
                        "path": "inputs/source.json",
                        "sha256": hashlib.sha256(required.read_bytes()).hexdigest(),
                    },
                    {
                        "phase": "prospective_output",
                        "path": "materialized/successor.json",
                        "sha256": None,
                    },
                    {
                        "phase": "post_execution_receipt",
                        "path": "receipts/writer.json",
                        "sha256": None,
                    },
                ],
            }],
        }
        return output, receipt, command

    def make_visual_route(self, root: str) -> dict:
        route = self.route()
        (self.repo / "claims" / "PLAY-999.md").write_text(
            f"# PLAY-999\nOwn `{root}` and `owned`.\n", encoding="utf-8"
        )
        route["authority"]["claim"] = self._binding("claims/PLAY-999.md")
        route["pathPolicy"]["claimOwnedRoots"] = [root, "owned"]
        route["pathPolicy"]["allowed"] = [root, "owned/evidence"]
        self.add_composition_contract(route, None)
        return route

    def acceptance_route(self) -> dict:
        route = self.route("FRONTIER_AUTHORITY", "acceptance")
        route["proofPolicy"].update(
            {
                "deliverableClaims": ["visual_quality", "real_app_interaction"],
                "focusedProofLevel": "static_only",
                "fullProofLevel": "real_app_journey",
                "behavioralCommands": ["fresh-player real-app final journey"],
            }
        )
        route["assignment"].update(
            {
                "threadId": "qa-thread",
                "featureAuthorThreadId": "author-thread",
                "finalQAOwnership": True,
                "subjectiveJudgmentRequired": True,
            }
        )
        route["validation"]["focusedGateOwner"]["threadId"] = "fixture-thread"
        route["validation"]["fullGateOwner"]["threadId"] = "qa-thread"
        route["validation"]["fullCommands"] = ["fresh-player real-app final journey"]
        route["independentReviewer"] = {
            "required": True,
            "threadId": "qa-thread",
            "model": "gpt-5.6-sol",
            "effort": "high",
        }
        self.add_composition_contract(route, self.head)
        return route

    def qa_handoff(self) -> dict:
        route = self.acceptance_route()
        route_path = self.repo / "inputs" / "qa-route.json"
        route_path.write_text(json.dumps(route), encoding="utf-8")
        dispatch = {
            "schema": 2,
            "authorityCommit": self.head,
            "assignments": [
                {
                    "modelRouteSha256": validator.canonical_sha(route),
                    "modelRoute": copy.deepcopy(route),
                }
            ],
        }
        dispatch_path = self.repo / "inputs" / "qa-dispatch.json"
        dispatch_path.write_text(json.dumps(dispatch), encoding="utf-8")
        app_root = self.repo / "stage" / "CitySim.app"
        executable = app_root / "Contents" / "MacOS" / "CitySim"
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_text("staged application bytes\n", encoding="utf-8")
        (app_root / "Contents" / "Info.plist").write_bytes(
            plistlib.dumps({"CFBundleExecutable": "CitySim"})
        )
        data_root = self.repo / "qa-data"
        data_root.mkdir(exist_ok=True)
        digest = subprocess.check_output(
            ["bash", str(self.repo / "script" / "canonical_tree_digest.sh"), str(app_root)],
            text=True,
        ).strip()
        return {
            "schema": 1,
            "kind": "qa_handoff",
            "taskId": "PLAY-999",
            "route": self._binding("inputs/qa-route.json"),
            "dispatch": self._binding("inputs/qa-dispatch.json"),
            "candidate": {"ref": "HEAD", "commit": self.head},
            "stage": {
                "appRoot": str(app_root),
                "sha256": digest,
                "producer": copy.deepcopy(self.producer),
            },
            "launch": {
                "command": [str(executable)],
                "environment": {
                    "CITYSIM_DATA_ROOT": str(data_root),
                    "CITYSIM_COMPACT_WINDOW": "1",
                },
                "expectedWindow": {"width": 900, "height": 600},
                "pidVerification": {
                    "required": True,
                    "command": ["ps", "eww", "-p", "{pid}"],
                },
            },
        }

    def test_all_supported_route_tuples(self) -> None:
        kinds = {
            "FRONTIER_AUTHORITY": "authority",
            "LUNA_IMPLEMENTATION": "implementation",
            "LUNA_MECHANICAL": "mechanical",
            "LUNA_LOCAL_DEBUG": "local_debug",
        }
        for classification, kind in kinds.items():
            with self.subTest(classification=classification):
                self.assert_valid(self.route(classification, kind))

    def test_unsupported_or_wrong_model_route_fails(self) -> None:
        route = self.route()
        route["classification"] = "CHEAP_UNKNOWN"
        self.assert_invalid(route, "unsupported model route")
        route = self.route()
        route["model"] = "gpt-5.6-sol"
        self.assert_invalid(route, "requires model/effort")

    def test_luna_cannot_own_authority_or_final_qa(self) -> None:
        for key in ("sharedAuthorityOwnership", "finalQAOwnership", "subjectiveJudgmentRequired"):
            route = self.route()
            route["assignment"][key] = True
            with self.subTest(key=key):
                self.assert_invalid(route, "Luna cannot own")

    def test_every_escalation_trigger_is_required(self) -> None:
        for trigger in validator.TRIGGERS:
            route = self.route()
            route["escalationTriggers"].remove(trigger)
            with self.subTest(trigger=trigger):
                self.assert_invalid(route, "exact mandatory set")

    def test_claim_and_allowed_paths_are_exact(self) -> None:
        route = self.route()
        route["pathPolicy"]["allowed"] = ["outside"]
        self.assert_invalid(route, "outside claim-owned roots")
        route = self.route()
        route["pathPolicy"]["claimOwnedRoots"] = ["unclaimed"]
        route["pathPolicy"]["allowed"] = ["unclaimed"]
        self.assert_invalid(route, "claim does not literally own root")
        route = self.route()
        route["pathPolicy"]["allowed"] = ["owned/../claims"]
        self.assert_invalid(route, "not an exact normalized")

    def test_luna_cannot_mutate_shared_authority_roots(self) -> None:
        route = self.route()
        route["pathPolicy"]["claimOwnedRoots"] = ["docs/production/claims"]
        route["pathPolicy"]["allowed"] = ["docs/production/claims"]
        route["pathPolicy"]["forbidden"] = ["outside"]
        (self.repo / "claims" / "PLAY-999.md").write_text(
            "# PLAY-999\nOwn `docs/production/claims/`.\n", encoding="utf-8"
        )
        route["authority"]["claim"]["sha256"] = hashlib.sha256(
            (self.repo / "claims" / "PLAY-999.md").read_bytes()
        ).hexdigest()
        self.assert_invalid(route, "shared-authority root")

    def test_focused_and_full_gate_ownership_are_distinct(self) -> None:
        route = self.route()
        route["validation"]["fullGateOwner"]["threadId"] = "worker-thread"
        self.assert_invalid(route, "must be distinct")

    def test_luna_focused_gate_rejects_aggregate_commands(self) -> None:
        route = self.route()
        route["validation"]["focusedCommands"] = ["swift test --package-path Native/CitySimNative"]
        self.assert_invalid(route, "aggregate/final command")
        route["validation"]["focusedCommands"] = ["swift test --package-path Native/CitySimNative --filter FocusedTests"]
        self.assert_invalid(route, "requires an exact swiftExecution contract")
        self.add_swift_execution(route)
        self.assert_valid(route)

    def test_raw_swift_route_is_rejected_and_bound_runner_passes(self) -> None:
        route = self.route("FRONTIER_AUTHORITY", "authority")
        route["validation"]["fullCommands"] = ["swift test --package-path Native/CitySimNative"]
        self.assert_invalid(route, "requires an exact swiftExecution contract")
        command = self.add_swift_execution(route)
        route["validation"]["fullCommands"] = [command]
        route["validation"]["focusedCommands"] = ["python3 focused_check.py"]
        self.assert_valid(route)

    def test_swift_retry_requires_terminal_descendant_free_prior_receipt(self) -> None:
        route = self.route()
        self.add_swift_execution(route, attempt=2)
        self.assert_invalid(route, "requires a terminal priorAttemptReceipt")

        row = route["swiftExecution"]["executions"][0]
        prior_path = self.repo / "inputs" / "prior-swift-attempt.json"
        prior_path.write_text(json.dumps({
            "status": "running",
            "terminal": False,
            "parentExited": False,
            "processGroupExited": False,
            "descendantsExited": False,
            "liveProcessGroupPids": [123],
            "liveObservedDescendantPids": [124],
            "leaseId": row["leaseId"],
            "buildRoot": row["buildRoot"],
            "exitCode": 0,
            "logSha256": "a" * 64,
        }), encoding="utf-8")
        row["priorAttemptReceipt"] = self._binding("inputs/prior-swift-attempt.json")
        self.assert_invalid(route, "not terminal and descendant-free")

        prior_path.write_text(json.dumps({
            "status": "terminal",
            "terminal": True,
            "parentExited": True,
            "processGroupExited": True,
            "descendantsExited": True,
            "liveProcessGroupPids": [],
            "liveObservedDescendantPids": [],
            "leaseId": row["leaseId"],
            "buildRoot": row["buildRoot"],
            "exitCode": 1,
            "logSha256": "b" * 64,
        }), encoding="utf-8")
        row["priorAttemptReceipt"] = self._binding("inputs/prior-swift-attempt.json")
        self.assert_valid(route)

    def test_writer_execution_binds_environment_root_and_phases(self) -> None:
        route = self.route()
        output, _, _ = self.add_writer_execution(route)
        self.assert_valid(route)

        route["writerExecution"]["writers"][0]["environment"]["EXTRA"] = "forbidden"
        self.assert_invalid(route, "must exactly match command environment")
        del route["writerExecution"]["writers"][0]["environment"]["EXTRA"]

        route["writerExecution"]["writers"][0]["artifacts"][1]["path"] = "../escape.json"
        self.assert_invalid(route, "normalized root-relative")
        route["writerExecution"]["writers"][0]["artifacts"][1]["path"] = "materialized/successor.json"

        output.parent.mkdir()
        output.write_text("stale\n", encoding="utf-8")
        self.assert_invalid(route, "prospective_output already exists")

    def test_writer_execution_rejects_missing_or_unbound_required_input(self) -> None:
        route = self.route()
        self.add_writer_execution(route)
        artifact = route["writerExecution"]["writers"][0]["artifacts"][0]
        artifact["sha256"] = "0" * 64
        self.assert_invalid(route, "required_input sha256 does not match")
        artifact["path"] = "inputs/missing.json"
        self.assert_invalid(route, "required_input does not exist")

    def test_writer_receipt_binds_terminal_outputs_and_generated_bytes(self) -> None:
        route = self.route()
        output, receipt_path, command = self.add_writer_execution(route)
        output.parent.mkdir()
        output.write_text('{"successor":6}\n', encoding="utf-8")
        receipt_path.parent.mkdir()
        receipt = {
            "schema": 1,
            "routeId": route["routeId"],
            "writerId": "successor-corpus",
            "command": command,
            "environment": {
                "CITYSIM_WRITER_MODE": "successor",
                "CITYSIM_SEED": "131",
            },
            "generatedOutputRoot": route["writerExecution"]["generatedOutputRoot"],
            "status": "terminal",
            "exitCode": 0,
            "outputs": [{
                "path": "materialized/successor.json",
                "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
            }],
        }
        receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
        self.assertEqual([], validator.validate_route(
            route, self.repo, writer_phase="post_execution"
        ))
        self.assertEqual([], validator.validate_writer_receipt(
            receipt, receipt_path, route
        ))

        receipt["outputs"][0]["sha256"] = "0" * 64
        errors = validator.validate_writer_receipt(receipt, receipt_path, route)
        self.assertTrue(any("does not match generated bytes" in error for error in errors), errors)

    def test_executable_claim_requires_real_focused_behavior(self) -> None:
        route = self.route()
        route["proofPolicy"]["deliverableClaims"] = ["executable_behavior"]
        self.assert_invalid(route, "requires focused proof level contained_smoke")
        command = "blender --background --python smoke.py"
        route["proofPolicy"]["focusedProofLevel"] = "contained_smoke"
        route["proofPolicy"]["fullProofLevel"] = "contained_smoke"
        route["proofPolicy"]["behavioralCommands"] = [command]
        route["validation"]["focusedCommands"].append(command)
        self.assert_valid(route)

    def test_behavioral_command_must_be_an_exact_focused_gate(self) -> None:
        route = self.route()
        route["proofPolicy"].update(
            {
                "deliverableClaims": ["executable_behavior"],
                "focusedProofLevel": "contained_smoke",
                "fullProofLevel": "contained_smoke",
                "behavioralCommands": ["python3 actual_behavior.py"],
            }
        )
        self.assert_invalid(route, "not an exact command of the gate")

    def test_behavioral_command_must_be_shell_parseable(self) -> None:
        route = self.route()
        command = "python3 smoke.py --path '/tmp/James's Files/output'"
        route["proofPolicy"].update(
            {
                "deliverableClaims": ["executable_behavior"],
                "focusedProofLevel": "contained_smoke",
                "fullProofLevel": "contained_smoke",
                "behavioralCommands": [command],
            }
        )
        route["validation"]["focusedCommands"].append(command)
        self.assert_invalid(route, "not shell-parseable")

    def test_static_candidate_can_defer_real_smoke_to_full_gate(self) -> None:
        route = self.route("FRONTIER_AUTHORITY", "authority")
        command = "blender --background --python contained_smoke.py"
        route["proofPolicy"]["fullProofLevel"] = "contained_smoke"
        route["proofPolicy"]["behavioralCommands"] = [command]
        route["validation"]["fullCommands"] = [command]
        self.assert_valid(route)

    def test_luna_cannot_invent_novel_architecture(self) -> None:
        route = self.route()
        route["proofPolicy"]["architectureState"] = "novel_or_ambiguous"
        route["proofPolicy"]["referenceImplementation"] = None
        self.assert_invalid(route, "Luna cannot own novel or ambiguous architecture")
        route = self.route("FRONTIER_AUTHORITY", "authority")
        route["proofPolicy"]["architectureState"] = "novel_or_ambiguous"
        route["proofPolicy"]["referenceImplementation"] = None
        self.assert_valid(route)

    def test_frozen_reference_requires_exact_bound_bytes(self) -> None:
        route = self.route()
        route["proofPolicy"]["referenceImplementation"] = None
        self.assert_invalid(route, "requires an exact referenceImplementation")
        route = self.route()
        route["proofPolicy"]["referenceImplementation"]["sha256"] = "0" * 64
        self.assert_invalid(route, "does not match repository bytes")

    def test_static_or_ast_checks_cannot_substitute_for_behavior(self) -> None:
        route = self.route()
        route["proofPolicy"]["prohibitedSubstitutions"].remove(
            "ast_shape_for_runtime_success"
        )
        self.assert_invalid(route, "exact mandatory set")
        route = self.route()
        route["proofPolicy"]["behavioralCommands"] = ["python3 token_scan.py"]
        self.assert_invalid(route, "static-only proof cannot declare behavioral commands")

    def test_mechanical_route_cannot_claim_executable_behavior(self) -> None:
        route = self.route("LUNA_MECHANICAL", "mechanical")
        command = "python3 execute_feature.py"
        route["proofPolicy"].update(
            {
                "deliverableClaims": ["executable_behavior"],
                "focusedProofLevel": "contained_smoke",
                "fullProofLevel": "contained_smoke",
                "behavioralCommands": [command],
            }
        )
        route["validation"]["focusedCommands"].append(command)
        self.assert_invalid(route, "LUNA_MECHANICAL cannot claim executable")

    def test_final_qa_cannot_use_feature_author_task(self) -> None:
        route = self.route("FRONTIER_AUTHORITY", "acceptance")
        route["proofPolicy"].update(
            {
                "deliverableClaims": ["visual_quality", "real_app_interaction"],
                "focusedProofLevel": "static_only",
                "fullProofLevel": "real_app_journey",
                "behavioralCommands": ["fresh-player real-app final journey"],
            }
        )
        route["assignment"].update({
            "threadId": "qa-thread", "featureAuthorThreadId": "qa-thread",
            "finalQAOwnership": True, "subjectiveJudgmentRequired": True,
        })
        route["validation"]["focusedGateOwner"]["threadId"] = "fixture-thread"
        route["validation"]["fullGateOwner"]["threadId"] = "qa-thread"
        route["validation"]["fullCommands"] = ["fresh-player real-app final journey"]
        route["independentReviewer"] = {
            "required": True, "threadId": "qa-thread", "model": "gpt-5.6-sol", "effort": "high"
        }
        self.assert_invalid(route, "requires compositionContract")
        self.add_composition_contract(route, self.head)
        self.assert_invalid(route, "feature-author")
        route["assignment"]["featureAuthorThreadId"] = "author-thread"
        self.assert_valid(route)

    def test_visual_routes_require_exact_composed_screen_contract(self) -> None:
        for root in validator.VISUAL_ROUTE_ROOTS:
            with self.subTest(root=root):
                route = self.make_visual_route(root)
                self.assert_valid(route)
                missing = copy.deepcopy(route)
                del missing["compositionContract"]
                self.assert_invalid(missing, "requires compositionContract")

    def test_composed_screen_contract_rejects_weak_map_or_unbound_command(self) -> None:
        route = self.make_visual_route(validator.VISUAL_ROUTE_ROOTS[0])
        contract_path = self.repo / route["compositionContract"]["path"]
        contract = json.loads(contract_path.read_text(encoding="utf-8"))
        contract["viewports"][1]["minMapFraction"] = 0.40
        contract_path.write_text(json.dumps(contract), encoding="utf-8")
        binding = self._binding("inputs/composed-screen.json")
        route["compositionContract"]["sha256"] = binding["sha256"]
        route["authority"]["immutableInputs"][-1] = binding
        self.assert_invalid(route, "minMapFraction")

        contract["viewports"][1]["minMapFraction"] = 0.50
        contract["aggregateCommand"] = "python3 different_aggregate.py"
        contract_path.write_text(json.dumps(contract), encoding="utf-8")
        binding = self._binding("inputs/composed-screen.json")
        route["compositionContract"]["sha256"] = binding["sha256"]
        route["authority"]["immutableInputs"][-1] = binding
        self.assert_invalid(route, "aggregateCommand does not match")

        contract_path.write_text("{", encoding="utf-8")
        binding = self._binding("inputs/composed-screen.json")
        route["compositionContract"]["sha256"] = binding["sha256"]
        route["authority"]["immutableInputs"][-1] = binding
        self.assert_invalid(route, "cannot load compositionContract")

    def test_compact_context_requires_exact_bound_packet(self) -> None:
        route = self.route()
        route["context"] = {"mode": "compact_continuation", "packet": None, "verifiedHashes": [self.input]}
        self.assert_invalid(route, "requires a bound context packet")

    def test_dispatch_projects_exact_route(self) -> None:
        route = self.route()
        dispatch = {
            "schema": 2,
            "authorityCommit": self.head,
            "assignments": [{"modelRouteSha256": validator.canonical_sha(route), "modelRoute": copy.deepcopy(route)}],
        }
        self.assertEqual([], validator.validate_dispatch(dispatch, self.repo))
        dispatch["assignments"][0]["modelRoute"]["effort"] = "medium"
        errors = validator.validate_dispatch(dispatch, self.repo)
        self.assertTrue(any("canonical route JSON" in error for error in errors), errors)

    def _route_local_dispatch(self) -> tuple[dict, str, str]:
        stale_sibling = self.route()
        stale_sibling["routeId"] = "PLAY-999:sibling:v1"
        stale_sibling["assignment"]["threadId"] = "sibling-thread"
        stale_sibling["validation"]["focusedGateOwner"]["threadId"] = "sibling-thread"
        stale_sibling["independentReviewer"]["threadId"] = "sibling-review-thread"

        (self.repo / "inputs" / "live-head.txt").write_text("advance\n", encoding="utf-8")
        subprocess.run(
            ["git", "-C", str(self.repo), "add", "inputs/live-head.txt"], check=True
        )
        subprocess.run(
            ["git", "-C", str(self.repo), "commit", "-qm", "advance live head"], check=True
        )
        live_head = subprocess.check_output(
            ["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True
        ).strip()

        selected = self.route()
        selected["routeId"] = "PLAY-999:selected:v1"
        selected["assignment"]["expectedHead"] = live_head
        dispatch = {
            "schema": 2,
            "authorityCommit": self.head,
            "assignments": [
                {
                    "modelRouteSha256": validator.canonical_sha(stale_sibling),
                    "modelRoute": stale_sibling,
                },
                {
                    "modelRouteSha256": validator.canonical_sha(selected),
                    "modelRoute": selected,
                },
            ],
        }
        return dispatch, stale_sibling["routeId"], selected["routeId"]

    def test_dispatch_route_selection_is_exact_and_isolates_sibling_drift(self) -> None:
        dispatch, _, selected_id = self._route_local_dispatch()
        all_errors = validator.validate_dispatch(dispatch, self.repo)
        self.assertTrue(any("assignment HEAD mismatch" in error for error in all_errors), all_errors)
        self.assertEqual(
            [], validator.validate_dispatch(dispatch, self.repo, selected_id)
        )

    def test_dispatch_route_selection_rejects_unknown_route(self) -> None:
        dispatch, _, _ = self._route_local_dispatch()
        errors = validator.validate_dispatch(dispatch, self.repo, "PLAY-999:missing:v1")
        self.assertTrue(any("routeId not found" in error for error in errors), errors)

    def test_dispatch_route_selection_rejects_duplicate_route_ids(self) -> None:
        dispatch, _, selected_id = self._route_local_dispatch()
        dispatch["assignments"][0]["modelRoute"]["routeId"] = selected_id
        dispatch["assignments"][0]["modelRouteSha256"] = validator.canonical_sha(
            dispatch["assignments"][0]["modelRoute"]
        )
        errors = validator.validate_dispatch(dispatch, self.repo, selected_id)
        self.assertTrue(any("duplicate routeId" in error for error in errors), errors)

    def test_dispatch_route_selection_enforces_selected_live_identity(self) -> None:
        dispatch, stale_id, _ = self._route_local_dispatch()
        errors = validator.validate_dispatch(dispatch, self.repo, stale_id)
        self.assertTrue(any("assignment HEAD mismatch" in error for error in errors), errors)

    def test_qa_handoff_binds_route_dispatch_candidate_stage_and_launch(self) -> None:
        handoff = self.qa_handoff()
        self.assertEqual([], validator.validate_qa_handoff(handoff, self.repo))

    def test_qa_handoff_uses_declared_bundle_executable(self) -> None:
        handoff = self.qa_handoff()
        original = Path(handoff["launch"]["command"][0])
        native = original.with_name("CitySimNative")
        original.rename(native)
        info_path = native.parent.parent / "Info.plist"
        info_path.write_bytes(plistlib.dumps({"CFBundleExecutable": "CitySimNative"}))
        handoff["launch"]["command"] = [str(native)]
        handoff["stage"]["sha256"] = subprocess.check_output(
            ["bash", str(self.repo / "script" / "canonical_tree_digest.sh"), handoff["stage"]["appRoot"]],
            text=True,
        ).strip()
        self.assertEqual([], validator.validate_qa_handoff(handoff, self.repo))

    def test_qa_handoff_accepts_exact_launchservices_environment(self) -> None:
        handoff = self.qa_handoff()
        app_root = handoff["stage"]["appRoot"]
        environment = handoff["launch"]["environment"]
        handoff["launch"]["command"] = [
            "/usr/bin/open", "-n",
            "--env", f"CITYSIM_DATA_ROOT={environment['CITYSIM_DATA_ROOT']}",
            "--env", f"CITYSIM_COMPACT_WINDOW={environment['CITYSIM_COMPACT_WINDOW']}",
            app_root,
        ]
        self.assertEqual([], validator.validate_qa_handoff(handoff, self.repo))

    def test_qa_handoff_rejects_substituted_launcher_target_or_bundle_executable(self) -> None:
        def launchservices_command(handoff: dict) -> list[str]:
            environment = handoff["launch"]["environment"]
            return [
                "/usr/bin/open", "-n",
                "--env", f"CITYSIM_DATA_ROOT={environment['CITYSIM_DATA_ROOT']}",
                "--env", f"CITYSIM_COMPACT_WINDOW={environment['CITYSIM_COMPACT_WINDOW']}",
                handoff["stage"]["appRoot"],
            ]

        handoff = self.qa_handoff()
        handoff["launch"]["command"] = launchservices_command(handoff)
        handoff["launch"]["command"][0] = "/usr/bin/env"
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("directly invoke" in error for error in errors), errors)

        handoff = self.qa_handoff()
        handoff["launch"]["command"] = launchservices_command(handoff)[:-1] + [str(self.repo / "wrong.app")]
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("directly invoke" in error for error in errors), errors)

        handoff = self.qa_handoff()
        command = launchservices_command(handoff)
        command[5] = command[3]
        handoff["launch"]["command"] = command
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("directly invoke" in error for error in errors), errors)

        handoff = self.qa_handoff()
        info_path = Path(handoff["stage"]["appRoot"]) / "Contents" / "Info.plist"
        info_path.write_bytes(plistlib.dumps({"CFBundleExecutable": "../CitySim"}))
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("CFBundleExecutable" in error for error in errors), errors)

        handoff = self.qa_handoff()
        Path(handoff["launch"]["command"][0]).unlink()
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("does not resolve to a file" in error for error in errors), errors)

    def test_qa_handoff_rejects_missing_or_substituted_contracts(self) -> None:
        handoff = self.qa_handoff()
        del handoff["launch"]
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("unsupported or missing fields" in error for error in errors), errors)

        handoff = self.qa_handoff()
        handoff["route"]["sha256"] = "0" * 64
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("does not match repository bytes" in error for error in errors), errors)

        handoff = self.qa_handoff()
        handoff["stage"]["producer"] = copy.deepcopy(self.input)
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("canonical_tree_digest.sh" in error for error in errors), errors)

    def test_qa_handoff_rejects_candidate_or_dispatch_drift(self) -> None:
        handoff = self.qa_handoff()
        handoff["candidate"]["commit"] = self.baseline
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("does not resolve" in error for error in errors), errors)

        handoff = self.qa_handoff()
        dispatch_path = self.repo / handoff["dispatch"]["path"]
        dispatch = json.loads(dispatch_path.read_text(encoding="utf-8"))
        dispatch["assignments"][0]["modelRoute"]["boundedDeliverable"] = "Drifted."
        dispatch["assignments"][0]["modelRouteSha256"] = validator.canonical_sha(
            dispatch["assignments"][0]["modelRoute"]
        )
        dispatch_path.write_text(json.dumps(dispatch), encoding="utf-8")
        handoff["dispatch"] = self._binding("inputs/qa-dispatch.json")
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("does not embed the exact" in error for error in errors), errors)

    def test_qa_handoff_rejects_stage_or_launch_drift(self) -> None:
        handoff = self.qa_handoff()
        executable = Path(handoff["launch"]["command"][0])
        executable.write_text("mutated staged bytes\n", encoding="utf-8")
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("staged-app seal" in error for error in errors), errors)

        handoff = self.qa_handoff()
        del handoff["launch"]["environment"]["CITYSIM_COMPACT_WINDOW"]
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("CITYSIM_COMPACT_WINDOW=1" in error for error in errors), errors)

        handoff = self.qa_handoff()
        handoff["launch"]["pidVerification"]["command"] = ["pgrep", "CitySim"]
        errors = validator.validate_qa_handoff(handoff, self.repo)
        self.assertTrue(any("actual-PID" in error for error in errors), errors)

    def test_swift_test_log_requires_result_bearing_pass_summary(self) -> None:
        xctest = (
            "Test Suite 'Selected tests' passed.\n"
            "Executed 59 tests, with 0 failures (0 unexpected) in 2.4 seconds\n"
        )
        swift_testing = "✔ Test run with 3 tests passed after 0.012 seconds.\n"
        self.assertEqual([], validator.validate_swift_test_log(xctest))
        self.assertEqual([], validator.validate_swift_test_log(swift_testing))

    def test_swift_test_log_rejects_compilation_only_or_zero_tests(self) -> None:
        errors = validator.validate_swift_test_log("Build complete! (4.21s)\n")
        self.assertTrue(any("compilation_only" in error for error in errors), errors)
        errors = validator.validate_swift_test_log(
            "Executed 0 tests, with 0 failures (0 unexpected) in 0.0 seconds\n"
        )
        self.assertTrue(any("zero tests" in error for error in errors), errors)

    def test_swift_test_log_rejects_failure_or_missing_summary(self) -> None:
        errors = validator.validate_swift_test_log(
            "Executed 2 tests, with 1 failure (0 unexpected) in 0.2 seconds\n"
        )
        self.assertTrue(any("failing" in error for error in errors), errors)
        errors = validator.validate_swift_test_log("Test Case passed\n")
        self.assertTrue(any("lacks a positive" in error for error in errors), errors)

    def test_unchanged_passing_sibling_cannot_be_demoted(self) -> None:
        previous = {"cells": [
            {"direction": "east", "state": "returned", "claimRevision": "a"},
            {"direction": "south", "state": "integration_admitted", "claimRevision": "b", "sourceAdmissionReceipt": "sha"},
        ]}
        current = copy.deepcopy(previous)
        current["cells"][1]["state"] = "predesign"
        errors = validator.validate_siblings(previous, current, "east")
        self.assertTrue(any("south was demoted" in error for error in errors), errors)
        current = copy.deepcopy(previous)
        current["cells"][0]["state"] = "predesign"
        self.assertEqual([], validator.validate_siblings(previous, current, "east"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
