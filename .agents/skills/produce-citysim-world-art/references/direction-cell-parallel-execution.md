# Direction-Cell Parallel Execution

## Contents

- Immutable family and direction bindings
- Prelock and postlock direction execution
- Schedule, grant, and closure authority
- Direction-local job fan-out and execution receipts
- DCC capacity, joins, and failure isolation

Read this reference before stage execution, DCC authorization, parallel helpers, or direction-local return.

## Fan out one family across direction cells

Treat the Integration-published family contract as immutable. It must identify
the exact family/version, logical asset identity, scale, palette/material
roles, footprint, pivot, N/E/S/W camera and road-facing sockets, light, shadow,
and toolchain. The later Integration-published appearance lock must add the
exact independently accepted North process-A appearance authority and bind it
to that contract version/hash. An appearance lock is not North source
acceptance, family selection, renderer activation, or shipping authority.
Stop if the contract, family lock, branch claim, or source revision is missing,
stale, or contradictory for the requested stage; never repair shared authority
from a direction cell.

### Start the direction cell immediately

The first work update after a valid dispatch must publish the cell's compact
execution declaration:

`{directionBinding, stage, readyNow, running, waitingOnJoin,
serializedAuthority, nextRefill, capacity, unusedCapacityReasons}`

Then start every stage-legal job whose frozen inputs and exclusive roots are
ready. Do not return a plan while leaving ready work unstarted. During prelock,
that normally means direction-local scene/material authoring followed by
static and actual-camera zero-pixel proofs; during postlock production, it
means all granted A/B/C processes up to the published DCC cap plus any
independent CPU validation whose inputs are already closed. A sibling's
review, failure, queue position, or unfinished output is never a blocker for
direction-local work that does not consume it.

When the current cell has exhausted its stage-legal mutations, continue with
claim-owned inventory, provenance, validator, review-sheet, packet, or
rejection-preservation work when possible. Report idle only with the exact
prohibition, its authority owner, the resumption event, and why no such
preparation remains.

Use one branch, worktree, claim, and task-owned path set per direction. North
owns design calibration; East, South, and West independently own only their
named orientation. Run all Integration-authorized cells concurrently:

Freeze one immutable direction binding per cell:
`{familyContractPath/hash, direction, branch, worktree, claimPath/hash,
publishedBase, sourceRoot, evidenceRoot}`. The binding must be unique across
North/East/South/West and must not change during the claimed stage. Reject a
missing, duplicated, cross-direction, or drifted binding; only Integration may
publish a replacement family contract or claim revision.

1. **Before the family lock:** East, South, and West independently author
   text-scene/material bindings and run static plus actual-camera zero-pixel
   geometry, silhouette, portal/frontage, footprint, pivot, socket, light,
   shadow, and occlusion proofs. They do not render, normalize, or claim pixel
   authority. North does the same predesign work and may additionally execute
   exactly one Integration-scheduled and per-process-granted Process A
   appearance calibration. That North exception authorizes no B/C, source
   candidate, normalization, production handoff, sibling pixel authority,
   family selection, or renderer activation. North stops after Process A for
   independent technical and literal-scale review. When a sibling claim
   defines predesign as its complete deliverable, commit the passing predesign
   normally; otherwise preserve it as a non-ready checkpoint.
2. **After Integration publishes the appearance lock and updates the claims to
   authorize production:** North begins B/C while East, South, and West begin
   their independently authored A/B/C renders and deterministic validation,
   all concurrently. Do not wait for a sibling direction to finish. Bind every
   process to the exact appearance-lock hash.
3. **On a direction-local failure:** preserve its rejection and return only
   that direction to repair. Successful siblings retain their independent
   candidates and continue to handoff; they may not lend pixels, masks, scene
   geometry, or transformed coordinates to the failed cell.
4. **At handoff:** return direction candidates independently. Integration
   admits source candidates and Renderer quarantines admitted directions;
   direction cells perform neither action. Production selection and shipping
   activation remain blocked until Integration has the exact admitted and
   Renderer-quarantined N/E/S/W set. Selection is atomic at 4/4.

Direction cells never edit shared family contracts, material libraries,
shared authoring tools, shipping manifests, atlas slots, or sibling files.
Shared changes return to Integration or a separately claimed non-direction
shared-toolchain writer. Never copy, mirror, rotate, transform, or derive
sibling scene geometry or pixels.

Before every checkpoint, audit the complete changed-path range from the
claimed base through `HEAD`. Fail if any changed path is outside the
direction's claim-owned roots or if the cell consumed a sibling scene,
geometry, raster, mask, coordinate set, or evidence packet. Record the
changed-path inventory and `siblingInputsConsumed: []` in the machine-readable
handoff.

A post-lock production claim and dispatch authority must bind the exact claim
revision and published base; appearance-lock and source-production-profile
paths, hashes, and commits; authorized process set; immutable process/output
and evidence roots; source revision; compute-slot and queue policy; bounded
deliverable; and stop condition. A prelock claim or an appearance lock by
itself never authorizes pixels.

Launch production only through one Integration-published execution mode:

- `delegated_authenticated`: a direction cell invokes the approved
  orchestrator with an exact validated per-process grant. The grant binds the
  global schedule, compute lease, direction, claim revision, published base,
  frozen scene/material/toolchain hashes, process ID, exclusive roots, and one
  child start. No module that verifies this authority may also expose a public
  builder or accept a caller-selected verification key.
- `integration_direct`: the Integration captain, not the direction cell,
  invokes the exact approved high-level orchestrator from the governed
  worktree after validating the schedule, lease, branch, HEAD, claim, hashes,
  command, roots, and unused attempt marker. The direction cell may author and
  zero-child test that orchestrator, but cannot execute it. Integration records
  the child PID, command hash, start/end time, output roots, and exactly-one
  attempt before handing the closed output back to the visible cell.

Do not pretend repository-local Python can authenticate a hostile caller that
may import the verifier and choose its secret. If delegated authentication
cannot establish a real external trust root, use `integration_direct` and keep
the launch authority outside the worker process. In either mode, low-level
direction runners remain non-invocable directly, and A/B/C cannot begin while
the family schedule, strict validator, execution-mode authority, exact
orchestrator binding, or per-process grant is missing, stale, or unvalidated.

A passing schedule consumer or adapter is preparation, not launch readiness.
The execution-closure proof must show either a valid external delegated trust
root or an Integration-owned direct-launch boundary reaching the exact
high-level orchestrator and runner contract. A zero-child worker proof may
establish orchestrator readiness in `integration_direct` mode, but only the
later Integration-owned process receipt establishes that a launch occurred.
Direction-local closure code may bind the shared interface read-only but may
not copy a sibling launcher, constants, evidence, or task paths.

Zero-child checks certify only static prelaunch structure. They may not certify
that Blender starts, the child reaches its builder, the camera/lights/world are
valid, output directories exist at write time, paths remain contained, meshes
are renderable, or a PNG is decodable. Before Integration grants a production
attempt, the exact high-level orchestrator must pass one Integration-owned,
contained Blender smoke using the same launch/build/render path and a disposable
exclusive output root. The smoke must record the real Blender command and exit
status, process identity, created object/camera/light counts, output containment,
nonempty decodable render dimensions, and cleanup/retention disposition. It has
no source authority and cannot satisfy Process A/B/C, determinism, appearance,
or production selection. Static token or AST checks may supplement but never
replace this smoke.

After two unsuccessful implementation repairs, freeze the rejected descendants
and return the execution architecture to `FRONTIER_AUTHORITY`. Do not assign a
third Luna repair. Once the frontier reference passes the contained smoke and
is accepted, Luna siblings may implement against its exact bound bytes and
must run their own direction-local contained smoke before A/B/C production.

For Industrial L4, validate the exact Integration schedule with
`.agents/skills/operate-citysim-integration/scripts/validate_industrial_l04_parallel_execution_schedule_v1.py`.
Treat
`docs/production/evidence/INTEGRATION/industrial-l04-parallel-execution-schedule-schema-v1.json`
as the wire contract and
`docs/production/evidence/INTEGRATION/INDUSTRIAL-L04-PARALLEL-EXECUTION-SCHEDULE-V1-AUTHORITY.md`
as the operating authority. Direction-local adapters and runners may consume
those shared files read-only; they never edit them.

For any other family, resolve the schedule schema, validator, adversarial
tests, and operating authority from that family's exact Integration ledger and
contract. Fail closed if family-specific controls do not exist; never point a
new family at the Industrial L4 profile merely to obtain a passing validator.

### Parallelize inside each direction cell

Scene and material authoring remain single-writer until the exact
direction-local scene revision is frozen. After that freeze and only within
the stage authorized by the claim:

- publish a compact direction-local job plan before launching work. List every
  job's frozen inputs, exclusive output root, dependency, execution owner,
  state (`ready`, `running`, `joined`, or `blocked`), and join condition.
  Separate DCC/render capacity from CPU/helper capacity so a full render queue
  does not hide idle validation or evidence work;
- enqueue every authorized A, B, and C fresh process immediately, each writing
  only to its own immutable output directory. Integration's global scheduler
  keeps every available DCC slot occupied up to the published compute cap;
  queued processes do not block direction-local CPU validation, evidence, or
  packet preparation;
- never let one process consume, repair, rename, or overwrite another
  process's output;
- after the raw files close, run independent hash/RGBA, registration,
  normalization-repeat, literal-scale, grayscale, and contact-sheet jobs
  concurrently when their input/output paths are disjoint;
- preserve any failed process immediately without canceling passing siblings;
  and
- assign exactly one direction-local assembler to validate the complete packet
  and write the final handoff after all required jobs settle.

Use available internal helpers or parallel tool calls for bounded read-only
inspection and jobs writing only to isolated temporary roots outside the
direction worktree. The direction's visible worker remains the sole
scene/material writer before freeze and the sole worktree, Git index, governed
evidence packet, handoff, and commit writer throughout; it alone may validate
and adopt temporary outputs. Helpers may not mutate a shared scene, consume
unfinished inputs, stage or commit, relax a validator, or claim direction
completion. When safe eligible jobs outnumber launched jobs, record the
concrete capacity limit or ownership conflict; "working sequentially" is not
an explanation.

Follow this dependency graph; concurrency does not authorize consumers to race
unfinished inputs:

`raw A/B/C fan-out → per-process provenance/RGBA fan-out → identity join →
normalization-repeat fan-out → literal color/grayscale/contact-sheet fan-out →
single packet assembly`

Emit one machine-readable parallel-execution receipt containing the frozen
scene, material, schema, toolchain, and authority hashes; process IDs and
distinct roots; start/end timestamps; exactly-one-invocation assertions;
actual overlap; join results; validation-job roots; and the final assembler
identity. Also record ready-job count, maximum available DCC and helper
capacity, launched-job count, unused-capacity reasons, and each required join.
Its `executionAccounting` projection must use the exact Integration schema:
one bound job object per launch with batch, claim revision, base, head, visible
thread, branch, worktree, resource/mutation class, exclusive root, state,
interval, DCC slot/process when applicable, and exact visible-thread item
evidence. Bind the visible cell as sole Git/evidence writer, list every running
job exactly once, and give each unused helper or DCC slot its own reason.
If Integration's compute envelope requires a sequential render wave, record
the resource exception and queue order. Claim overlap only when the timestamps
prove it, and never exceed the published global DCC cap.

Treat the compute slot as a lease, not a department lock. A queued or failed
DCC process blocks only its own exclusive output root. Continue every
direction-local CPU-only provenance, validator, review-sheet, inventory, and
packet task whose inputs are closed, while sibling cells do the same. Never
cancel passing sibling work merely because one direction or process fails.

North's pre-lock process-A appearance calibration remains a one-process gate.
The internal A/B/C fan-out begins for North only after Integration publishes
the appearance lock and explicitly releases B/C. East, South, and West may
begin their full A/B/C fan-out concurrently at that same release boundary.
Parallel execution never relaxes fresh-process identity, exact input hashes,
or the requirement for byte/pixel determinism.
