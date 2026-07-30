#!/usr/bin/env python3
"""No-DCC tests for the Industrial L4 source-admission receipt validator."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import validate_industrial_l04_source_admission_receipt_v1 as validator
from jsonschema import Draft202012Validator


def canonical_bytes(value: object) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n"
    ).encode("utf-8")


class AdmissionFixture:
    def __init__(self, source_repo: Path, direction: str = "north") -> None:
        self.source_repo = source_repo
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        self.direction = direction
        self.logical_id = f"industrial_l04_v0_{direction}"
        self.content_commit = "a" * 40
        self.integration_commit = "b" * 40
        self.ledger_commit = "c" * 40
        self.decoded = "d" * 64

        family_path = "docs/production/decisions/CONTRACT-010-directional-building-art.md"
        self.family = self.write(
            family_path,
            (source_repo / family_path).read_bytes(),
        )
        self.appearance = self.write(
            "docs/production/evidence/INTEGRATION/APPEARANCE-LOCK.md",
            b"appearance lock\n",
        )
        self.profile = self.write(
            "docs/production/evidence/INTEGRATION/source-profile.json",
            b"{}\n",
        )
        self.raw = self.write(
            f"Native/CitySimNative/WorldArt/Blender/PLAY-027/{direction}/raw.png",
            b"not-real-pixels-but-hash-bound",
        )

        for relative in (
            validator.SCHEMA_PATH,
            validator.SOURCE_STAGE_SCHEMA_PATH,
            validator.SEMANTIC_VALIDATOR_PATH,
        ):
            target = self.repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((source_repo / relative).read_bytes())

        self.semantic_result = {
            "schema": "citysim://integration/industrial-l04-source-stage-handoff-v2",
            "result": "PASS",
            "stage": "source_candidate",
            "taskId": {
                "north": "PLAY-027",
                "east": "PLAY-079",
                "south": "PLAY-080",
                "west": "PLAY-081",
            }[direction],
            "direction": direction,
            "contentCommit": self.content_commit,
            "forbiddenDecodedRgbaSha256Count": 44,
            "forbiddenSetSha256": (
                "265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea"
            ),
        }
        self.semantic = self.write_json(
            "docs/production/evidence/INTEGRATION/"
            f"industrial-l04-semantic-validations-v2/{direction}.json",
            self.semantic_result,
        )
        self.worker_validation = self.write_json(
            f"docs/production/evidence/PLAY-027/{direction}/worker-validation.json",
            {
                "result": "PASS",
            },
        )
        self.appearance_descriptor = {
            "documentPath": self.appearance[0],
            "commit": "e" * 40,
            "documentSha256": self.appearance[1],
            "northProcessASourceSha256": "f" * 64,
            "northProcessADecodedRgbaSha256": "1" * 64,
        }
        self.profile_descriptor = {
            "path": self.profile[0],
            "commit": "2" * 40,
            "sha256": self.profile[1],
        }
        self.family_descriptor = {
            "path": self.family[0],
            "sha256": self.family[1],
        }
        self.semantic_validator_descriptor = {
            "path": validator.SEMANTIC_VALIDATOR_PATH,
            "sha256": validator.SEMANTIC_VALIDATOR_SHA256,
        }
        task_id = self.semantic_result["taskId"]
        branch = {
            "north": "codex/citysim-world-art",
            "east": "codex/citysim-world-art-east",
            "south": "codex/citysim-world-art-south",
            "west": "codex/citysim-world-art-west",
        }[direction]
        source_root = (
            f"Native/CitySimNative/WorldArt/Blender/{task_id}/industrial-l04/"
        )
        evidence_root = f"docs/production/evidence/{task_id}/industrial-l04/"
        artifact = self.family_descriptor
        raster = {
            "path": self.raw[0],
            "sha256": self.raw[1],
            "decodedRgbaSha256": self.decoded,
        }
        process = lambda process_id: {
            "processId": process_id,
            "outputRoot": f"{evidence_root}process-{process_id.lower()}",
            "freshInvocationReceipt": artifact,
            "renderInvocationCount": 1,
            "raw": raster,
            "semantic": raster,
            "provenance": artifact,
        }
        socket = {
            "north": [896, 704],
            "east": [896, 832],
            "south": [640, 832],
            "west": [640, 704],
        }[direction]
        authorized = ["B", "C"] if direction == "north" else ["A", "B", "C"]
        isolated_roots = {
            process_id: f"{evidence_root}process-{process_id.lower()}"
            for process_id in authorized
        }
        all_true_gates = {
            key: True
            for key in (
                "freshProcessProvenance",
                "rawDecodedRgbaIdentity",
                "semanticDecodedRgbaIdentity",
                "alphaChromaHiddenRgb",
                "occupiedBoundsIdentity",
                "registration",
                "literal192",
                "compactColorAndGrayscaleSurvival",
                "nonAliasing",
                "normalizationRepeatIdentity",
                "d4FingerprintCompleteness",
                "reviewManifestCompleteness",
            )
        }
        self.packet = {
            "schemaVersion": 2,
            "stage": "source_candidate",
            "identity": {
                "taskId": task_id,
                "direction": direction,
                "branch": branch,
                "logicalID": self.logical_id,
                "family": "industrial",
                "level": 4,
                "variant": 0,
                "sourceKey": f"industrial_l04/variant-0/{direction}/source-v01",
                "sourceRoot": source_root,
                "evidenceRoot": evidence_root,
                "orientationTransform": "none",
                "fallbackSourceKey": None,
            },
            "lineage": {
                "publishedBaseline": "9" * 40,
                "cellContentCommit": self.content_commit,
            },
            "authorities": {
                "contract010": self.family_descriptor,
                "contract021": {
                    "path": (
                        "docs/production/decisions/"
                        "CONTRACT-021-parallel-directional-art-cells.md"
                    ),
                    "revision": 2,
                    "sha256": (
                        "f80844c928d904498510b8b151381f40315e072d52d81695aafcd6b91081ae4c"
                    ),
                },
                "directionBridge": {
                    "documentPath": (
                        "docs/production/evidence/INTEGRATION/"
                        "INDUSTRIAL-L04-DIRECTIONAL-BRIDGE-V06-ACCEPTANCE.md"
                    ),
                    "sourceCandidate": "3e01ca6738d7574718f9aeff4b66771eee109feb",
                    "integratedProofCommit": "3d76fab8a45807c34198a6d8bb1dd1eeff7be51e",
                    "documentSha256": (
                        "9765d88191d8a555de41dcccfb83b3da16d8f1423d534d66312ffa98a4615208"
                    ),
                    "mappingContractSha256": (
                        "5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7"
                    ),
                    "coordinateSystem": "citysim_source_pixels_v1",
                },
                "appearanceLock": self.appearance_descriptor,
                "lockedMaterialMapping": self.profile_descriptor,
                "sourceProductionProfile": self.profile_descriptor,
                "nonAliasInput": {
                    "path": (
                        "docs/production/evidence/INTEGRATION/"
                        "industrial-l04-accepted-master-non-alias-input-v1.json"
                    ),
                    "sha256": (
                        "d1d75fdc30d9a2f21d49b59fd13dbc6fe7d81669f76f801d1087b35a7fb70044"
                    ),
                    "forbiddenDecodedRgbaSha256Count": 44,
                    "forbiddenSetSha256": (
                        "265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea"
                    ),
                },
                "nonAliasLoader": {
                    "path": (
                        "Native/CitySimNative/WorldArt/Shared/"
                        "accepted_master_non_alias_v1.py"
                    ),
                    "sha256": (
                        "83716838d310b5a5a3be51091b255d2a5eabb1b2f28d9af72a89a885779f3a7d"
                    ),
                },
                "semanticValidator": self.semantic_validator_descriptor,
                "canonicalDecoder": {
                    "path": (
                        "Native/CitySimNative/WorldArt/Shared/"
                        "canonical_rgba_v1.swift"
                    ),
                    "sha256": (
                        "2be2b57d0c9bb73e8a4438c69aa4230eba08c4b87937fae4d4e048244b9beaab"
                    ),
                },
            },
            "inputs": {
                "prelaunchHandoff": artifact,
                "frozenInputManifest": artifact,
                "runnerContract": artifact,
                "outputRoot": evidence_root,
            },
            "launch": {
                "guardReceipt": artifact,
                "result": "PASS",
                "authorizedProcesses": authorized,
                "isolatedOutputRoots": isolated_roots,
                "allOutputRootsDistinct": True,
                "outputRootIsolationReceipt": artifact,
            },
            "completion": {
                "contentCommit": self.content_commit,
                "source": {
                    "decodedRgbaSha256": self.decoded,
                    "authoredGeometrySha256": "4" * 64,
                    "componentManifestSha256": "5" * 64,
                    "fallbackSourceKey": None,
                },
                "selectedProcess": "A",
                "selectedSource": raster,
                "processes": {
                    "A": process("A"),
                    "B": process("B"),
                    "C": process("C"),
                },
                "lods": {
                    "city": {**raster, "canvasPixels": [256, 171]},
                    "neighborhood": {**raster, "canvasPixels": [512, 342]},
                    "block": {**raster, "canvasPixels": [1024, 683]},
                },
                "registration": {
                    "footprintTiles": [1, 1],
                    "canvasPixels": [1536, 1024],
                    "groundPivotSource": [768, 896],
                    "frontageSocketSource": socket,
                    "frontageEdge": direction,
                    "supportedOrientation": f"{direction}-facing-authored",
                    "occupiedBounds": {
                        "minX": 1,
                        "minY": 1,
                        "maxX": 2,
                        "maxY": 2,
                    },
                    "groundContactPolygonWorld": [
                        [-28, -28],
                        [28, -28],
                        [28, 28],
                        [-28, 28],
                    ],
                    "contactDeclaration": "registered_ground_pivot",
                    "shadowDirection": "southeast",
                    "alpha": {
                        "nonzeroPixelCount": 1,
                        "hiddenRgbPixelCount": 0,
                        "nearChromaPixelCount": 0,
                    },
                },
                "transformFingerprints": {
                    "identity": "0" * 64,
                    "rotate90": "1" * 64,
                    "rotate180": "2" * 64,
                    "rotate270": "3" * 64,
                    "mirrorX": "4" * 64,
                    "mirrorY": "5" * 64,
                    "mirrorDiagonal": "6" * 64,
                    "mirrorAntiDiagonal": "7" * 64,
                },
                "validation": {
                    "receipt": {
                        "path": self.worker_validation[0],
                        "sha256": self.worker_validation[1],
                    },
                    "result": "PASS",
                    "gates": all_true_gates,
                },
                "parallelExecutionReceipt": artifact,
                "reviewManifest": artifact,
                "rejectedAttemptInventory": artifact,
            },
            "candidateReadyForIndependentReview": True,
            "sourceReady": False,
            "integrationAdmitted": False,
            "rendererQuarantined": False,
            "productionSelected": False,
        }
        self.packet_artifact = self.write_json(
            f"docs/production/evidence/PLAY-027/{direction}/packet.json",
            self.packet,
        )
        review_binding = {
            "disposition": "ACCEPT",
            "direction": direction,
            "logicalID": self.logical_id,
            "workerPacketSha256": self.packet_artifact[1],
            "contentCommit": self.content_commit,
            "decodedRgbaSha256": self.decoded,
        }
        self.technical = self.write_json(
            f"docs/production/evidence/INTEGRATION/reviews/{direction}-technical.json",
            review_binding,
        )
        self.literal = self.write_json(
            f"docs/production/evidence/INTEGRATION/reviews/{direction}-literal.json",
            review_binding,
        )
        self.receipt = {
            "schemaVersion": 1,
            "disposition": "integration_source_admitted",
            "integrationCommit": self.integration_commit,
            "sourceContext": {
                "branch": branch,
                "head": self.content_commit,
                "cleanState": "clean",
            },
            "direction": direction,
            "logicalID": self.logical_id,
            "familyContract": self.family_descriptor,
            "appearanceLock": self.appearance_descriptor,
            "sourceProductionProfile": self.profile_descriptor,
            "sourceStageSchema": {
                "path": validator.SOURCE_STAGE_SCHEMA_PATH,
                "version": 2,
                "sha256": validator.SOURCE_STAGE_SCHEMA_SHA256,
            },
            "workerPacket": {
                "path": self.packet_artifact[0],
                "sha256": self.packet_artifact[1],
            },
            "contentCommit": self.content_commit,
            "admittedRaw": {"path": self.raw[0], "sha256": self.raw[1]},
            "decodedRgbaSha256": self.decoded,
            "semanticValidator": self.semantic_validator_descriptor,
            "semanticValidationReceipt": {
                "path": self.semantic[0],
                "sha256": self.semantic[1],
                "disposition": "PASS",
            },
            "semanticValidationResult": "PASS",
            "independentTechnicalReview": {
                "path": self.technical[0],
                "sha256": self.technical[1],
                "disposition": "ACCEPT",
            },
            "independentTechnicalDisposition": "ACCEPT",
            "literalScaleReview": {
                "path": self.literal[0],
                "sha256": self.literal[1],
                "disposition": "ACCEPT",
            },
            "literalScaleDisposition": "ACCEPT",
            "sharedLedgerRevision": {
                "path": validator.LEDGER_PATH,
                "commit": self.ledger_commit,
                "sha256": "3" * 64,
                "batch": "industrial_l04_directional_family",
                "directionState": "integration_admitted",
            },
            "rendererQuarantined": False,
            "productionSelected": False,
            "shippingActivated": False,
        }

    def close(self) -> None:
        self.temp.cleanup()

    def write(self, relative: str, data: bytes) -> tuple[str, str]:
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return relative, hashlib.sha256(data).hexdigest()

    def write_json(self, relative: str, value: object) -> tuple[str, str]:
        return self.write(relative, canonical_bytes(value))

    def validate(self, receipt: dict | None = None) -> dict:
        return validator.validate_receipt(
            self.repo,
            self.receipt if receipt is None else receipt,
            verify_git=False,
            semantic_runner=lambda repo, packet, schema: self.semantic_result,
        )


class SourceAdmissionValidatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source_repo = Path(__file__).resolve().parents[4]

    def setUp(self) -> None:
        self.fixture = AdmissionFixture(self.source_repo)

    def tearDown(self) -> None:
        self.fixture.close()

    def assert_rejected(self, code: str, mutate) -> None:
        receipt = copy.deepcopy(self.fixture.receipt)
        mutate(receipt)
        with self.assertRaises(validator.AdmissionError) as caught:
            self.fixture.validate(receipt)
        self.assertEqual(code, caught.exception.code)

    def test_complete_receipt_passes_without_dcc(self) -> None:
        result = self.fixture.validate()
        self.assertEqual("PASS", result["result"])
        self.assertFalse(result["rendererQuarantined"])
        self.assertFalse(result["productionSelected"])
        self.assertFalse(result["shippingActivated"])

    def test_unknown_top_level_field_fails_closed(self) -> None:
        self.assert_rejected(
            "JSON_SCHEMA_VALIDATION_FAILED",
            lambda receipt: receipt.__setitem__("unexpected", True),
        )

    def test_worker_self_admission_fails_closed(self) -> None:
        self.fixture.packet["integrationAdmitted"] = True
        packet = self.fixture.write_json(
            self.fixture.packet_artifact[0], self.fixture.packet
        )
        self.fixture.receipt["workerPacket"]["sha256"] = packet[1]
        with self.assertRaises(validator.AdmissionError) as caught:
            self.fixture.validate()
        self.assertEqual("WORKER_SELF_ADMISSION", caught.exception.code)

    def test_full_source_stage_schema_is_mandatory(self) -> None:
        del self.fixture.packet["lineage"]
        packet = self.fixture.write_json(
            self.fixture.packet_artifact[0], self.fixture.packet
        )
        self.fixture.receipt["workerPacket"]["sha256"] = packet[1]
        with self.assertRaises(validator.AdmissionError) as caught:
            self.fixture.validate()
        self.assertEqual("JSON_SCHEMA_VALIDATION_FAILED", caught.exception.code)

    def test_semantic_receipt_must_equal_fresh_execution(self) -> None:
        def mismatch(repo: Path, packet: Path, schema: Path) -> dict:
            result = dict(self.fixture.semantic_result)
            result["direction"] = "west"
            return result

        with self.assertRaises(validator.AdmissionError) as caught:
            validator.validate_receipt(
                self.fixture.repo,
                self.fixture.receipt,
                verify_git=False,
                semantic_runner=mismatch,
            )
        self.assertEqual(
            "SEMANTIC_RECEIPT_EXECUTION_MISMATCH", caught.exception.code
        )

    def test_semantic_subprocess_uses_clean_source_worktree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            tool = source / validator.SEMANTIC_VALIDATOR_PATH
            tool.parent.mkdir(parents=True)
            tool.write_text(
                "#!/usr/bin/env python3\n"
                "import json, subprocess, sys\n"
                "args=sys.argv\n"
                "repo=args[args.index('--repo-root')+1]\n"
                "branch=subprocess.check_output("
                "['git','-C',repo,'branch','--show-current'],text=True).strip()\n"
                "status=subprocess.check_output("
                "['git','-C',repo,'status','--porcelain=v1'],text=True)\n"
                "if branch!='codex/citysim-world-art' or status: raise SystemExit(9)\n"
                "print(json.dumps({'schema':'citysim://integration/"
                "industrial-l04-source-stage-handoff-v2','result':'PASS',"
                "'stage':'source_candidate','taskId':'PLAY-027',"
                "'direction':'north','contentCommit':'"
                + "a" * 40
                + "'},sort_keys=True))\n"
            )
            packet = source / "docs/production/evidence/PLAY-027/packet.json"
            packet.parent.mkdir(parents=True)
            packet.write_text("{}\n")
            schema = source / validator.SOURCE_STAGE_SCHEMA_PATH
            schema.parent.mkdir(parents=True, exist_ok=True)
            schema.write_text("{}\n")
            subprocess.run(["git", "-C", str(source), "init", "-q"], check=True)
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(source),
                    "checkout",
                    "-q",
                    "-b",
                    "codex/citysim-world-art",
                ],
                check=True,
            )
            subprocess.run(
                ["git", "-C", str(source), "config", "user.email", "test@example.com"],
                check=True,
            )
            subprocess.run(
                ["git", "-C", str(source), "config", "user.name", "CitySim Test"],
                check=True,
            )
            subprocess.run(["git", "-C", str(source), "add", "."], check=True)
            subprocess.run(
                ["git", "-C", str(source), "commit", "-q", "-m", "source"],
                check=True,
            )
            result = validator.run_semantic_validator(source, packet, schema)
            self.assertEqual("PASS", result["result"])
            self.assertFalse(
                (
                    source
                    / "docs/production/evidence/INTEGRATION/"
                    "industrial-l04-source-admissions-v1"
                ).exists()
            )

    def test_direction_logical_id_mismatch_fails_closed(self) -> None:
        self.assert_rejected(
            "JSON_SCHEMA_VALIDATION_FAILED",
            lambda receipt: receipt.__setitem__(
                "logicalID", "industrial_l04_v0_east"
            ),
        )

    def test_hash_drift_fails_closed(self) -> None:
        self.assert_rejected(
            "ARTIFACT_HASH_MISMATCH",
            lambda receipt: receipt["admittedRaw"].__setitem__(
                "sha256", "0" * 64
            ),
        )

    def test_review_must_bind_exact_packet(self) -> None:
        path = self.fixture.repo / self.fixture.technical[0]
        data = json.loads(path.read_text())
        data["workerPacketSha256"] = "9" * 64
        path.write_bytes(canonical_bytes(data))
        self.fixture.receipt["independentTechnicalReview"]["sha256"] = (
            hashlib.sha256(path.read_bytes()).hexdigest()
        )
        with self.assertRaises(validator.AdmissionError) as caught:
            self.fixture.validate()
        self.assertEqual("REVIEW_BINDING_MISMATCH", caught.exception.code)

    def test_renderer_or_shipping_escalation_fails_closed(self) -> None:
        for field in ("rendererQuarantined", "productionSelected", "shippingActivated"):
            with self.subTest(field=field):
                self.assert_rejected(
                    "JSON_SCHEMA_VALIDATION_FAILED",
                    lambda receipt, field=field: receipt.__setitem__(field, True),
                )

    def test_symlinked_raw_is_rejected(self) -> None:
        raw_path = self.fixture.repo / self.fixture.raw[0]
        target = raw_path.with_name("real-raw.png")
        raw_path.rename(target)
        os.symlink(target.name, raw_path)
        with self.assertRaises(validator.AdmissionError) as caught:
            self.fixture.validate()
        self.assertEqual("SYMLINK_FORBIDDEN", caught.exception.code)

    def test_all_direction_logical_id_pairs_pass(self) -> None:
        self.fixture.close()
        for direction in validator.DIRECTIONS:
            with self.subTest(direction=direction):
                fixture = AdmissionFixture(self.source_repo, direction)
                try:
                    self.assertEqual("PASS", fixture.validate()["result"])
                finally:
                    fixture.close()
        self.fixture = AdmissionFixture(self.source_repo)

    def test_duplicate_json_key_is_rejected(self) -> None:
        with self.assertRaises(validator.AdmissionError) as caught:
            validator.strict_json_bytes(b'{"a":1,"a":2}', "duplicate")
        self.assertEqual("DUPLICATE_JSON_KEY", caught.exception.code)

    def test_schema_rejects_repository_path_traversal(self) -> None:
        schema = json.loads(
            (self.source_repo / validator.SCHEMA_PATH).read_text()
        )
        path_schema = schema["$defs"]["repositoryPath"]
        for unsafe in (
            "docs/production/evidence/../../escape.png",
            "docs/production/evidence/./escape.png",
            "docs/production/evidence//escape.png",
            "/docs/production/evidence/escape.png",
        ):
            with self.subTest(path=unsafe):
                self.assertTrue(
                    list(Draft202012Validator(path_schema).iter_errors(unsafe))
                )

    def test_git_ancestry_and_committed_blob_checks_are_enforced(self) -> None:
        repo = self.fixture.repo
        subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "config", "user.email", "test@example.com"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(repo), "config", "user.name", "CitySim Test"],
            check=True,
        )
        subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "commit", "-q", "-m", "fixture"],
            check=True,
        )
        commit = (
            subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"])
            .decode()
            .strip()
        )
        validator.require_ancestor(repo, commit, commit, "self")
        validator.require_blob_hash(
            repo,
            commit,
            self.fixture.family[0],
            self.fixture.family[1],
            "family",
        )
        with self.assertRaises(validator.AdmissionError) as caught:
            validator.require_blob_hash(
                repo,
                commit,
                self.fixture.family[0],
                "0" * 64,
                "family",
            )
        self.assertEqual("COMMITTED_BLOB_HASH_MISMATCH", caught.exception.code)

    def test_publication_check_requires_zero_live_receipts(self) -> None:
        schema_target = self.fixture.repo / validator.SCHEMA_PATH
        schema_target.parent.mkdir(parents=True, exist_ok=True)
        schema_target.write_bytes((self.source_repo / validator.SCHEMA_PATH).read_bytes())
        result = validator.validate_schema_publication(
            self.fixture.repo, schema_target
        )
        self.assertEqual("PASS_PUBLICATION_ONLY", result["result"])
        admissions = (
            self.fixture.repo
            / "docs/production/evidence/INTEGRATION/"
            "industrial-l04-source-admissions-v1"
        )
        admissions.mkdir(parents=True)
        (admissions / "north.json").write_text("{}\n")
        with self.assertRaises(validator.AdmissionError) as caught:
            validator.validate_schema_publication(
                self.fixture.repo, schema_target
            )
        self.assertEqual(
            "UNAUTHORIZED_LIVE_RECEIPT_PRESENT", caught.exception.code
        )

    def test_publication_rejects_gutted_or_symlinked_schema(self) -> None:
        schema_target = self.fixture.repo / validator.SCHEMA_PATH
        schema_target.parent.mkdir(parents=True, exist_ok=True)
        schema_target.write_text(
            json.dumps(
                {
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "$id": validator.SCHEMA_ID,
                    "type": "object",
                    "additionalProperties": False,
                    "required": sorted(validator.RECEIPT_KEYS),
                    "properties": {
                        key: {} for key in sorted(validator.RECEIPT_KEYS)
                    },
                    "$defs": {},
                }
            )
        )
        with self.assertRaises(validator.AdmissionError) as caught:
            validator.validate_schema_publication(
                self.fixture.repo, schema_target
            )
        self.assertEqual("ADMISSION_SCHEMA_HASH_MISMATCH", caught.exception.code)

        schema_target.unlink()
        external = self.fixture.repo / "outside-schema.json"
        external.write_bytes((self.source_repo / validator.SCHEMA_PATH).read_bytes())
        os.symlink(external, schema_target)
        with self.assertRaises(validator.AdmissionError) as caught:
            validator.validate_schema_publication(
                self.fixture.repo, schema_target
            )
        self.assertEqual("SYMLINK_FORBIDDEN", caught.exception.code)


if __name__ == "__main__":
    unittest.main()
