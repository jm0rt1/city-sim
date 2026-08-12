#!/usr/bin/env python3
import copy
import unittest

from validate_unresolved_return_liveness import LivenessError, validate


COMMIT = "e3b2f5167e2a8634ebdd4e209f6188526c1feabf"
HASH = "d95a583cacbce1457f36aec0a619fc1e7ec4dc61729f1ee191ee754dfdb561a8"


def receiver():
    return {
        "taskId": "PLAY-141",
        "owner": "Agent 006 — Operational Excellence Officer",
        "routeId": "os-v1:play-141-receiver-liveness",
        "commit": COMMIT,
        "artifactPath": "/private/tmp/PLAY-141-DISPATCH.json",
        "artifactSha256": HASH,
        "threadId": "019ff2ea-cde0-7c72-86ce-805918e21956",
        "dispatchedAt": "2026-08-12T10:01:00-04:00",
        "acknowledgement": {
            "threadId": "019ff2ea-cde0-7c72-86ce-805918e21956",
            "evidenceId": "item-ack-141",
            "acknowledgedAt": "2026-08-12T10:02:00-04:00",
        },
        "firstJobStart": None,
    }


def dependency():
    return {
        "taskId": "PLAY-051",
        "owner": "Agent 004 — Playtest Quality",
        "routeId": "qa-v1:play-051-pid-bound-axpress-recovery",
        "commit": COMMIT,
        "artifactPath": "/private/tmp/CITYSIM-PLAY051-71E2-AGGREGATE.json",
        "artifactSha256": HASH,
        "recordedAt": "2026-08-12T10:01:00-04:00",
        "resumeWhen": "A candidate-bound AXPress-only QA harness artifact is bound.",
    }


def payload(*, receiver_receipt=None, serialized_dependency=None):
    return {
        "schema": 2,
        "managementTurn": {
            "turnId": "integration-turn-2026-08-12T10:00:00-04:00",
            "startedAt": "2026-08-12T10:00:00-04:00",
            "observedAt": "2026-08-12T10:05:00-04:00",
        },
        "unresolvedReturns": [{
            "returnId": "PLAY-051-qa-harness",
            "returnedAt": "2026-08-12T10:00:30-04:00",
            "receiverReceipt": receiver_receipt,
            "serializedDependency": serialized_dependency,
        }],
    }


class UnresolvedReturnLivenessTests(unittest.TestCase):
    def test_receiver_acknowledgement_is_sufficient(self):
        result = validate(payload(receiver_receipt=receiver()))
        self.assertEqual(result["receiverCount"], 1)
        self.assertEqual(result["dependencyCount"], 0)

    def test_first_job_start_is_sufficient(self):
        receipt = receiver()
        receipt["acknowledgement"] = None
        receipt["firstJobStart"] = {
            "threadId": receipt["threadId"],
            "jobId": "focused-validator-proof",
            "evidenceId": "exec-141",
            "startedAt": "2026-08-12T10:03:00-04:00",
        }
        result = validate(payload(receiver_receipt=receipt))
        self.assertEqual(result["receiverCount"], 1)

    def test_receiver_may_bind_both_proofs(self):
        receipt = receiver()
        receipt["firstJobStart"] = {
            "threadId": receipt["threadId"],
            "jobId": "focused-validator-proof",
            "evidenceId": "exec-141",
            "startedAt": "2026-08-12T10:03:00-04:00",
        }
        self.assertEqual(validate(payload(receiver_receipt=receipt))["unresolvedReturnCount"], 1)

    def test_owner_name_without_receiver_evidence_fails_closed(self):
        legacy = payload()
        legacy["schema"] = 1
        legacy["unresolvedReturns"][0] = {
            "returnId": "PLAY-051",
            "nextOwner": "Agent 004",
            "serializedDependency": None,
        }
        with self.assertRaisesRegex(LivenessError, "schema 2"):
            validate(legacy)

    def test_receiver_without_acknowledgement_or_job_start_fails_closed(self):
        receipt = receiver()
        receipt["acknowledgement"] = None
        with self.assertRaisesRegex(LivenessError, "requires acknowledgement or firstJobStart"):
            validate(payload(receiver_receipt=receipt))

    def test_receiver_proof_must_follow_dispatch_in_same_turn(self):
        receipt = receiver()
        receipt["acknowledgement"]["acknowledgedAt"] = "2026-08-12T09:59:00-04:00"
        with self.assertRaisesRegex(LivenessError, "after dispatch and within the management turn"):
            validate(payload(receiver_receipt=receipt))

        receipt = receiver()
        receipt["acknowledgement"]["acknowledgedAt"] = "2026-08-12T10:06:00-04:00"
        with self.assertRaisesRegex(LivenessError, "after dispatch and within the management turn"):
            validate(payload(receiver_receipt=receipt))

    def test_receiver_proof_binds_exact_receiver_thread(self):
        receipt = receiver()
        receipt["acknowledgement"]["threadId"] = "wrong-thread"
        with self.assertRaisesRegex(LivenessError, "must match the receiver thread"):
            validate(payload(receiver_receipt=receipt))

    def test_structured_dependency_is_sufficient(self):
        result = validate(payload(serialized_dependency=dependency()))
        self.assertEqual(result["kind"], "validated_unresolved_return_liveness")
        self.assertEqual(result["dependencyCount"], 1)

    def test_missing_or_duplicate_successor_fails_closed(self):
        with self.assertRaisesRegex(LivenessError, "exactly one"):
            validate(payload())
        with self.assertRaisesRegex(LivenessError, "exactly one"):
            validate(payload(receiver_receipt=receiver(), serialized_dependency=dependency()))

    def test_dependency_requires_exact_identity_and_same_turn_recording(self):
        malformed = dependency()
        malformed.pop("artifactSha256")
        with self.assertRaisesRegex(LivenessError, "wrong fields"):
            validate(payload(serialized_dependency=malformed))

        malformed = dependency()
        malformed["commit"] = "not-a-sha"
        with self.assertRaisesRegex(LivenessError, "40-character SHA"):
            validate(payload(serialized_dependency=malformed))

        malformed = dependency()
        malformed["recordedAt"] = "2026-08-12T10:06:00-04:00"
        with self.assertRaisesRegex(LivenessError, "after the return and within the management turn"):
            validate(payload(serialized_dependency=malformed))

    def test_payload_is_not_mutated(self):
        data = payload(receiver_receipt=receiver())
        before = copy.deepcopy(data)
        validate(data)
        self.assertEqual(data, before)


if __name__ == "__main__":
    unittest.main()
