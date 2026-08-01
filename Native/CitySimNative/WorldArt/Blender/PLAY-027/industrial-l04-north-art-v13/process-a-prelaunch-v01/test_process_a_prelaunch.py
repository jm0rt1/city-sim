"""Hostile import/call proof for the retired North v13 prelaunch surface."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[6]
V02 = REPO / "Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v13/process-a-v02"
HISTORICAL_EVIDENCE = REPO / "docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v13/process-a-prelaunch-v01"
LEGACY_PREFIX = "citysim-play027-north-v13-test-attempt-"
FORBIDDEN_NAMES = (
    "build", "sign", "validat", "consume", "fixture", "schedule", "attempt",
    "child_start", "launcher", "token", "authority", "writer",
)


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def topology(root: Path) -> tuple[tuple[str, ...], tuple[str, ...]]:
    files: list[str] = []
    directories: list[str] = []
    if root.exists():
        for path in sorted(root.rglob("*")):
            relative = path.relative_to(root).as_posix()
            (directories if path.is_dir() else files).append(relative)
    return tuple(files), tuple(directories)


def legacy_topology() -> tuple[str, ...]:
    return tuple(sorted(path.name for path in Path("/private/tmp").glob(LEGACY_PREFIX + "*")))


def assert_surface_is_inert(module, label: str) -> None:
    names = {name for name in vars(module) if not name.startswith("_")}
    assert names <= {"RETIREMENT_STATE", "SOURCE_AUTHORITY", "PRODUCTION_SELECTED", "main", "annotations"}, (label, names)
    semantic_names = names - {"RETIREMENT_STATE", "SOURCE_AUTHORITY", "PRODUCTION_SELECTED", "annotations", "main"}
    assert not any(any(term in name.lower() for term in FORBIDDEN_NAMES) for name in semantic_names)
    assert not any(name in vars(module) for name in ("subprocess", "bpy", "hmac", "hashlib", "json", "Path"))
    assert getattr(module, "RETIREMENT_STATE") == "retired"
    if hasattr(module, "SOURCE_AUTHORITY"):
        assert module.SOURCE_AUTHORITY is False
        assert module.PRODUCTION_SELECTED is False
    else:
        assert not hasattr(module, "PRODUCTION_SELECTED")
    try:
        module.main(["--integration-direct", "--attempt", "forged"])
    except RuntimeError:
        pass
    else:
        raise AssertionError(f"retired {label} call unexpectedly succeeded")


def main() -> int:
    contract = json.loads((HERE / "EXECUTION-CONTRACT.json").read_text(encoding="utf-8"))
    runner_contract = json.loads((HERE / "RUNNER-CONTRACT.json").read_text(encoding="utf-8"))
    assert contract["status"] == "retired" and contract["executable"] is False
    assert runner_contract["status"] == "retired" and runner_contract["executable"] is False
    assert runner_contract["childStartCapability"] is False
    assert runner_contract["writerCapability"] is False

    source_paths = (
        HERE / "EXECUTION-CONTRACT.json",
        HERE / "RUNNER-CONTRACT.json",
        HERE / "launch_north_v13_prelaunch.py",
        HERE / "render_north_v13_process_a_child.py",
        HERE / "test_process_a_prelaunch.py",
    )
    preserved = {str(path): digest(path) for path in source_paths}
    preserved.update({str(path): digest(path) for path in HISTORICAL_EVIDENCE.glob("*") if path.is_file()})
    if V02.exists():
        preserved.update({str(path): digest(path) for path in V02.rglob("*") if path.is_file()})

    launch = load("retired_north_v13_prelaunch", HERE / "launch_north_v13_prelaunch.py")
    child = load("retired_north_v13_child", HERE / "render_north_v13_process_a_child.py")
    assert_surface_is_inert(launch, "launcher")
    assert_surface_is_inert(child, "child")

    before_legacy = legacy_topology()
    with tempfile.TemporaryDirectory(prefix="play027-retirement-", dir="/private/tmp") as fresh:
        fresh_root = Path(fresh)
        before = topology(fresh_root)
        assert before == ((), ())
        for module in (launch, child):
            try:
                module.main(["--root", str(fresh_root), "--write", "forged"])
            except RuntimeError:
                pass
            else:
                raise AssertionError("forged attempted call succeeded")
        assert topology(fresh_root) == before
    assert legacy_topology() == before_legacy

    for raw_path, before_hash in preserved.items():
        assert digest(Path(raw_path)) == before_hash, raw_path
    assert not any((HERE / name).exists() for name in ("PRELAUNCH.json", "ATTEMPT.json", "GRANT.json"))
    print("PASS retired v13 hostile imports/calls; files=0 directories=0 childStarts=0 dccStarts=0 pixelWrites=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
