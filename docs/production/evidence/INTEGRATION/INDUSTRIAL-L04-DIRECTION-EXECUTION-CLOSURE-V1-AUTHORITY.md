# Industrial L4 direction execution-closure v1 authority

- **Owner:** Integration
- **Schema:** `industrial-l04-direction-execution-authority-schema-v1.json`
- **Semantic validator:** `validate_industrial_l04_direction_execution_authority_v1.py`
- **Adversarial protocol:** revision 6, validation-only
- **Live DCC, child, render, or pixel authority:** none

## Purpose

This authority defines the last fail-closed validation boundary between an
Integration-published Industrial L4 process grant and a direction cell's
task-owned high-level runner. It does not publish a process-specific execution
instance and does not activate any schedule grant. A later Integration commit
must publish one exact instance and name its publication commit before a
direction worker can validate that closure. Separate explicit dispatch is still
required before any live execution.

The closure binds, without inference:

- the exact task, direction, branch, claim path, claim revision, claim hash,
  and published base;
- the exact Integration-owned schedule path, hash, phase, and publication
  commit;
- the appearance lock and source-production profile, or explicit pre-lock
  `null` values;
- one process, queue token, grant, slot, one-child maximum, and exactly-one
  invocation rule;
- the execution contract, direction schedule adapter, high-level orchestrator,
  runner contract and entrypoint, scene, materials, and toolchain by exact
  Git-published hashes;
- four direction-exclusive, fresh, non-overlapping output/evidence/attempt/
  terminal roots;
- the timeout, RSS, one-thread, new-process-group, kill-and-reap, no-network,
  fresh-lease, and no-replay envelope; and
- an anonymous-pipe secret hash plus a one-time HMAC-SHA256 child capability
  bound to the exact grant.

Every readiness, admission, Renderer, production, and shipping disposition is
false. Validation returns counters of zero for DCC starts, child starts,
renders, and pixels.

## Trust and publication rules

The validator requires all four caller inputs:

1. the repository path of the proposed Integration-owned authority instance;
2. a full trusted-head commit;
3. a full worker-head commit; and
4. the full authority-publication commit.

The trusted head must exactly equal the locally fetched
`refs/remotes/origin/master`; a symbolic name, stale local `master`, or
caller-selected substitute is rejected. The authority publication, schedule
publication, task base, and trusted head must have the required ancestry into
the worker head. The authority's current bytes must exactly equal the bytes
published at the supplied authority commit. Schedule, claim, shared bindings,
and task-owned artifacts are read from their exact Git commits and compared by
SHA-256; working-tree substitutes do not satisfy the gate.

The validator parses the authority and schedule with duplicate-key and
non-finite-number rejection. It rejects extra fields, shortened or missing
commits, traversal, sibling/shared roots, root overlap, pre-existing roots or
lease, artifact aliasing, stale bytes, a direct low-level runner call, replay,
forged capability binding, and any non-false product-readiness disposition.

## Direction-cell boundary

North, East, South, and West cells may consume a published authority instance
and this schema/validator. They may not edit, replace, vendor, shadow, or
republish any of these Integration-owned shared files:

- `docs/production/evidence/INTEGRATION/industrial-l04-direction-execution-authority-schema-v1.json`;
- `.agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_direction_execution_authority_v1.py`;
- `.agents/skills/operate-citysim-integration/scripts/test_validate_industrial_l04_direction_execution_authority_v1.py`; or
- this authority document.

A direction-local copy is not authoritative. An authority JSON outside the
top-level Integration evidence directory is rejected even if its bytes are
otherwise well formed.

## Revision-6 validation

Run only:

```bash
python3 .agents/skills/operate-citysim-integration/scripts/test_validate_industrial_l04_direction_execution_authority_v1.py
```

The suite uses temporary Git repositories and inert text fixtures. It creates
no live lease, child process, Blender/DCC process, render, source pixel,
normalization output, source candidate, Renderer input, production selection,
or shipping mutation.

## Stop boundary

Publication of these four control files is zero-DCC setup only. It does not
authorize a lease, high-level orchestrator invocation, low-level entrypoint,
Blender, Cycles, render, pixel, source candidate, appearance acceptance,
source-profile activation, admission, Renderer quarantine, production
selection, atlas/manifest change, or shipping. Integration must separately
publish and validate an exact process-specific authority instance after the
corresponding schedule exists, then explicitly dispatch that instance. Until
then, no pixel or DCC authority exists.
