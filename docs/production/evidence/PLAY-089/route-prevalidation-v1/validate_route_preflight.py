#!/usr/bin/env python3
"""Proposal-only route preflight checks for PLAY-089 evidence.

This module is deliberately offline. It validates a route projection and an
explicit producer/output contract; it does not dispatch work or call the
shared Integration validator.
"""

from __future__ import annotations

import os
import shlex
from pathlib import PurePosixPath
from typing import Any


def _error(code: str, message: str) -> dict[str, str]:
    return {"code": code, "message": message}


def _relative_path(value: Any) -> str | None:
    if not isinstance(value, str) or not value or "\\" in value:
        return None
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or "." in path.parts:
        return None
    return str(path)


def _under_root(path: str, root: str) -> bool:
    return path == root or path.startswith(root.rstrip("/") + "/")


def _command_has_shell_operator(command: str) -> bool:
    return any(token in command for token in (";", "|", ">", "<", "&&", "||", "`", "$"))


def _check_focused_command(command: Any, allowed_roots: list[str]) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    if not isinstance(command, str) or not command.strip():
        return [_error("invalid_focused_command", "focused command must be a non-empty string")]
    if _command_has_shell_operator(command):
        return [_error("invalid_focused_command", "focused command contains a shell operator")]
    try:
        words = shlex.split(command)
    except ValueError as exc:
        return [_error("invalid_focused_command", f"focused command is not shell-parseable: {exc}")]
    if not words or words[0] not in {"python3", "git"}:
        return [_error("invalid_focused_command", "focused command must begin with python3 or git")]
    if words[0] == "python3" and "-m" not in words:
        script_words = [word for word in words[1:] if not word.startswith("-")]
        if not script_words:
            errors.append(_error("invalid_focused_command", "python3 command has no producer script"))
        else:
            script = _relative_path(script_words[0])
            if script is None or not any(_under_root(script, root) for root in allowed_roots):
                errors.append(_error("invalid_focused_command", "producer script is outside claim-owned roots"))
    return errors


def validate_route(route: dict[str, Any], repository_root: str) -> dict[str, Any]:
    """Return deterministic errors for a proposal-only route preflight."""

    errors: list[dict[str, str]] = []
    if not isinstance(repository_root, str) or not os.path.isabs(repository_root):
        errors.append(_error("invalid_repository_root", "repository root must be absolute"))
    elif os.path.normpath(repository_root) != repository_root:
        errors.append(_error("invalid_repository_root", "repository root must be normalized"))

    if not isinstance(route, dict):
        return {"valid": False, "errors": errors + [_error("invalid_route", "route must be an object")]}

    model_route = route.get("modelRoute", route)
    if not isinstance(model_route, dict):
        errors.append(_error("invalid_route", "modelRoute must be an object"))
        return {"valid": False, "errors": errors}

    for field in ("routeId", "taskId", "classification", "model", "effort", "boundedDeliverable", "stopCondition"):
        if not isinstance(model_route.get(field), str) or not model_route[field]:
            errors.append(_error("missing_route_field", f"missing route field: {field}"))

    assignment = model_route.get("assignment")
    if not isinstance(assignment, dict):
        errors.append(_error("missing_assignment", "assignment contract is required"))
    else:
        if not isinstance(assignment.get("branch"), str) or not assignment["branch"]:
            errors.append(_error("missing_assignment", "branch is required"))
        if not isinstance(assignment.get("worktree"), str) or not os.path.isabs(assignment["worktree"]):
            errors.append(_error("invalid_assignment", "worktree must be absolute"))
        if not isinstance(assignment.get("expectedHead"), str) or not assignment["expectedHead"]:
            errors.append(_error("missing_assignment", "expectedHead is required"))

    path_policy = model_route.get("pathPolicy")
    allowed_roots: list[str] = []
    if not isinstance(path_policy, dict):
        errors.append(_error("missing_path_policy", "pathPolicy is required"))
    else:
        allowed = path_policy.get("allowed")
        claim_roots = path_policy.get("claimOwnedRoots")
        if not isinstance(allowed, list) or not allowed or not all(isinstance(item, str) for item in allowed):
            errors.append(_error("missing_path_policy", "at least one exact allowed root is required"))
        else:
            allowed_roots = allowed
        if allowed != claim_roots:
            errors.append(_error("path_policy_mismatch", "allowed roots must equal claim-owned roots"))

    focused_commands = (model_route.get("validation") or {}).get("focusedCommands")
    if not isinstance(focused_commands, list) or not focused_commands:
        errors.append(_error("missing_focused_commands", "focused commands are required"))
    else:
        for command in focused_commands:
            errors.extend(_check_focused_command(command, allowed_roots))

    contract = model_route.get("preflightContract")
    if not isinstance(contract, dict):
        errors.append(_error("missing_preflight_contract", "producer/output preflight contract is required"))
    else:
        contract_root = contract.get("repositoryRoot")
        if contract_root != repository_root:
            errors.append(_error("invalid_repository_root", "preflight repositoryRoot must equal supplied root"))
        producer = contract.get("producer")
        output = contract.get("output")
        if not isinstance(producer, dict) or not producer.get("command"):
            errors.append(_error("missing_producer_contract", "producer command is required"))
        else:
            errors.extend(_check_focused_command(producer["command"], allowed_roots))
        if not isinstance(output, dict) or not output.get("path"):
            errors.append(_error("missing_output_contract", "output path is required"))
        else:
            output_path = _relative_path(output["path"])
            if output_path is None or not any(_under_root(output_path, root) for root in allowed_roots):
                errors.append(_error("unsafe_output_path", "output path must remain under an exact allowed root"))
            if isinstance(producer, dict) and producer.get("outputPath") != output.get("path"):
                errors.append(_error("producer_output_mismatch", "producer outputPath must equal output path"))

    return {"valid": not errors, "errors": errors}
