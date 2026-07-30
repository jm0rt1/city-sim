# PLAY-073 Industrial L3 replacement-R2 technical handoff

## Disposition

`RENDERER_TECHNICAL_GATE_PASS_QA_PENDING`

The exact authorized accepted-L2-to-cohesive-replacement delta is restored on
published master without merging or cherry-picking its historical carrier.
The reconstructed product commit is
`8a30954a0d5c6664bff03a5551fea7acf8a440e1`; every one of its 13 authorized
path blobs equals the corresponding blob in frozen replacement reference
`25d291a7373833a797dc3bb3ba36658e18eccc06`.

The candidate-neutral directional fixture checkpoint is
`8c50496f07298b40adc1be213eb66af52aa62d46`. It imports only the
Integration-enumerated test and historical intake record. The QA-owned fixture
remains byte-identical at
`b8875422a277b59f6797aef03ca93175a502df5963a5c972684ca47be40e7aa5`.

This packet is technical Renderer evidence, not player-facing acceptance.
PLAY-075 owns the sole fresh same-SHA regular/compact interaction and visual
journey. Production selection, integration, acceptance, and push remain false.

## Exact authority

- Published recovery authority: `508619b5ef64ef21fb7a2a6a032b4f16f4e1a2f7`.
- Claim SHA-256:
  `12c901919261e18763eae50910b48b83d9c2243fb2095d223f1d38791557b380`.
- Recovery-authority SHA-256:
  `acf91f4e5d0e2f809fb63f84e9faf2deca40116fe8fe1229869d2a12bd910cac`.
- Accepted Industrial L2 reference:
  `d41c2c68d5584c990e271af06c0b93ab50722f5e`.
- Cohesive replacement reference:
  `25d291a7373833a797dc3bb3ba36658e18eccc06`.

## Product identity

| Artifact | SHA-256 |
|---|---|
| L3 catalog | `e9fa8eda7330385d478fbcac358bdce444e996ce6e4e7c373271426cba4cd136` |
| generated-v4 manifest | `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92` |
| block page 00 | `eb9231936bc9afb3cb43da5fc6ccddee7432455cd97c7adf7c0185da85e180db` |
| block page 01 | `a71d5eaa5fa2fad2dd923ae25499c03ff13fb79796005118a2ac11fc656985ee` |
| city page 00 | `99f350b1ec8366ad034e6ebeb486217f03788cc969acbe6caf7aef6b183389a0` |
| neighborhood page 00 | `ce6f7bee1a1810e6df3738e0bdc6bbaf1645ac72d2d77d3a3448dbfabdd9068f` |

Two fresh pack builds were byte-identical to one another and to those five
canonical shipping artifacts. The stable pre-existing payload projection,
excluding the four new L3 identities, has the same SHA-256 on accepted L2 and
this product:
`062be81d919887c82b760ba39c3b1842008b4d87a5d7509edb21a67b20860c21`.
This binds Industrial L1/L2 and unrelated catalog payloads against accidental
source, normalized-pixel, or packed-payload drift.

## Technical validation

- Source-binding unit suite: 4/4 passed.
- Candidate-neutral external directional fixture: 1/1 passed in 4.809 seconds.
- Focused `WorldRenderingTests`: 66/66 passed in 44.827 seconds.
- Complete Swift suite: 312 executed, 2 expected caller-input skips,
  0 failures, 216.306 seconds.
- Pack validator: 216 payload digests, 216 extrusions, 6,472 packed-overlap
  checks, 12 distinct Industrial sources, 36 distinct Industrial LOD hashes,
  zero failures.
- Production geometry: 11,236 reciprocal-ground checks, 212 road-setback
  checks, 820 entrance/prop-exclusion checks, zero collisions or failures.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: passed on exact technical checkpoint
  `8c50496f07298b40adc1be213eb66af52aa62d46`.
- Staged atlas parity: `staged_matches_source: true`, zero failures.
- Non-interactive smoke: exact PID `54831` remained alive for 35 seconds,
  loaded the exact resource pack, measured 320,144 KiB RSS, and was terminated
  by exact PID only. No player-facing interaction or scoring ran.

The complete reports and exact test/build logs are retained under `reports/`
and `logs/`.

## Performance and resources

- Cold world update: `4.199 ms` against the `6.03 ms` ceiling.
- Cold total render: `7.017 ms` (disclosed separately; no threshold changed).
- Unchanged-pulse soak: `4,286` pulses, `0.0006 ms` average against the
  `2.1 ms` target.
- Regular: `1,823` nodes / `890` drawables.
- Exact compact: `1,843` nodes / `904` drawables.
- Active-plus-adjacent decoded high water: `50,331,648` bytes.
- Repeated LOD-cycle decoded high water: `26,807,376` bytes.
- Exact smoke RSS: `320,144 KiB` (`312.640625 MiB`), below the
  `333.8 MiB` ceiling.
- Fallback count: `0`.

## Known limitation and next gate

Renderer intentionally did not perform default/compact player-facing
screenshots, pointer/keyboard/AX scoring, or visual acceptance. The exact clean
final evidence candidate must be restaged by PLAY-075 for one fresh same-SHA
journey covering all directions, all three LODs, regular and exact `900x600`,
hover/selection, construction/condition, demolition/Undo, Reduce Motion,
accessibility, and comparison with published Industrial L2.

The temporary generated-only pack validator receipt is retained because that
over-broad invocation correctly found the two intentionally absent legacy
rollback files. Canonical validation and byte comparison passed; no generated
pack was rebuilt or threshold loosened after that receipt.
