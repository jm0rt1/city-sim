# PLAY-073 Industrial L4 atomic assembly intake handoff

## Disposition

`ATOMIC_ASSEMBLY_INPUT_PREPARED_NONSHIPPING`

This checkpoint closes the removable test-tooling gap between four independent
Renderer quarantine receipts and a later Integration-authorized atomic
assembly. It does not admit a real direction, inspect source pixels, build an
atlas, activate runtime lookup, stage the app, or select production art.

## Ordered commits

1. Synchronization merge `043e495301febac7e6d8494d16e76bf1768874c2`
   preserves the Renderer history and contains published authority
   `8214ba39d88ec30a28597e65a10f1b0bc5e1759e`.
2. Proposal `b9240646` defines the requested Integration-owned
   `assembly-input-manifest-v1` boundary.
3. Harness `fd05ec462517d5c802f4918f65af4515ea7f3c09`
   adds the test-only file-backed assembler and command wrapper.

The accepted caller-path commits on published master,
`e177be62` and `02fd3434`, are ancestors of the candidate.

## Harness behavior

The assembler accepts one caller-supplied manifest path and SHA-256 beneath a
claimed repository root. It:

1. rejects unknown or missing manifest fields before decoding;
2. verifies the exact accepted-L3 baseline catalog/manifest byte bindings;
3. reopens all North/East/South/West packet/admission pairs through the
   existing v2 direction harness;
4. reopens each retained Renderer quarantine receipt, verifies its SHA-256,
   and compares it byte-semantically with the receipt regenerated from the
   bound pair;
5. verifies six direction-local byte locators: raw, provenance,
   normalization, descriptor, contact, and review;
6. rejects missing/extra directions and duplicate locator path/hash identity;
7. invokes the existing exact 4/4 join, which retains its focused fallback,
   registration, alias, transformed-sibling, 12-LOD, and 32-D4 rejection
   coverage; and
8. emits sorted-key deterministic `atomic-admission-ledger-v1` bytes with
   runtime, shipping, and production flags all false.

The synthetic file-backed replay passed twice with byte-identical ledgers.
The explicit caller-path test remains skipped until Integration publishes the
real manifest; this is intentional.

## Focused validation

The exact committed harness passed:

```text
CLANG_MODULE_CACHE_PATH=/private/tmp/play073-l4-assembly-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/play073-l4-assembly-swift-cache \
swift test --package-path Native/CitySimNative \
  --filter IndustrialL4V2SourceAdmissionHarnessTests
```

Result: 8 executed, 6 passed, 2 expected caller-input skips, 0 failed in
0.057 seconds. `bash -n` and `git diff --check` passed. The first ungoverned
Swift invocation failed before compilation because the outer sandbox blocked
the default user module cache; the exact private-tmp rerun passed.

No full suite or staged app was run under the tiered intake rule.

## Integration decision required

Integration must approve and publish the shared
`assembly-input-manifest-v1` authority, including:

- the canonical schema/document path and hash;
- the exact accepted L3 baseline commit, catalog, and Industrial L3 manifest
  hashes;
- the four exact packet/admission/quarantine-receipt path/hash triples;
- the six byte locators for each direction; and
- the candidate-only resource path allowed to consume the non-shipping ledger.

Until then, the new wrapper is synthetic/future-facing only and no actual 4/4
family can be assembled or activated.
