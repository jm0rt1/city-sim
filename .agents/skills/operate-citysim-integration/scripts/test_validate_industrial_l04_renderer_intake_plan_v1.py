#!/usr/bin/env python3
"""Adversarial no-product tests for the Industrial L4 Renderer intake plan."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
VALIDATOR = Path(__file__).with_name(
    "validate_industrial_l04_renderer_intake_plan_v1.py"
)
PLAN = (
    ROOT
    / "docs/production/evidence/INTEGRATION"
    / "industrial-l04-renderer-intake-plan-v1.json"
)
SPEC = importlib.util.spec_from_file_location("renderer_intake_validator", VALIDATOR)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class RendererIntakePlanValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.valid = json.loads(PLAN.read_text())
        self.temporary = tempfile.TemporaryDirectory(
            prefix="citysim-industrial-l04-intake-validator-"
        )

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write(self, data: dict) -> Path:
        path = Path(self.temporary.name) / "plan.json"
        path.write_text(json.dumps(data, sort_keys=True))
        return path

    def assert_fails(self, mutate) -> None:
        data = copy.deepcopy(self.valid)
        mutate(data)
        with self.assertRaises(MODULE.IntakePlanError):
            MODULE.validate(ROOT, self.write(data))

    def test_valid_candidate_neutral_plan(self) -> None:
        result = MODULE.validate(ROOT, PLAN)
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["directionCount"], 4)
        self.assertEqual(result["lodSlotCount"], 12)
        self.assertFalse(result["runtimeActivated"])

    def test_template_shape_is_derived_from_actual_swift_assembler(self) -> None:
        harness = (
            ROOT
            / "Native/CitySimNative/Tests/CitySimNativeTests"
            / "IndustrialL4V2SourceAdmissionHarnessTests.swift"
        )
        shape = MODULE.extract_swift_manifest_shape(harness)
        template = self.valid["atomicAssembly"]["manifestTemplate"]
        self.assertEqual(set(template), shape["root"])
        self.assertEqual(
            set(template["acceptedL3Baseline"]),
            shape["baseline"],
        )
        for entry in template["directions"]:
            self.assertEqual(set(entry), shape["direction"])
            self.assertEqual(set(entry["locators"]), shape["locators"])

    def test_bound_tool_targets_actual_caller_supplied_swift_harness(self) -> None:
        tool = (
            ROOT
            / self.valid["atomicAssembly"]["assemblerAssignment"]["tool"]["path"]
        ).read_text()
        self.assertIn(
            "IndustrialL4V2SourceAdmissionHarnessTests/"
            "testCallerSuppliedAtomicAssemblyManifest",
            tool,
        )
        self.assertIn("CITYSIM_L4_ASSEMBLY_MANIFEST_PATH", tool)

    def test_shipping_manifest_stays_bound_outside_swift_template(self) -> None:
        shipping = next(
            item
            for item in self.valid["boundInputs"]
            if item["role"] == "shipping_manifest"
        )
        self.assertEqual(
            shipping["path"],
            "Native/CitySimNative/Sources/CitySimNative/Resources/"
            "WorldAssets.atlas/generated-v4-manifest.json",
        )
        self.assertNotIn(
            "shippingManifest",
            self.valid["atomicAssembly"]["manifestTemplate"][
                "acceptedL3Baseline"
            ],
        )

    def test_rejects_wrong_published_base(self) -> None:
        self.assert_fails(
            lambda data: data["publishedBase"].update(commit="f" * 40)
        )

    def test_rejects_stale_schema_binding(self) -> None:
        self.assert_fails(lambda data: data["schema"].update(sha256="f" * 64))

    def test_rejects_stale_frozen_input(self) -> None:
        self.assert_fails(
            lambda data: data["boundInputs"][6].update(sha256="f" * 64)
        )

    def test_rejects_missing_frozen_input_role(self) -> None:
        self.assert_fails(lambda data: data["boundInputs"].pop())

    def test_rejects_duplicate_frozen_input_role(self) -> None:
        self.assert_fails(
            lambda data: data["boundInputs"][1].update(
                role=data["boundInputs"][0]["role"]
            )
        )

    def test_rejects_path_traversal(self) -> None:
        self.assert_fails(
            lambda data: data["boundInputs"][0].update(
                path="../industrial-l04-accepted-master-non-alias-input-v1.json"
            )
        )

    def test_rejects_direction_order_drift(self) -> None:
        self.assert_fails(
            lambda data: data["directionIntake"].__setitem__(
                slice(0, 2),
                [data["directionIntake"][1], data["directionIntake"][0]],
            )
        )

    def test_rejects_logical_id_alias(self) -> None:
        self.assert_fails(
            lambda data: data["directionIntake"][1].update(
                logicalID=data["directionIntake"][0]["logicalID"]
            )
        )

    def test_rejects_atlas_slot_alias(self) -> None:
        self.assert_fails(
            lambda data: data["directionIntake"][1]["lods"][0].update(
                atlasSlot=data["directionIntake"][0]["lods"][0]["atlasSlot"]
            )
        )

    def test_rejects_lod_canvas_drift(self) -> None:
        self.assert_fails(
            lambda data: data["directionIntake"][2]["lods"][2].update(
                canvasPixels=[1024, 682]
            )
        )

    def test_rejects_frontage_socket_drift(self) -> None:
        self.assert_fails(
            lambda data: data["directionIntake"][3]["registration"].update(
                frontageSocketSource=[641, 704]
            )
        )

    def test_rejects_prebound_source_before_integration_admission(self) -> None:
        self.assert_fails(
            lambda data: data["directionIntake"][0]["futureInputs"][
                "sourcePacket"
            ].update(path="candidate.json", sha256="a" * 64, status="bound")
        )

    def test_rejects_missing_direction_quarantine_job(self) -> None:
        self.assert_fails(
            lambda data: data["quarantineGraph"]["directionJobs"].pop()
        )

    def test_rejects_cross_direction_output_root(self) -> None:
        self.assert_fails(
            lambda data: data["quarantineGraph"]["directionJobs"][1].update(
                exclusiveOutputRoot=data["quarantineGraph"]["directionJobs"][0][
                    "exclusiveOutputRoot"
                ]
            )
        )

    def test_rejects_direction_failure_that_blocks_siblings(self) -> None:
        self.assert_fails(
            lambda data: data["quarantineGraph"]["directionJobs"][2].update(
                failureIsolation="stop_all_directions"
            )
        )

    def test_rejects_partial_family_activation(self) -> None:
        self.assert_fails(
            lambda data: data["quarantineGraph"]["join"].update(
                activationAllowed=True
            )
        )

    def test_rejects_fixture_mutation(self) -> None:
        self.assert_fails(
            lambda data: data["preparation"]["fixture"].update(
                mutationAllowed=True
            )
        )

    def test_rejects_camera_scale_drift(self) -> None:
        self.assert_fails(
            lambda data: data["preparation"]["cameraStates"][0].update(
                canonicalCameraScale=0.75
            )
        )

    def test_rejects_app_capture_during_preparation(self) -> None:
        self.assert_fails(
            lambda data: data["preparation"]["cameraStates"][5].update(
                appCaptureAuthorized=True
            )
        )

    def test_rejects_removed_transform_gate(self) -> None:
        self.assert_fails(
            lambda data: data["rejectionGates"].remove(
                "mirror_rotation_or_other_d4_transform"
            )
        )

    def test_rejects_duplicate_rejection_gate(self) -> None:
        self.assert_fails(
            lambda data: data["rejectionGates"].append(
                "missing_or_extra_direction"
            )
        )

    def test_rejects_partial_binding_in_atomic_template(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"]["manifestTemplate"][
                "directions"
            ][0]["packet"].update(
                path="packet.json",
                sha256="a" * 64,
                status="integration_admitted",
            )
        )

    def test_rejects_old_accepted_baseline_field_name(self) -> None:
        def mutate(data):
            template = data["atomicAssembly"]["manifestTemplate"]
            template["acceptedBaseline"] = template.pop("acceptedL3Baseline")

        self.assert_fails(mutate)

    def test_rejects_embedded_shipping_manifest_from_swift_shape(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"]["manifestTemplate"][
                "acceptedL3Baseline"
            ].update(
                shippingManifest={
                    "path": "manifest.json",
                    "sha256": "a" * 64,
                }
            )
        )

    def test_rejects_direction_logical_id_not_accepted_by_swift_shape(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"]["manifestTemplate"][
                "directions"
            ][0].update(logicalID="industrial_l04_v0_north")
        )

    def test_rejects_uncontrolled_manifest_disposition_transition(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"]["manifestTransition"].update(
                toDisposition="ready_for_atomic_assembly_nonshipping"
            )
        )

    def test_rejects_stale_bound_swift_harness(self) -> None:
        def mutate(data):
            entry = next(
                item
                for item in data["boundInputs"]
                if item["role"] == "atomic_assembler_harness"
            )
            entry["sha256"] = "f" * 64

        self.assert_fails(mutate)

    def test_rejects_atomic_assembly_before_four_receipts(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"].update(
                state="ready_for_atomic_assembly"
            )
        )

    def test_rejects_wrong_atomic_assembler_thread(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"]["assemblerAssignment"].update(
                threadId="019f96e0-3793-7542-9172-060a9ca09b0a"
            )
        )

    def test_rejects_atomic_assembler_shipping_mutation(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"]["assemblerAssignment"].update(
                shippingMutationAllowed=True
            )
        )

    def test_rejects_atomic_output_runtime_activation(self) -> None:
        self.assert_fails(
            lambda data: data["atomicAssembly"]["output"].update(
                runtimeActivated=True
            )
        )

    def test_rejects_renderer_admission_grant(self) -> None:
        self.assert_fails(
            lambda data: data["grants"].update(rendererAdmission=True)
        )

    def test_rejects_production_selection_grant(self) -> None:
        self.assert_fails(
            lambda data: data["grants"].update(productionSelection=True)
        )


if __name__ == "__main__":
    unittest.main()
