#!/usr/bin/env python3
import copy
import unittest

from validate_unresolved_return_liveness import LivenessError, validate


COMMIT = "e3b2f5167e2a8634ebdd4e209f6188526c1feabf"
HASH = "d95a583cacbce1457f36aec0a619fc1e7ec4dc61729f1ee191ee754dfdb561a8"


def payload(item):
    return {"schema": 1, "unresolvedReturns": [item]}


class UnresolvedReturnLivenessTests(unittest.TestCase):
    def test_active_owner_is_sufficient(self):
        result = validate(payload({
            "returnId": "PLAY-098-renderer",
            "nextOwner": "Agent 404 — Renderer Asset Intake Engineer",
            "serializedDependency": None,
        }))
        self.assertEqual(result["unresolvedReturnCount"], 1)

    def test_structured_dependency_is_sufficient(self):
        result = validate(payload({
            "returnId": "PLAY-051-qa-harness",
            "nextOwner": None,
            "serializedDependency": {
                "taskId": "PLAY-051",
                "owner": "Agent 004 — Playtest Quality",
                "routeId": "qa-v1:play-051-pid-bound-axpress-recovery",
                "commit": COMMIT,
                "artifactPath": "/private/tmp/CITYSIM-PLAY051-71E2-AGGREGATE.json",
                "artifactSha256": HASH,
                "resumeWhen": "A candidate-bound AXPress-only QA harness artifact is bound.",
            },
        }))
        self.assertEqual(result["kind"], "validated_unresolved_return_liveness")

    def test_missing_successor_fails_closed(self):
        with self.assertRaisesRegex(LivenessError, "exactly one"):
            validate(payload({"returnId": "PLAY-051", "nextOwner": None, "serializedDependency": None}))

    def test_owner_and_dependency_cannot_both_be_set(self):
        item = {
            "returnId": "PLAY-051",
            "nextOwner": "Agent 004",
            "serializedDependency": {
                "taskId": "PLAY-051", "owner": "Agent 004", "routeId": "qa-v1:recovery",
                "commit": COMMIT, "artifactPath": "/private/tmp/receipt.json", "artifactSha256": HASH,
                "resumeWhen": "A route is bound.",
            },
        }
        with self.assertRaisesRegex(LivenessError, "exactly one"):
            validate(payload(item))

    def test_dependency_requires_exact_identity_fields_and_hashes(self):
        item = {
            "returnId": "PLAY-051",
            "nextOwner": None,
            "serializedDependency": {
                "taskId": "PLAY-051", "owner": "Agent 004", "routeId": "qa-v1:recovery",
                "commit": COMMIT, "artifactPath": "/private/tmp/receipt.json", "artifactSha256": HASH,
                "resumeWhen": "A route is bound.",
            },
        }
        malformed = copy.deepcopy(item)
        malformed["serializedDependency"].pop("artifactSha256")
        with self.assertRaisesRegex(LivenessError, "wrong fields"):
            validate(payload(malformed))
        malformed = copy.deepcopy(item)
        malformed["serializedDependency"]["commit"] = "not-a-sha"
        with self.assertRaisesRegex(LivenessError, "40-character SHA"):
            validate(payload(malformed))


if __name__ == "__main__":
    unittest.main()
