#!/usr/bin/env python3
"""Validate the self-contained v10 bundle and every task-owned writer class."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Callable

from sealed_io import SealedDirectory, create_exact_directory


SOURCE_REL = Path(
    "Native/CitySimNative/WorldArt/Blender/PLAY-027/"
    "industrial-l04-north-art-v10"
)
EVIDENCE_REL = Path(
    "docs/production/evidence/PLAY-027/industrial-l04/l04/"
    "blender-north-art-v10"
)
MANIFEST_SHA256 = (
    "1e25cab5e751ff1a627ede8eee0521f184e8339c11fa176bea78c3df85d5d466"
)
RETAINED_EVIDENCE = {
    "HANDOFF.json": (
        "48a5d4228af280adb225d89ae523454e7161187b879eaa988cf217afbe14bf5b"
    ),
    "REPLAY-IDENTITY.json": (
        "6c42535c9411c5a0979f52dccc2db33b59812f1fe95a07202f8ceae9e273a097"
    ),
    "replay-a/EXACT-192-COLOR.png": (
        "4555aad01bb3cba86f7a26f16c12bf8165463cfe70a6c4553b3f3aa423c2c235"
    ),
    "replay-a/EXACT-192-GRAYSCALE.png": (
        "e81ccae7c45711d8f0c3054b5be9152c21a0527617d4a6a0a495d50e4cf6a87b"
    ),
    "replay-a/EXACT-192-SEMANTIC.png": (
        "924b0b22d011360abb6e6ec264531d1e3d9fa2ec46baf6a0217e11e7427ce3f2"
    ),
    "replay-a/FIELD-DIFF.json": (
        "de5c974ad74fd373ee6d99d93e4baadc5a2f59ec4b14f3651eb3a292db32755e"
    ),
    "replay-a/MATERIALS.json": (
        "e683feed89f6878903d1ec0b255d0d5e8a36c74f431a2fb723287bf955c54d09"
    ),
    "replay-a/SCENE.json": (
        "0f572b80ec8d17f23e8569816e9a1f17502b114c1a4e361ea582d4ca388f8459"
    ),
    "replay-a/V08-V09-V10-COMPARISON.png": (
        "14af06a0ec75bcc6a6273f8a2099a529f9091b06ee291c406aca81082a77135e"
    ),
    "replay-a/VALIDATION.json": (
        "c733cbb8e0c6dc01247bff272bc9fcc21eefe36767ce0d57f33926fb043379eb"
    ),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def expect_rejection(label: str, action: Callable[[], None]) -> dict[str, str]:
    try:
        action()
    except (OSError, RuntimeError, ValueError) as error:
        return {"case": label, "result": "PASS_REJECTED", "error": str(error)}
    raise RuntimeError(f"negative path test unexpectedly succeeded: {label}")


def writer_action(
    writer_class: str,
    root: Path,
    source: Path,
    allowed_leaf: str,
    attempt_leaf: str | None = None,
) -> None:
    leaf = attempt_leaf or allowed_leaf
    sealed = SealedDirectory(root, {allowed_leaf})
    if writer_class == "builder-copy":
        sealed.copy_regular(leaf, source)
    elif writer_class == "builder-json":
        sealed.write_json(leaf, {"writer": writer_class})
    elif writer_class == "builder-png":
        sealed.write_bytes(leaf, b"\x89PNG\r\n\x1a\nsealed-fixture")
    elif writer_class == "assembler-json":
        sealed.write_json(leaf, {"writer": writer_class})
    else:
        raise RuntimeError(f"unknown writer class: {writer_class}")


def exercise_writer_negatives(temp_root: Path) -> list[dict[str, str]]:
    results: list[dict[str, str]] = []
    source = temp_root / "copy-source.bin"
    source.write_bytes(b"immutable-copy-source")
    writer_classes = (
        "builder-copy",
        "builder-json",
        "builder-png",
        "assembler-json",
    )
    for writer_class in writer_classes:
        class_root = temp_root / writer_class
        class_root.mkdir()
        allowed_leaf = f"{writer_class}.out"
        results.append(
            expect_rejection(
                f"{writer_class}:arbitrary-leaf",
                lambda root=class_root: writer_action(
                    writer_class,
                    root,
                    source,
                    allowed_leaf,
                    "not-whitelisted.out",
                ),
            )
        )
        results.append(
            expect_rejection(
                f"{writer_class}:outside-leaf",
                lambda root=class_root: writer_action(
                    writer_class,
                    root,
                    source,
                    allowed_leaf,
                    "../outside.out",
                ),
            )
        )

        preexisting_root = temp_root / f"{writer_class}-preexisting"
        preexisting_root.mkdir()
        (preexisting_root / allowed_leaf).write_bytes(b"occupied")
        results.append(
            expect_rejection(
                f"{writer_class}:preexisting-leaf",
                lambda root=preexisting_root: writer_action(
                    writer_class,
                    root,
                    source,
                    allowed_leaf,
                ),
            )
        )

        shared_root = temp_root / f"{writer_class}-shared"
        shared_root.mkdir()
        shared_target = temp_root / f"{writer_class}-shared-target"
        shared_target.write_bytes(b"shared")
        os.symlink(shared_target, shared_root / allowed_leaf)
        results.append(
            expect_rejection(
                f"{writer_class}:shared-symlink-leaf",
                lambda root=shared_root: writer_action(
                    writer_class,
                    root,
                    source,
                    allowed_leaf,
                ),
            )
        )

        dangling_root = temp_root / f"{writer_class}-dangling"
        dangling_root.mkdir()
        os.symlink(
            temp_root / f"{writer_class}-missing-target",
            dangling_root / allowed_leaf,
        )
        results.append(
            expect_rejection(
                f"{writer_class}:dangling-symlink-leaf",
                lambda root=dangling_root: writer_action(
                    writer_class,
                    root,
                    source,
                    allowed_leaf,
                ),
            )
        )

        redirect_target = temp_root / f"{writer_class}-redirect-target"
        redirect_target.mkdir()
        redirect_root = temp_root / f"{writer_class}-redirect-root"
        os.symlink(redirect_target, redirect_root)
        results.append(
            expect_rejection(
                f"{writer_class}:symlink-parent",
                lambda root=redirect_root: writer_action(
                    writer_class,
                    root,
                    source,
                    allowed_leaf,
                ),
            )
        )

        dangling_parent = temp_root / f"{writer_class}-dangling-parent"
        os.symlink(
            temp_root / f"{writer_class}-missing-parent",
            dangling_parent,
        )
        results.append(
            expect_rejection(
                f"{writer_class}:dangling-parent",
                lambda root=dangling_parent: writer_action(
                    writer_class,
                    root,
                    source,
                    allowed_leaf,
                ),
            )
        )
    return results


def exercise_root_negatives(temp_root: Path) -> list[dict[str, str]]:
    parent = temp_root / "repository" / "evidence"
    parent.mkdir(parents=True)
    expected = parent / "replay-a"
    results = [
        expect_rejection(
            "root:arbitrary",
            lambda: create_exact_directory(
                parent / "arbitrary",
                expected,
                (expected,),
            ),
        ),
        expect_rejection(
            "root:outside",
            lambda: create_exact_directory(
                temp_root / "outside",
                expected,
                (expected,),
            ),
        ),
    ]
    expected.mkdir()
    results.append(
        expect_rejection(
            "root:preexisting",
            lambda: create_exact_directory(expected, expected, (expected,)),
        )
    )
    expected.rmdir()
    shared = temp_root / "shared-root"
    shared.mkdir()
    os.symlink(shared, expected)
    results.append(
        expect_rejection(
            "root:shared-symlink",
            lambda: create_exact_directory(expected, expected, (expected,)),
        )
    )
    expected.unlink()
    os.symlink(temp_root / "missing-root", expected)
    results.append(
        expect_rejection(
            "root:dangling-symlink",
            lambda: create_exact_directory(expected, expected, (expected,)),
        )
    )
    return results


def verify_source_objects(
    repository: Path,
    manifest: dict[str, Any],
) -> list[dict[str, Any]]:
    results = []
    for item in manifest["files"]:
        spec = f"{item['sourceCommit']}:{item['sourcePath']}"
        process = subprocess.run(
            ["git", "cat-file", "blob", spec],
            cwd=repository,
            check=True,
            stdout=subprocess.PIPE,
        )
        results.append(
            {
                "path": item["path"],
                "sourceCommit": item["sourceCommit"],
                "sourcePath": item["sourcePath"],
                "sourceObjectSHA256": hashlib.sha256(
                    process.stdout
                ).hexdigest(),
                "bundleSHA256": item["sha256"],
                "equal": hashlib.sha256(process.stdout).hexdigest()
                == item["sha256"],
            }
        )
    if not all(item["equal"] for item in results):
        raise RuntimeError("frozen input differs from declared source object")
    return results


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--record", action="store_true")
    parser.add_argument("--verify-source-objects", action="store_true")
    args = parser.parse_args()

    repository = args.repository_root
    if not repository.is_absolute() or repository.resolve() != repository:
        raise RuntimeError("repository root must be exact and canonical")
    source_root = repository / SOURCE_REL
    evidence_root = repository / EVIDENCE_REL
    bundle_root = source_root / "frozen-inputs"
    manifest_path = bundle_root / "MANIFEST.json"
    if sha256(manifest_path) != MANIFEST_SHA256:
        raise RuntimeError("frozen-input manifest hash drift")
    manifest = load_json(manifest_path)
    bundle_inventory = {}
    for item in manifest["files"]:
        path = bundle_root / item["path"]
        actual = sha256(path)
        if actual != item["sha256"] or path.stat().st_size != item["bytes"]:
            raise RuntimeError(f"frozen-input drift: {path}")
        bundle_inventory[item["path"]] = actual

    actual_retained = {
        relative: sha256(evidence_root / relative)
        for relative in RETAINED_EVIDENCE
    }
    if actual_retained != RETAINED_EVIDENCE:
        raise RuntimeError("retained v10 replay/disposition bytes changed")

    with tempfile.TemporaryDirectory(
        prefix="play027-v10-portability-",
        dir="/private/tmp",
    ) as temporary:
        temp_root = Path(temporary)
        negative_results = [
            *exercise_writer_negatives(temp_root),
            *exercise_root_negatives(temp_root),
        ]
        for result in negative_results:
            result["error"] = result["error"].replace(
                str(temp_root),
                "<DISPOSABLE_ROOT>",
            )

    source_object_results: list[dict[str, Any]] | str
    if args.verify_source_objects:
        source_object_results = verify_source_objects(repository, manifest)
    else:
        source_object_results = (
            "NOT_REQUIRED_FOR_PORTABLE_REPLAY; bundle hashes are authoritative"
        )

    receipt = {
        "schema": 1,
        "task": "PLAY-027",
        "stage": "north-v10-portability-path-repair",
        "frozenCandidate": (
            "afa796700d1e693bf6f1af89bfabd8197d2d5a95"
        ),
        "preservedCommits": [
            "29d28842a3ca655d9fd661d0c49f8ff5ddcb7a4e",
            "414c200e7a99933f5aa5aa202598e94bf4106fb8",
            "afa796700d1e693bf6f1af89bfabd8197d2d5a95",
        ],
        "bundleManifestSHA256": MANIFEST_SHA256,
        "bundleInventory": bundle_inventory,
        "sourceObjectVerification": source_object_results,
        "pathPolicy": {
            "lexicalIdentity": True,
            "descriptorRelativeParents": True,
            "parentOpenFlags": ["O_DIRECTORY", "O_NOFOLLOW"],
            "leafOpenFlags": ["O_CREAT", "O_EXCL", "O_NOFOLLOW"],
            "immediatePreWriteRecheck": True,
            "symlinkAndDanglingComponentsRejected": True,
        },
        "writerClasses": [
            "builder-copy",
            "builder-json",
            "builder-png",
            "assembler-json",
        ],
        "negativeTests": negative_results,
        "negativeTestCount": len(negative_results),
        "allNegativeTestsPassed": all(
            item["result"] == "PASS_REJECTED" for item in negative_results
        ),
        "retainedEvidence": actual_retained,
        "retainedReplayAByteIdentity": True,
        "retainedFirstFailure": {
            "westJambUnErodedCorePixels": 7,
            "westJambOnePixelErodedCorePixels": 0,
            "westJambBounds": [107, 82, 110, 85],
            "validationPassed": False,
        },
        "newProcessCounts": {
            "analytic": 0,
            "blender": 0,
            "cycles": 0,
            "sceneKit": 0,
            "metal": 0,
            "imageGen": 0,
            "normalizer": 0,
            "A": 0,
            "B": 0,
            "C": 0,
            "siblings": 0,
        },
        "disposition": "PORTABILITY_PATH_REPAIR_ONLY_V10_REMAINS_REJECTED",
        "sourceAuthority": False,
        "productionSelected": False,
    }
    if args.record:
        writer = SealedDirectory(
            evidence_root,
            {"PORTABILITY-REPAIR.json"},
        )
        writer.write_json("PORTABILITY-REPAIR.json", receipt)
    else:
        print(json.dumps(receipt, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
