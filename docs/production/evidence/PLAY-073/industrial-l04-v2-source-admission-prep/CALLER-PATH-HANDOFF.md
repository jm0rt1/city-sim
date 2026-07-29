# PLAY-073 Industrial L4 caller-path quarantine handoff

## Disposition

`CALLER_PATH_PREPARED_NONSHIPPING`

Published authority `af6b661b79e0802386123537aaeddce5c9d385f2`
integrates the self-contained v2 harness. Synchronization merge
`2639ba33d5ba9f2c2e36ce080295b51d631d29a0` preserves the earlier Renderer
history without rewriting it.

Checkpoint `a66b245b6b822e3b03a17fd96a1e7ab3f6960c0e` adds only a task-owned caller-path test entrypoint,
per-direction command wrapper, and synthetic packet/admission/receipt fixtures.
It does not inspect or admit unaccepted source pixels.

## Exact command

```text
docs/production/evidence/PLAY-073/industrial-l04-v2-source-admission-prep/tools/quarantine_direction_packet.sh \
  --repo-root <clean-renderer-worktree> \
  --direction north|east|south|west \
  --packet <repo-relative-worker-packet.json> \
  --packet-sha256 <64-lowercase-hex> \
  --admission <repo-relative-integration-admission.json> \
  --admission-sha256 <64-lowercase-hex> \
  --receipt-output <repo-relative-PLAY-073-evidence-path.json>
```

The wrapper invokes only:

```text
swift test --package-path Native/CitySimNative --filter IndustrialL4V2SourceAdmissionHarnessTests/testCallerSuppliedDirectionPacketAndAdmissionReceipt
```

Packet and admission inputs must resolve beneath the caller-supplied repository
root. The Integration receipt must bind the packet by its repository-relative
path and exact SHA-256. Output is restricted beneath
`docs/production/evidence/PLAY-073/`.

## Receipt boundary

A passing command emits one deterministic receipt with:

- `rendererQuarantined=true`;
- `readyForAtomicAssembly=false`;
- `productionSelected=false`;
- `runtimeMappingMutated=false`; and
- `shippingResourcesMutated=false`.

The command does not join directions, modify an atlas or manifest, expose a
runtime identity, materialize a save, stage the app, or authorize production.
Exact 4/4 assembly remains a later serialized Renderer operation after four
separate Integration-admitted packets pass.

## Synthetic proof

The retained North fixture uses conspicuous non-authoritative hashes. It proves
receipt consumption and deterministic command behavior only:

- packet:
  `284b1c960cbd6635c1b0956e8beb619720f73a57ae770e8aad7d4b073df61b68`;
- Integration admission:
  `9f5b715abe865f4646202e92337f9c2b070a52bbf9261e20cff4f9f62748e553`;
- Renderer quarantine receipt:
  `3bc7636f98afed07cc8b0b5f5fc0302d032be107acbb6e69af950459789173d4`.

Two wrapper runs produced the exact same receipt bytes.

## Validation

- Focused harness: 5 executed, 4 passed, 1 caller-path test skipped, 0 failed.
- Explicit caller path run A: 1 passed, 0 failed.
- Explicit caller path run B: 1 passed, 0 failed.
- `bash -n`: passed.
- Fixture JSON parsing: passed.
- `git diff --check`: passed.

No full suite or staged app was run. No actual packet or Integration admission
was consumed. No World Art source, product, package, runtime, shipping
resource, atlas, manifest, or accepted fixture byte changed.
