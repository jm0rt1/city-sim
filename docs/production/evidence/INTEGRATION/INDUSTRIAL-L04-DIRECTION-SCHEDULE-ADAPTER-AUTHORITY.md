# Industrial L4 direction schedule-adapter authority

- **Integration base:** `be524831`
- **Batch:** `industrial_l04_directional_family`
- **Cells:** North `PLAY-027`, East `PLAY-079`, South `PLAY-080`, West `PLAY-081`
- **Stage:** parallel zero-pixel launch readiness
- **Production selected:** false

## Purpose

Prepare all four independent art cells to consume the executable Integration
schedule immediately when their process grants become legal. This preparation
runs concurrently. It does not serialize behind North appearance review and it
does not authorize a Blender or source-render child.

## Direction-local authorization

Each cell may edit only its existing exclusive task-owned source and evidence
roots. It may:

- add or adapt one direction-local schedule-consumer layer around its approved
  high-level orchestrator;
- bind schedule schema v1 and its semantic validator by exact path and SHA-256;
- require an exact direction, claim revision, base commit, process grant,
  DCC slot, exclusive roots, orchestrator binding, and child-start limit;
- fail closed when the schedule, grant, claim, base, appearance lock, source
  profile, slot, queue, owned roots, or orchestrator identity is absent, stale,
  mismatched, or illegal for the schedule phase;
- prove by adversarial tests that a blocked grant starts zero children and that
  direct low-level DCC invocation cannot pass through the adapter;
- retain one machine-readable zero-child readiness packet and a focused clean
  checkpoint.

The North adapter targets only the future `north:A` pre-lock grant. East,
South, and West adapters target their future post-lock A/B/C grants. Sibling
cells must not read or copy one another's task-owned scene geometry, source
pixels, or generated evidence.

## Required return

Return the exact clean commit, branch, base ancestry, changed-path inventory,
claim SHA-256, schema/validator hashes, adapter/orchestrator hashes, adversarial
test results, zero-child receipt, and explicit confirmation that no Blender,
DCC, render, source pixel, normalization, admission, Renderer, shipping,
runtime, package, shared-contract, push, or self-acceptance action occurred.

## Stop boundary

Stop after the zero-child adapter checkpoint. North Process A requires a new
validator-passing `prelock_north_a` schedule and exact launch grant.
East/South/West A/B/C require a later validator-passing `postlock_abc` schedule
that binds the independently accepted North appearance lock and published
source-production profile.
