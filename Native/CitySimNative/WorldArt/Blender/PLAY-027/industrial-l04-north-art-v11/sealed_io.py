#!/usr/bin/env python3
"""Descriptor-relative, fail-closed writes for the PLAY-027 v11 task roots."""

from __future__ import annotations

import json
import os
import stat
from pathlib import Path
from typing import Any, Iterable


DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
LEAF_FLAGS = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW


def exact_absolute(path: Path, expected: Path, label: str) -> Path:
    if not path.is_absolute() or path.parts != expected.parts:
        raise RuntimeError(
            f"{label} must have exact lexical identity: expected {expected}, got {path}"
        )
    return path


def reject_symlink_or_missing_chain(path: Path) -> None:
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        if not os.path.lexists(current):
            raise RuntimeError(f"missing or dangling path component: {current}")
        mode = os.lstat(current).st_mode
        if stat.S_ISLNK(mode):
            raise RuntimeError(f"symlink path component forbidden: {current}")


def _open_directory(path: Path) -> int:
    reject_symlink_or_missing_chain(path)
    descriptor = os.open(path.anchor, DIRECTORY_FLAGS)
    try:
        for part in path.parts[1:]:
            next_descriptor = os.open(
                part,
                DIRECTORY_FLAGS,
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def create_exact_directory(
    candidate: Path,
    expected: Path,
    allowed_new_directories: Iterable[Path],
) -> None:
    exact_absolute(candidate, expected, "output root")
    allowed = {item.parts for item in allowed_new_directories}
    descriptor = os.open(candidate.anchor, DIRECTORY_FLAGS)
    current = Path(candidate.anchor)
    try:
        for part in candidate.parts[1:]:
            current /= part
            exists = os.path.lexists(current)
            if current.parts in allowed:
                if exists:
                    raise RuntimeError(
                        f"authorized output directory must be absent: {current}"
                    )
                os.mkdir(part, mode=0o755, dir_fd=descriptor)
            elif not exists:
                raise RuntimeError(
                    f"missing or dangling non-output path component: {current}"
                )
            mode = os.lstat(current).st_mode
            if stat.S_ISLNK(mode):
                raise RuntimeError(f"symlink path component forbidden: {current}")
            if not stat.S_ISDIR(mode):
                raise RuntimeError(f"directory path component required: {current}")
            next_descriptor = os.open(
                part,
                DIRECTORY_FLAGS,
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
    finally:
        os.close(descriptor)


class SealedDirectory:
    """Write a fixed leaf inventory through one O_NOFOLLOW directory descriptor."""

    def __init__(self, root: Path, allowed_leaves: Iterable[str]) -> None:
        if not root.is_absolute():
            raise RuntimeError(f"sealed root must be absolute: {root}")
        reject_symlink_or_missing_chain(root)
        self.root = root
        self.allowed_leaves = frozenset(allowed_leaves)
        if not self.allowed_leaves:
            raise RuntimeError("sealed writer requires a nonempty leaf whitelist")
        for leaf in self.allowed_leaves:
            if (
                not leaf
                or leaf in {".", ".."}
                or Path(leaf).name != leaf
                or "/" in leaf
            ):
                raise RuntimeError(f"invalid sealed leaf name: {leaf!r}")

    def _validate_leaf(self, leaf: str) -> Path:
        if leaf not in self.allowed_leaves:
            raise RuntimeError(f"output leaf is not whitelisted: {leaf}")
        target = self.root / leaf
        if target.parts != (*self.root.parts, leaf):
            raise RuntimeError(f"output leaf lost lexical identity: {target}")
        reject_symlink_or_missing_chain(self.root)
        if os.path.lexists(target):
            raise RuntimeError(f"output leaf must be absent: {target}")
        return target

    def write_bytes(self, leaf: str, payload: bytes) -> None:
        target = self._validate_leaf(leaf)
        parent_descriptor = _open_directory(self.root)
        descriptor: int | None = None
        try:
            # Immediate descriptor-relative recheck closes the path-check/write gap.
            try:
                os.stat(leaf, dir_fd=parent_descriptor, follow_symlinks=False)
            except FileNotFoundError:
                pass
            else:
                raise RuntimeError(f"output leaf appeared before write: {target}")
            descriptor = os.open(
                leaf,
                LEAF_FLAGS,
                0o644,
                dir_fd=parent_descriptor,
            )
            mode = os.fstat(descriptor).st_mode
            if not stat.S_ISREG(mode):
                raise RuntimeError(f"regular output leaf required: {target}")
            remaining = memoryview(payload)
            while remaining:
                written = os.write(descriptor, remaining)
                if written <= 0:
                    raise RuntimeError(f"short write: {target}")
                remaining = remaining[written:]
            os.fsync(descriptor)
        finally:
            if descriptor is not None:
                os.close(descriptor)
            os.close(parent_descriptor)

    def write_json(self, leaf: str, value: Any) -> None:
        payload = (
            json.dumps(value, indent=2, sort_keys=True) + "\n"
        ).encode("utf-8")
        self.write_bytes(leaf, payload)

    def copy_regular(self, leaf: str, source: Path) -> None:
        reject_symlink_or_missing_chain(source.parent)
        if not source.is_file() or source.is_symlink():
            raise RuntimeError(f"regular non-symlink copy input required: {source}")
        self.write_bytes(leaf, source.read_bytes())
