# Worktree, Thread, and Git Operations

Read this reference before visible-task routing, worktree audit, staging, checkpointing, or synchronization.

## Keep delegation visible without pinning threads

- Delegate lane work through user-visible Codex threads whenever the user expects to observe or enter the work. Use an existing canonical lane thread when one exists; otherwise create a clearly titled project/worktree thread.
- Never pin an individual Codex thread. Do not call `set_thread_pinned` with `pinned: true` as a dispatch, prominence, reminder, or status mechanism. Pinning is user-owned interface organization.
- Keep tasks findable through descriptive thread titles, explicit delegation messages, reported thread IDs, and `list_threads`, `read_thread`, `send_message_to_thread`, and `wait_threads` status management.
- Do not alter pre-existing pin state. If this integration agent pinned a thread during the current operation, undo only that pin and disclose the correction.
- Internal subagents may support bounded analysis, but they must not substitute for a requested user-visible lane thread or edit the same worktree concurrently with its visible owner.

### Bind visible threads to exact worktrees

Treat a thread as a communication surface, never as sufficient routing
authority. Before every dispatch, verify and record the tuple
`{lane, direction, thread_id, branch, absolute_worktree, claim, base, head,
state}`. Reuse a canonical visible thread only when its current worktree,
branch, and claim match that tuple. Otherwise repair the routing or create a
new clearly titled project/worktree thread; never send mutation authority to a
stale, detached, or differently claimed checkout. Report the binding in the
management update so the user can inspect it without relying on pin state.

## Enforce intelligent commits everywhere

Treat commits as continuous durability and review boundaries, not end-of-project cleanup.

### Commit invariants

- Never use `git add -A` in a dirty multi-owner checkout. Stage explicit files or narrow directories.
- Inspect `git status --short`, `git diff`, `git diff --cached --check`, and `git diff --cached --stat` before every commit.
- Keep one coherent player, contract, test, evidence, or management outcome per commit.
- Never mix unrelated user work, multiple lanes, generated output, or speculative cleanup into a commit.
- Use messages such as `PLAY-030: Add typed command registry` or `Integration: Publish wave 1 baseline`.
- Commit after a coherent validated checkpoint, before handoff, before changing task or lane, before risky refactors/merges, and before ending a work turn with completed work.
- Allow explicit `checkpoint(PLAY-###): ...` commits on worker branches only when work is incomplete but worth preserving. Checkpoints cannot support `ready-for-integration` and must state failing or unrun validation.
- Require a completion record to name exact commit hashes. Completed-but-uncommitted work is invalid.
- Workers commit locally but do not push or integrate. Integration pushes accepted `master` and may preserve recovery branches when necessary.

### Worktree audit

At dispatch, status review, handoff, and integration, verify for every lane:

- expected branch/worktree and base ancestry;
- clean or explicitly explained dirty state;
- task claim matches changed paths;
- latest durable commit is current with reported progress;
- no staged leftovers, accidental generated files, or unrelated changes;
- divergence and merge dependencies are understood;
- completion hashes exist before acceptance.

If finished work is dirty, direct the owner to validate and commit it. If provenance is ambiguous, freeze the lane and preserve the diff before any cleanup.
