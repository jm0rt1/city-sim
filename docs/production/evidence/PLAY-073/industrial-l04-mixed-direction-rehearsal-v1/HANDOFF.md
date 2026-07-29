# PLAY-073 Industrial L4 mixed-direction rehearsal

## Disposition

`SYNTHETIC_QUARANTINE_TO_ATOMIC_ASSEMBLY_REHEARSED_NONSHIPPING`

This checkpoint rehearses the already-integrated direction-admission and
atomic-assembly harnesses without admitting Industrial L4 art. It uses only
synthetic file-backed packets, Integration admissions, Renderer quarantine
receipts, byte locators, and fixture identities beneath a temporary claimed
root.

The candidate is a descendant of exact clean Renderer base
`0f3a600abee6bb092dea2342b07252b4e2338a96`. No synchronization or merge was
performed for this slice.

## Transition proof

`testMixedDirectionRejectionsRemainIsolated` exercises every cyclic arrival
order:

1. North, East, South, West
2. East, South, West, North
3. South, West, North, East
4. West, North, East, South

Before each accepted arrival, a direction-local packet SHA mismatch is
introduced. All 16 bad inputs fail as `hashMismatch`. Each failure leaves the
already accepted packet, Integration-admission, and Renderer-receipt hashes
unchanged, leaves their sorted batch digest unchanged, and invokes no
assembler. Correct inputs transition from `inactive` through three
`quarantined_incomplete` states to `ready_for_atomic_assembly`.

`testFourthDirectionImmediatelyTriggersOneNonshippingAssembly` uses the mixed
East, South, West, North route. A bad North packet leaves the three accepted
siblings and their digest unchanged. The corrected North pair makes the join
ready and invokes the existing file-backed atomic assembler exactly once, at
arrival index 3.

The resulting synthetic ledger proves:

- four distinct fixture coordinates and four distinct authoritative
  frontages;
- 12 unique direction/LOD identities;
- 32 direction/D4 fingerprints;
- exact packet, admission, and quarantine-receipt hash propagation;
- synthetic-only byte locators; and
- runtime activation, runtime mapping mutation, shipping-resource mutation,
  ready-for-assembly receipt state, and production selection all remain
  false.

## Audit references only

These published/frozen preparation records informed the rehearsal shape but
were never opened as admission inputs:

- East:
  `docs/production/evidence/PLAY-079/industrial-l04-east-source-v01/RENDERER-LOCATOR-INVENTORY.json`
  (`c2b673414dfe31bf894e1b959335b4a9a41ec93a720922c64c88a48eb58ef3b8`)
- South:
  `docs/production/evidence/PLAY-080/industrial-l04-south-source-v01/RENDERER-LOCATOR-INVENTORY.json`
  (`b95b36fd7d08699ef48b7b73984530597ce132ff94f377729c53288a8e786213`)
- frozen West candidate `0bc3bda9527e8cf53174e96d369c0ae013168093`:
  `docs/production/evidence/PLAY-081/industrial-l04-west-source-v01/PRELOCK-LAUNCH-PLUMBING-VALIDATION.json`
  (`4d9c40e0b1560aa7d8a0169305e6ca0598d6bace58c6022bf37d305f3225f6b9`)
  and `WEST-ZERO-PIXEL-V2-HANDOFF.json`
  (`b6328cbf64781809df4264590924846ce8c2e0eff6ea6c868480e24e8e2a1f05`).

No actual source packet, admission receipt, quarantine receipt, fixture byte,
or pixel from those records participates in the rehearsal.

## Focused validation

```text
CLANG_MODULE_CACHE_PATH=/private/tmp/play073-mixed-intake-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/play073-mixed-intake-swiftpm \
swift test --package-path Native/CitySimNative \
  --filter IndustrialL4V2SourceAdmissionHarnessTests
```

Result: 16 executed, 14 passed, 2 expected caller-input skips, 0 failed in
0.163 seconds. The two new cases passed in 0.050 and 0.019 seconds.

The first post-edit invocation stopped at compile time because one new
receipt-hash assertion omitted `try`; no test executed. That mechanical error
and one unused mutable binding were corrected before the passing runs. A
subsequent unprivileged retry also stopped before compilation when SwiftPM's
nested manifest sandbox was denied. The identical command then ran with the
existing focused-test sandbox allowance and passed.

`jq` validation and `git diff --check` passed. No full suite or staged app was
run under the approved focused-only intake-ahead boundary.

## Authority boundary

This is rehearsal evidence only. It does not inspect or admit unfinished
pixels; create an actual admission or quarantine receipt; mutate a fixture;
write a shipping atlas or manifest; enable runtime lookup; select production
art; change Package.swift; stage the app; or publish shared authority.
