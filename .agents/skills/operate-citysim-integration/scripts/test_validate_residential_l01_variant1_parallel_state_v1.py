#!/usr/bin/env python3
"""Adversarial execution tests for Residential L1 variant-one controls."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[4]
VALIDATOR = Path(__file__).with_name("validate_residential_l01_variant1_parallel_state_v1.py")
SCHEDULE = ROOT / "docs/production/evidence/INTEGRATION/RESIDENTIAL-L01-VARIANT1-PARALLEL-SCHEDULE-V1.json"
SPEC = importlib.util.spec_from_file_location("residential_controls", VALIDATOR)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ResidentialControlTests(unittest.TestCase):
    def setUp(self) -> None:
        self.valid = json.loads(SCHEDULE.read_text())
        self.temp = tempfile.TemporaryDirectory()
        self.route_root = Path(self.temp.name)
        (self.route_root / "routes").mkdir()

    def tearDown(self) -> None:
        self.temp.cleanup()

    def project(self, data: dict) -> None:
        rows = [
            {key: row[key] for key in ("cell", "taskId", "threadId", "head", "state", "dispatchState", "cleanState", "observedAt")} | {"claimRevision": row["claim"]["sha256"]}
            for row in data["cells"]
        ]
        projection = {"batchId": data["batchId"], "phase": data["phase"], "rows": rows}
        data["ledgerProjection"] = copy.deepcopy(projection)
        data["dispatchProjection"] = copy.deepcopy(projection)
        data["ledgerSha256"] = MODULE.canonical_sha(projection)

    def bind_route(self, data: dict, row: dict) -> None:
        requirement = row["routeRequirement"]
        route_id = f"quality-v2:{row['taskId'].lower()}-{data['phase']}-{row['cell']}-test"
        route = {
            "schema": 2,
            "routeId": route_id,
            "taskId": row["taskId"],
            "classification": requirement["classification"],
            "model": requirement["model"],
            "effort": requirement["effort"],
            "authority": {"authorityCommit": data["authorityCommit"]},
            "assignment": {
                "threadId": row["threadId"],
                "branch": row["branch"],
                "worktree": row["worktree"],
                "expectedHead": row["head"],
            },
        }
        route_sha = MODULE.canonical_sha(route)
        receipt = {"schema": 2, "authorityCommit": data["authorityCommit"], "assignments": [{"modelRouteSha256": route_sha, "modelRoute": route}]}
        path = self.route_root / "routes" / f"{row['cell']}.json"
        payload = (json.dumps(receipt, indent=2) + "\n").encode()
        path.write_bytes(payload)
        row["routeReceipt"] = {
            "path": f"routes/{row['cell']}.json",
            "sha256": hashlib.sha256(payload).hexdigest(),
            "routeId": route_id,
            "modelRouteSha256": route_sha,
        }

    def activate(self, data: dict, phase: str, previous_phase: str) -> None:
        data["previousPhase"] = previous_phase
        data["phase"] = phase
        data["dispatchReady"] = True
        job_refs = []
        for index, row in enumerate(data["cells"]):
            row["headStatus"] = "current"
            row["dispatchState"] = "working"
            row["eligibleUsefulWork"] = True
            row["dependency"] = {
                "status": "ready",
                "ownerThreadId": row["threadId"],
                "resumptionEvent": "none_active_now",
                "unavailablePreparation": "none_active_now",
                "nextRefill": "Complete the bounded phase work and return evidence.",
            }
            classification, model, effort = MODULE.required_route(row["cell"], phase)
            row["routeRequirement"] = {
                "classification": classification,
                "model": model,
                "effort": effort,
                "escalationTriggers": sorted(MODULE.ESCALATIONS),
            }
            row["permissions"] = MODULE.permission_projection(row["cell"], phase)
            row["authorityAcknowledgement"] = {
                "threadId": row["threadId"],
                "authorityCommit": data["authorityCommit"],
                "claimRevision": row["claim"]["sha256"],
                "acknowledgedAt": "2026-08-02T19:59:00-04:00",
                "boundedDeliverable": row["boundedDeliverable"],
                "stopCondition": row["stopCondition"],
                "evidenceId": f"thread:{row['threadId']}/turn:test/item:ack",
            }
            job_id = f"{row['cell']}-proof"
            row["executionAccounting"]["launchedJobs"] = [{
                "id": job_id,
                "batchId": data["batchId"],
                "claimSha256": row["claim"]["sha256"],
                "publishedBase": data["authorityCommit"],
                "head": row["observedHead"] or row["head"],
                "threadId": row["threadId"],
                "branch": row["branch"],
                "worktree": row["worktree"],
                "resourceClass": "helper",
                "mutationClass": "read_only",
                "exclusiveRoot": row["ownedRoots"][0],
                "processSlot": None,
                "state": "completed",
                "startedAt": "2026-08-02T20:00:00-04:00",
                "endedAt": "2026-08-02T20:10:00-04:00",
                "evidenceId": f"thread:{row['threadId']}/turn:test/item:{job_id}",
            }]
            row["executionAccounting"]["running"] = []
            row["executionAccounting"]["waitingOnJoin"] = []
            row["executionAccounting"]["capacity"] = {"helperSlots": 0, "dccSlots": 0}
            row["executionAccounting"]["unusedCapacityReasons"] = []
            row["executionAccounting"]["join"] = {"state": "not_required", "requiredJobs": [], "completedJobs": []}
            self.bind_route(data, row)
            if index < 3:
                job_refs.append({"cell": row["cell"], "jobId": job_id})
        data["parallelismProof"] = {
            "requiredConcurrentCells": 3,
            "eligibleCells": [row["cell"] for row in data["cells"]],
            "jobRefs": job_refs,
            "startedAt": "2026-08-02T20:00:00-04:00",
            "endedAt": "2026-08-02T20:10:00-04:00",
        }
        self.project(data)

    def validate_fixture(self, data: dict) -> dict:
        return MODULE.validate_schedule(
            data,
            ROOT,
            check_live=False,
            check_repository=False,
            route_root=self.route_root,
            route_runner=lambda *_: None,
        )

    def assert_fails(self, data: dict) -> None:
        with self.assertRaises(MODULE.ControlError):
            self.validate_fixture(data)

    def test_current_blocked_schedule_binds_authority_blobs_and_live_heads(self) -> None:
        result = MODULE.validate_schedule(self.valid, ROOT)
        self.assertFalse(result["dispatchReady"])
        self.assertEqual(result["eligibleCells"], [])

    def test_positive_prelock_transition_with_real_schema2_receipt_projection(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        result = self.validate_fixture(data)
        self.assertTrue(result["dispatchReady"])

    def test_positive_direction_local_return_preserves_siblings(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "abc_active", "abc_active")
        for row in data["cells"][:4]:
            row["previousState"] = "source_candidate"
            row["state"] = "source_candidate"
        data["cells"][1]["state"] = "returned"
        data["cells"][4].update(previousState="intake_ready", state="intake_ready")
        data["cells"][5].update(previousState="preregistered", state="preregistered")
        self.project(data)
        self.assertEqual(self.validate_fixture(data)["phase"], "abc_active")

    def test_positive_exact_four_of_four_ready_transition(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "4of4_ready", "abc_active")
        for row in data["cells"][:4]:
            row.update(previousState="integration_admitted", state="renderer_quarantined")
        data["cells"][4].update(previousState="intake_ready", state="quarantining")
        data["cells"][5].update(previousState="preregistered", state="preregistered")
        data["familyActivation"].update(
            state="ready_for_atomic_activation",
            admittedDirections=list(MODULE.DIRECTIONS),
            quarantinedDirections=list(MODULE.DIRECTIONS),
            atomicAssemblyManifest={"path": "evidence/atomic.json", "sha256": "a" * 64},
        )
        self.project(data)
        self.assertEqual(self.validate_fixture(data)["phase"], "4of4_ready")

    def test_positive_atomic_candidate_to_distinct_final_qa(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "exact_candidate_qa", "4of4_ready")
        for row in data["cells"][:4]:
            row.update(previousState="renderer_quarantined", state="renderer_quarantined")
        data["cells"][4].update(previousState="quarantining", state="4of4_assembled")
        data["cells"][5].update(previousState="preregistered", state="exact_candidate_active")
        data["familyActivation"].update(
            state="exact_candidate_active",
            admittedDirections=list(MODULE.DIRECTIONS),
            quarantinedDirections=list(MODULE.DIRECTIONS),
            atomicAssemblyManifest={"path": "evidence/atomic.json", "sha256": "a" * 64},
            rendererCandidateReceipt={"path": "evidence/candidate.json", "sha256": "b" * 64},
        )
        self.project(data)
        self.assertEqual(self.validate_fixture(data)["phase"], "exact_candidate_qa")

    def test_rejects_valid_but_stale_dispatch_head(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        data["cells"][0]["headStatus"] = "stale_pre_authority"
        self.assert_fails(data)

    def test_rejects_task_claim_thread_branch_worktree_or_live_head_drift(self) -> None:
        mutations = (
            lambda d: d["cells"][0].update(taskId="PLAY-999"),
            lambda d: d["cells"][0]["claim"].update(path="docs/production/claims/PLAY-091.world-art-east.md"),
            lambda d: d["cells"][0].update(threadId="wrong-thread"),
            lambda d: d["cells"][0].update(branch="wrong-branch"),
            lambda d: d["cells"][0].update(worktree="/private/tmp/wrong"),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                data = copy.deepcopy(self.valid)
                mutate(data)
                self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        data["cells"][0].update(head=data["authorityCommit"], headStatus="current")
        self.project(data)
        with self.assertRaises(MODULE.ControlError):
            MODULE.validate_schedule(data, ROOT)

    def test_rejects_working_tree_claim_substitution_for_authority_blob(self) -> None:
        data = copy.deepcopy(self.valid)
        data["cells"][0]["claim"]["sha256"] = "0" * 64
        with self.assertRaises(MODULE.ControlError):
            MODULE.validate_schedule(data, ROOT, check_live=False)

    def test_rejects_route_stub_or_route_projection_mismatch(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        path = self.route_root / "routes/north.json"
        payload = b'{"schema":1}\n'
        path.write_bytes(payload)
        data["cells"][0]["routeReceipt"]["sha256"] = hashlib.sha256(payload).hexdigest()
        self.assert_fails(data)

    def test_rejects_missing_route_tier_or_escalation_trigger(self) -> None:
        data = copy.deepcopy(self.valid)
        data["cells"][0]["routeRequirement"]["model"] = "gpt-5.6-luna"
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        data["cells"][1]["routeRequirement"]["escalationTriggers"].pop()
        self.assert_fails(data)

    def test_real_runner_calls_shared_model_route_validator(self) -> None:
        receipt = self.route_root / "route.json"
        receipt.write_text("{}")
        completed = subprocess.CompletedProcess([], 0, "PASS", "")
        with mock.patch.object(MODULE.subprocess, "run", return_value=completed) as run:
            MODULE.run_real_route_validator(ROOT, receipt, "quality-v2:test")
        argv = run.call_args.args[0]
        self.assertTrue(str(argv[1]).endswith("validate_model_route_v1.py"))
        self.assertIn("--dispatch-route-id", argv)

    def test_rejects_old_qa_task_or_non_distinct_final_reviewer(self) -> None:
        data = copy.deepcopy(self.valid)
        data["cells"][5]["threadId"] = "019f9a0a-35fa-75b1-92c4-73c182390a25"
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        data["finalQAReviewer"]["threadId"] = MODULE.QA_PREREG_THREAD
        self.assert_fails(data)

    def test_rejects_missing_acknowledgement_or_execution_accounting(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        data["cells"][0]["authorityAcknowledgement"] = None
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        data["cells"][0]["executionAccounting"].pop("nextRefill")
        self.assert_fails(data)

    def test_rejects_fabricated_parallelism_or_unexplained_capacity(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        data["parallelismProof"]["endedAt"] = "2026-08-02T20:20:00-04:00"
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        data["cells"][0]["executionAccounting"]["capacity"]["helperSlots"] = 1
        self.assert_fails(data)

    def test_rejects_ledger_projection_or_hash_drift(self) -> None:
        data = copy.deepcopy(self.valid)
        data["dispatchProjection"]["rows"][0]["head"] = "0" * 40
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        data["ledgerSha256"] = "0" * 64
        self.assert_fails(data)

    def test_rejects_return_that_demotes_a_passing_sibling(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "abc_active", "abc_active")
        for row in data["cells"][:4]:
            row.update(previousState="source_candidate", state="source_candidate")
        data["cells"][1]["state"] = "returned"
        data["cells"][2]["state"] = "predesign"
        data["cells"][4].update(previousState="intake_ready", state="intake_ready")
        data["cells"][5].update(previousState="preregistered", state="preregistered")
        self.project(data)
        self.assert_fails(data)

    def test_rejects_partial_four_of_four_or_early_candidate(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "4of4_ready", "abc_active")
        for row in data["cells"][:4]:
            row.update(previousState="integration_admitted", state="renderer_quarantined")
        data["cells"][4].update(previousState="intake_ready", state="quarantining")
        data["cells"][5].update(previousState="preregistered", state="preregistered")
        data["familyActivation"].update(
            state="ready_for_atomic_activation",
            admittedDirections=list(MODULE.DIRECTIONS),
            quarantinedDirections=["north", "east", "south"],
            atomicAssemblyManifest={"path": "evidence/atomic.json", "sha256": "a" * 64},
        )
        self.project(data)
        self.assert_fails(data)

    def test_rejects_prelock_shipping_or_sibling_transform_grant(self) -> None:
        data = copy.deepcopy(self.valid)
        data["cells"][0]["permissions"]["shippingActivation"] = True
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        data["cells"][2]["siblingTransformAllowed"] = True
        self.assert_fails(data)

    def test_rejects_owned_root_overlap_qa_author_collision_or_naive_time(self) -> None:
        data = copy.deepcopy(self.valid)
        data["cells"][1]["ownedRoots"] = copy.deepcopy(data["cells"][0]["ownedRoots"])
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        data["cells"][5]["featureAuthorThreadId"] = data["cells"][5]["threadId"]
        self.assert_fails(data)
        data = copy.deepcopy(self.valid)
        data["cells"][0]["observedAt"] = "2026-08-02T21:27:54"
        self.assert_fails(data)

    def test_rejects_dcc_job_without_compute_slot(self) -> None:
        data = copy.deepcopy(self.valid)
        self.activate(data, "prelock_active", "contract_pending")
        job = data["cells"][0]["executionAccounting"]["launchedJobs"][0]
        job.update(resourceClass="dcc", processSlot="dcc-1")
        self.assert_fails(data)


if __name__ == "__main__":
    unittest.main()
