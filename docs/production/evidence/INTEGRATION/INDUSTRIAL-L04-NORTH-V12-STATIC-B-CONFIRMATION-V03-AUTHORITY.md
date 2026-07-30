# Industrial L4 North v12 static-B confirmation v03

**Owner:** Integration
**Task:** PLAY-027
**Branch:** `codex/citysim-world-art`
**Frozen worker candidate:** `81d51486fb2086e26ab08dd200221c5eb8d79edb`
**Supersedes:** `INDUSTRIAL-L04-NORTH-V12-STATIC-B-CONFIRMATION-V02-AUTHORITY.md`
at SHA-256
`fdb36c1ab9061490724b04b9a351d711bd81ec13ec3edda9c42c455316d1162a`

## V02 disposition

V02 remains rejected as resource-envelope proof and immutable. Its only child
returned zero, emitted all six expected static outputs, passed semantic
validation, reproduced the five run-neutral files byte-for-byte, changed only
the two authorized `INPUT-BINDINGS.json` pointers, and produced no render,
pixel, or `.blend` output. The wrapper nevertheless failed closed because the
maximum wall-clock interval between parent-observer iterations was
`0.133433s`, above its `0.05s` cadence threshold.

That interval included a blocking full-system `/bin/ps -axo pgid=,rss=` scan,
the requested observer sleep, and host scheduler descheduling. It was not a
scene, output, or product-determinism measurement. The gap also means V02
cannot prove that no transient resource peak occurred, so its result may not
be promoted or reinterpreted as passing.

## Exact authority binding

- PLAY-027 claim SHA-256:
  `21495a4a19918ae68f14da1a90f33145a09b94942f9a9ea54f6475fb484d2890`.
- Frozen V02 failure candidate:
  `81d51486fb2086e26ab08dd200221c5eb8d79edb`.
- Accepted static-A content and all V02 evidence remain read-only.
- The external dispatch must supply and verify this file's post-publication
  SHA-256, the exact publication commit, and the claim SHA above before
  mutation.

## Owned additive surfaces

V03 may create only:

- `Native/CitySimNative/WorldArt/Blender/PLAY-027/industrial-l04-north-art-v12/blender-lowering-v01/static-b-confirmation-v03/`
  for its contract, launcher, focused tests, and prelaunch proof; and
- `docs/production/evidence/PLAY-027/industrial-l04/l04/blender-north-art-v12/blender-lowering-v01/static-b-confirmation-v03/`
  for the immutable one-child result and comparison evidence.

The importer, lowerer, scene, materials, accepted static-A, V01, V02, shared
contracts, Renderer, runtime, shipping, and sibling direction surfaces are
frozen.

## Exact-child terminal resource accounting

Keep the existing online process-group RSS sampling and immediate group
termination at the unchanged hard cap. Replace cadence-as-resource-proof with
terminal kernel accounting for the exact child:

1. Require `sys.platform == "darwin"` before interpreting terminal rusage.
   Any other or missing platform identity fails before the lease is consumed.
2. Start exactly one `subprocess.Popen` child with the same frozen command,
   environment, working directory, session, and output capture.
3. The observer loop must use `os.wait4(exact_pid, os.WNOHANG)` as the sole
   child-status/reaping authority. It must not call `Popen.poll`,
   `Popen.wait`, `Popen.communicate`, or another wait primitive before the
   terminal `wait4` result.
4. On termination, require the returned PID to equal the exact child PID,
   decode status with `os.waitstatus_to_exitcode`, assign `process.returncode`
   directly, and never wait or reap a second time.
5. macOS reports `ru_maxrss` in bytes. Normalize it to KiB using ceiling
   division:
   `terminalChildTreeMaxRSSKiB = (ru_maxrssBytes + 1023) // 1024`.
6. Define:
   `enforcedPeakRSSKiB = max(sampledAggregateGroupPeakRSSKiB, terminalChildTreeMaxRSSKiB)`.
7. Retain the unchanged hard limits:
   - terminal elapsed time `<= 120s`;
   - enforced peak RSS `<= 1,048,576 KiB`;
   - sampled process-group RSS above the cap terminates the group immediately.
8. Re-evaluate elapsed time and enforced peak RSS after the terminal
   `wait4` result, before output comparison or success.
9. Missing, zero, negative, malformed, unsupported, wrong-unit, wrong-PID, or
   multiply consumed terminal rusage fails closed.
10. The frozen Blender command is expected to remain one process with threads.
    At every sample, any additional PID in its process group is unexpected and
    fails the run. After reaping the exact child, perform a bounded process-
    group exhaustion check. Any remaining PID is recorded, terminated, and
    fails before output comparison.

The local macOS `wait(2)` contract states that `wait4` returns a resource
summary for the terminated process and all its children. The online group
sample remains the immediate concurrent-group guard; terminal rusage retains
the child-tree high-water mark hidden by an observer pause.

`ru_maxrss` is a maximum-RSS field, not proof of the maximum simultaneous sum
of every process-group member. Therefore V03 must record
`aggregatePeakCoverage: sampled_with_terminal_child_tree_high_water` and may
not claim exact aggregate process-group peak coverage. A short-lived,
unobserved extra member whose individual high-water remains under the cap is a
disclosed diagnostic limitation. V03 is still stronger than V02: it retains
online aggregate enforcement, rejects any observed or surviving extra member,
and adds kernel terminal child-tree high-water accounting without pretending
host observer cadence is product proof.

## Cadence telemetry

Keep the requested `0.01s` observer sleep and record:

- sample count;
- maximum observer gap;
- count of gaps above `0.05s`;
- total duration above `0.05s`; and
- whether the terminal kernel measurement remained available.

An observer gap above `0.05s` is warning telemetry, not by itself a resource or
product failure. The terminal resource result and hard limits remain
mandatory.

Record process truth exactly:

- `childStartCount: 1`;
- `staticBInvocationCount: 1`;
- `renderInvocationCount: 0`;
- no pixel or `.blend` files; and
- the exact terminal status, raw `ru_maxrss` bytes, normalized terminal KiB,
  sampled aggregate group peak KiB, enforced peak KiB, process-group
  exhaustion result, and aggregate-coverage classification.

## Required prelaunch adversaries

Before a DCC child may start, focused tests must prove:

1. an injected `150ms` observer gap with low terminal RSS records a cadence
   warning but passes the resource rule;
2. an injected high terminal child-tree RSS hidden inside that gap fails;
3. terminal elapsed time above `120s` fails even when the observer missed the
   deadline;
4. sampled process-group RSS above the cap terminates and fails;
5. missing, zero, negative, malformed, wrong-unit, wrong-PID, or twice-consumed
   terminal rusage fails;
6. nonzero or signaled child status fails;
7. a descendant surviving the direct child is terminated, recorded, and
   fails;
8. a sampled short-lived extra group member, second child, reused output root,
   or unexpected process fails;
9. Darwin/platform or terminal-unit drift fails before success;
10. frozen-input, command, output-inventory, five-file, or two-pointer drift
   fails;
11. render, pixel, `.blend`, or unexpected output fails; and
12. exactly one child plus `staticBInvocationCount: 1` is asserted.

The tests must use injected/fake child-status and rusage records. They may not
consume the real DCC lease.

## Comparison and lease

The V02 five-file byte-identity rule and exact two-pointer
`INPUT-BINDINGS.json` comparison remain binding. Comparison begins only after
terminal resource validation passes.

- Global DCC cap: one.
- Slot: `dcc-1`.
- Attempt: `industrial-l04-north-v12-static-b-confirmation-v03`.
- Process: `static-b`.
- Maximum child starts: one.

Commit the V03 contract, launcher, tests, and zero-DCC prelaunch proof before
starting the child. A child start consumes the lease. On failure, preserve only
the immutable partial child subset plus one exclusive `FAILURE.json`, commit,
and stop. On success, commit the exact comparison, process provenance,
resource evidence, validation, and handoff, then stop clean.

No retry, render invocation, pixel, `.blend`, normalization, Process A/B/C,
appearance lock, sibling DCC, source admission, Renderer quarantine, runtime
activation, shipping mutation, push, self-score, or self-acceptance is
authorized.
