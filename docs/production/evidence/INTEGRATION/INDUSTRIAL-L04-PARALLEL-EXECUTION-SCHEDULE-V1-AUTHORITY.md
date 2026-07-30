# Industrial L4 parallel execution schedule v1 authority

Integration publishes the first executable launch-schedule contract for the
Industrial L4 four-direction family. It turns the direction-cell fan-out from
an operating suggestion into fail-closed authority.

## Required behavior

- Integration publishes one immutable JSON schedule per launch phase.
- Every schedule binds the exact batch, Integration authority commit, family
  contract, direction claim revision, baseline commit, orchestrator, exclusive
  roots, process grant, DCC slot, child-start limit, and queue.
- A direction cell must validate the exact published schedule before mutation
  and again immediately before its approved orchestrator starts a child.
- A low-level renderer or DCC command is never directly invocable from the
  schedule. Every granted process is orchestrator-only and permits exactly one
  child start.
- A failed process consumes only its own grant and returns only its direction.
  It does not revoke or invalidate successful sibling grants.
- Integration alone publishes replacements, appearance locks, source profiles,
  production selection, shipping activation, exact-candidate QA leases,
  integration, and push.

## Two legal phases

`prelock_north_a` grants exactly one North Process A in one DCC slot. North B/C
and every East/South/West pixel process remain blocked. The appearance lock and
source-production profile must be absent.

`postlock_abc` requires exact appearance-lock and source-profile bindings. It
grants North B/C and East/South/West A/B/C, with at least three concurrent DCC
slots. Those processes may execute independently and concurrently under their
own exclusive roots. Atomic Renderer activation remains blocked until all four
directions have Integration-admitted exact source receipts.

## Published machine controls

- Schema:
  `docs/production/evidence/INTEGRATION/industrial-l04-parallel-execution-schedule-schema-v1.json`
- Semantic validator:
  `.agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_parallel_execution_schedule_v1.py`
- No-DCC adversarial tests:
  `.agents/skills/operate-citysim-integration/scripts/test_validate_industrial_l04_parallel_execution_schedule_v1.py`

The JSON Schema documents the wire contract. The semantic validator is binding:
it verifies repository-relative file hashes and commit identities, exact lane
ownership, disjoint roots, phase legality, grant/queue equality, child limits,
orchestrator-only execution, and the minimum post-lock concurrency.

This authority does not itself grant any source process. A separately
published, validator-passing schedule and lane claim are required.
