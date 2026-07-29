#!/usr/bin/env python3
"""Fail-closed output-path policy for the PLAY-079 East source cell."""

from __future__ import annotations

import contextlib
import errno
import os
import pathlib
import stat
from collections.abc import Callable, Iterator, Mapping


SOURCE_ROOT = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SOURCE_ROOT.parents[5]
SOURCE_PREFIX = (
    "Native/CitySimNative/WorldArt/Blender/PLAY-079/"
    "industrial-l04-east-source-v01/"
)
EVIDENCE_PREFIX = (
    "docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/"
)


class OutputSafetyRejected(RuntimeError):
    """Stable fail-closed output safety rejection."""

    def __init__(self, code: str, detail: str):
        super().__init__(detail)
        self.code = code
        self.detail = detail


def _process_paths(process: str) -> set[str]:
    lower = process.lower()
    return {
        f"{EVIDENCE_PREFIX}renders/process-{lower}/raw/industrial-l04-east-{lower}.png",
        (
            f"{EVIDENCE_PREFIX}renders/process-{lower}/semantic/"
            f"industrial-l04-east-{lower}-semantic.png"
        ),
        f"{EVIDENCE_PREFIX}renders/process-{lower}/provenance.json",
    }


def _normalization_paths() -> set[str]:
    values: set[str] = {
        f"{EVIDENCE_PREFIX}validation/NORMALIZATION-REPEAT.json",
    }
    for run in (1, 2):
        values.add(f"{EVIDENCE_PREFIX}normalization/run-{run}/NORMALIZATION-RECEIPT.json")
        for detail in ("city", "neighborhood", "block"):
            values.add(
                f"{EVIDENCE_PREFIX}normalization/run-{run}/{detail}/"
                f"industrial-l04-east-{detail}.png"
            )
    return values


WRITER_IDENTITIES: Mapping[str, frozenset[str]] = {
    "prepare_launch_bound": frozenset(
        {
            f"{EVIDENCE_PREFIX}SOURCE-STAGE-LAUNCH-GUARD-RECEIPT.json",
            f"{EVIDENCE_PREFIX}SOURCE-STAGE-HANDOFF.json",
        }
    ),
    "run_production": frozenset(
        _process_paths("A") | _process_paths("B") | _process_paths("C")
    ),
    "validation": frozenset(
        {
            f"{EVIDENCE_PREFIX}PRELOCK-VALIDATION.json",
            f"{EVIDENCE_PREFIX}HANDOFF-SCHEMA-VALIDATION.json",
            f"{EVIDENCE_PREFIX}LAUNCH-BOUND-CLI-VALIDATION.json",
            f"{EVIDENCE_PREFIX}EAST-ZERO-PIXEL-READINESS.json",
            f"{EVIDENCE_PREFIX}COORDINATE-BRIDGE-V06-ADOPTION.json",
            f"{EVIDENCE_PREFIX}COORDINATE-BRIDGE-V06-BLOCKER.json",
            f"{EVIDENCE_PREFIX}validation/REGISTRATION.json",
            f"{EVIDENCE_PREFIX}validation/RGBA-IDENTITY.json",
            f"{EVIDENCE_PREFIX}validation/ALPHA-CHROMA-HIDDEN-RGB.json",
            f"{EVIDENCE_PREFIX}validation/OCCUPIED-BOUNDS.json",
            f"{EVIDENCE_PREFIX}validation/LITERAL-192.json",
            f"{EVIDENCE_PREFIX}validation/NON-ALIASING.json",
            f"{EVIDENCE_PREFIX}validation/ABC-EQUALITY.json",
            f"{EVIDENCE_PREFIX}validation/SOURCE-CANDIDATE-VALIDATION.json",
            f"{EVIDENCE_PREFIX}OUTPUT-PATH-SAFETY-VALIDATION.json",
        }
    ),
    "normalization": frozenset(_normalization_paths()),
    "receipt": frozenset(
        {
            f"{EVIDENCE_PREFIX}SOURCE-STAGE-PRELOCK-RECEIPT.json",
            f"{EVIDENCE_PREFIX}PARALLEL-EXECUTION-RECEIPT.json",
            f"{EVIDENCE_PREFIX}review/REVIEW-MANIFEST.json",
            *(
                f"{EVIDENCE_PREFIX}execution/process-{process}/INVOCATION-RECEIPT.json"
                for process in ("a", "b", "c")
            ),
            *(
                f"{EVIDENCE_PREFIX}normalization/run-{run}/NORMALIZATION-RECEIPT.json"
                for run in (1, 2)
            ),
        }
    ),
    "review": frozenset(
        {
            f"{EVIDENCE_PREFIX}review/CONTACT-SHEET.png",
            *(
                f"{EVIDENCE_PREFIX}review/{mode}/{scale}.png"
                for mode in ("color", "grayscale")
                for scale in ("source", "native-2x", "literal-192")
            ),
        }
    ),
    "rejection": frozenset(
        {
            f"{EVIDENCE_PREFIX}MISSING-LOCK-REJECTION.json",
            f"{EVIDENCE_PREFIX}WRONG-LOCK-REJECTION.json",
            f"{EVIDENCE_PREFIX}rejections/REJECTION-INVENTORY.json",
        }
    ),
    "source_candidate": frozenset(
        {
            f"{EVIDENCE_PREFIX}validation/SOURCE-CANDIDATE-VALIDATION.json",
        }
    ),
}


def _parts(relative: str) -> tuple[str, ...]:
    if not relative or relative.startswith("/") or "\\" in relative:
        raise OutputSafetyRejected("output_identity_not_repo_relative", repr(relative))
    pure = pathlib.PurePosixPath(relative)
    if pure.as_posix() != relative or any(part in {"", ".", ".."} for part in pure.parts):
        raise OutputSafetyRejected("output_identity_not_canonical", repr(relative))
    return pure.parts


class OutputPolicy:
    """Exact-identity output policy with descriptor-relative writes."""

    def __init__(
        self,
        repository_root: pathlib.Path,
        writer_identities: Mapping[str, frozenset[str]],
    ):
        self.repository_root = pathlib.Path(os.path.abspath(repository_root))
        self.writer_identities = writer_identities

    def exact_relative(self, path: pathlib.Path | str, writer_class: str) -> str:
        allowed = self.writer_identities.get(writer_class)
        if allowed is None:
            raise OutputSafetyRejected("unknown_writer_class", writer_class)
        candidate = pathlib.Path(path)
        if not candidate.is_absolute():
            raise OutputSafetyRejected("output_path_not_absolute", str(path))
        try:
            relative = candidate.relative_to(self.repository_root).as_posix()
        except ValueError as error:
            raise OutputSafetyRejected("output_path_outside_repository", str(candidate)) from error
        _parts(relative)
        expected = self.repository_root / pathlib.PurePosixPath(relative)
        if candidate != expected:
            raise OutputSafetyRejected("output_path_not_lexically_exact", str(candidate))
        if relative not in allowed:
            raise OutputSafetyRejected(
                "output_identity_not_allowed",
                f"{writer_class}: {relative}",
            )
        return relative

    def reject_symlink_components(self, relative: str) -> None:
        current = self.repository_root
        try:
            root_status = os.lstat(current)
        except OSError as error:
            raise OutputSafetyRejected("repository_root_unavailable", str(error)) from error
        if stat.S_ISLNK(root_status.st_mode):
            raise OutputSafetyRejected("output_symlink_component", str(current))
        missing_seen = False
        for component in _parts(relative):
            current = current / component
            try:
                status = os.lstat(current)
            except FileNotFoundError:
                missing_seen = True
                continue
            except OSError as error:
                raise OutputSafetyRejected("output_component_unreadable", str(error)) from error
            if missing_seen:
                raise OutputSafetyRejected(
                    "output_component_after_missing_parent",
                    str(current),
                )
            if stat.S_ISLNK(status.st_mode):
                raise OutputSafetyRejected("output_symlink_component", str(current))

    def _open_parent(self, relative: str, create: bool) -> tuple[int, str]:
        parts = _parts(relative)
        if len(parts) < 2:
            raise OutputSafetyRejected("output_parent_missing", relative)
        flags = os.O_RDONLY | os.O_DIRECTORY
        if hasattr(os, "O_CLOEXEC"):
            flags |= os.O_CLOEXEC
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        directory_fd = os.open(self.repository_root, flags)
        try:
            for component in parts[:-1]:
                try:
                    next_fd = os.open(component, flags, dir_fd=directory_fd)
                except FileNotFoundError:
                    if not create:
                        raise
                    try:
                        os.mkdir(component, mode=0o755, dir_fd=directory_fd)
                    except FileExistsError:
                        pass
                    next_fd = os.open(component, flags, dir_fd=directory_fd)
                os.close(directory_fd)
                directory_fd = next_fd
            return directory_fd, parts[-1]
        except OSError as error:
            os.close(directory_fd)
            code = (
                "output_symlink_component"
                if error.errno in {errno.ELOOP, errno.ENOTDIR}
                else "output_parent_open_failed"
            )
            raise OutputSafetyRejected(code, f"{relative}: {error}") from error

    def ensure_parent(self, path: pathlib.Path | str, writer_class: str) -> str:
        relative = self.exact_relative(path, writer_class)
        self.reject_symlink_components(relative)
        parent_fd, _leaf = self._open_parent(relative, create=True)
        os.close(parent_fd)
        self.reject_symlink_components(relative)
        return relative

    def write_bytes_exclusive(
        self,
        path: pathlib.Path | str,
        payload: bytes,
        writer_class: str,
        *,
        pre_write_hook: Callable[[], None] | None = None,
    ) -> str:
        relative = self.ensure_parent(path, writer_class)
        if pre_write_hook is not None:
            pre_write_hook()
        # Required second check immediately before descriptor-relative creation.
        self.exact_relative(path, writer_class)
        self.reject_symlink_components(relative)
        parent_fd, leaf = self._open_parent(relative, create=False)
        file_fd: int | None = None
        try:
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
            if hasattr(os, "O_CLOEXEC"):
                flags |= os.O_CLOEXEC
            if hasattr(os, "O_NOFOLLOW"):
                flags |= os.O_NOFOLLOW
            file_fd = os.open(leaf, flags, 0o644, dir_fd=parent_fd)
            if not stat.S_ISREG(os.fstat(file_fd).st_mode):
                raise OutputSafetyRejected("output_leaf_not_regular", relative)
            view = memoryview(payload)
            while view:
                written = os.write(file_fd, view)
                if written <= 0:
                    raise OSError(errno.EIO, "short output write")
                view = view[written:]
            os.fsync(file_fd)
        except FileExistsError as error:
            raise OutputSafetyRejected("output_already_exists", relative) from error
        except OSError as error:
            code = "output_symlink_component" if error.errno == errno.ELOOP else "output_write_failed"
            raise OutputSafetyRejected(code, f"{relative}: {error}") from error
        finally:
            if file_fd is not None:
                os.close(file_fd)
            os.close(parent_fd)
        return relative

    @contextlib.contextmanager
    def reserve_external_output(
        self,
        path: pathlib.Path | str,
        writer_class: str,
        *,
        pre_write_hook: Callable[[], None] | None = None,
    ) -> Iterator[pathlib.Path]:
        """Reserve a regular leaf before an external DCC writer may open it."""

        relative = self.ensure_parent(path, writer_class)
        if pre_write_hook is not None:
            pre_write_hook()
        self.exact_relative(path, writer_class)
        self.reject_symlink_components(relative)
        parent_fd, leaf = self._open_parent(relative, create=False)
        flags = os.O_RDWR | os.O_CREAT | os.O_EXCL
        if hasattr(os, "O_CLOEXEC"):
            flags |= os.O_CLOEXEC
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            file_fd = os.open(leaf, flags, 0o644, dir_fd=parent_fd)
        except FileExistsError as error:
            os.close(parent_fd)
            raise OutputSafetyRejected("output_already_exists", relative) from error
        except OSError as error:
            os.close(parent_fd)
            code = "output_symlink_component" if error.errno == errno.ELOOP else "output_write_failed"
            raise OutputSafetyRejected(code, f"{relative}: {error}") from error
        reserved = os.fstat(file_fd)
        try:
            yield self.repository_root / pathlib.PurePosixPath(relative)
            self.reject_symlink_components(relative)
            current = os.stat(leaf, dir_fd=parent_fd, follow_symlinks=False)
            if not stat.S_ISREG(current.st_mode):
                raise OutputSafetyRejected("output_leaf_not_regular", relative)
            if (current.st_dev, current.st_ino) != (reserved.st_dev, reserved.st_ino):
                raise OutputSafetyRejected("output_inode_changed", relative)
        finally:
            os.close(file_fd)
            os.close(parent_fd)

    def remove_created_output(self, path: pathlib.Path | str, writer_class: str) -> None:
        relative = self.exact_relative(path, writer_class)
        self.reject_symlink_components(relative)
        parent_fd, leaf = self._open_parent(relative, create=False)
        try:
            status = os.stat(leaf, dir_fd=parent_fd, follow_symlinks=False)
            if not stat.S_ISREG(status.st_mode):
                raise OutputSafetyRejected("output_leaf_not_regular", relative)
            os.unlink(leaf, dir_fd=parent_fd)
        except FileNotFoundError:
            return
        except OSError as error:
            raise OutputSafetyRejected("output_remove_failed", f"{relative}: {error}") from error
        finally:
            os.close(parent_fd)


PRODUCTION_POLICY = OutputPolicy(REPOSITORY_ROOT, WRITER_IDENTITIES)


def require_output_path(path: pathlib.Path | str, writer_class: str) -> str:
    return PRODUCTION_POLICY.exact_relative(path, writer_class)


def ensure_output_parent(path: pathlib.Path | str, writer_class: str) -> str:
    return PRODUCTION_POLICY.ensure_parent(path, writer_class)


def write_bytes_exclusive(
    path: pathlib.Path | str,
    payload: bytes,
    writer_class: str,
) -> str:
    return PRODUCTION_POLICY.write_bytes_exclusive(path, payload, writer_class)


def reserve_external_output(
    path: pathlib.Path | str,
    writer_class: str,
) -> contextlib.AbstractContextManager[pathlib.Path]:
    return PRODUCTION_POLICY.reserve_external_output(path, writer_class)


def remove_created_output(path: pathlib.Path | str, writer_class: str) -> None:
    PRODUCTION_POLICY.remove_created_output(path, writer_class)
