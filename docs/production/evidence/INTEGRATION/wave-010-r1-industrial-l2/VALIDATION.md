# Wave 010 R1 Industrial L2 integration validation

## Accepted identities

- Pre-integration published master:
  `10c2ed8cacc6c14a748aa953365b5779c7e06ad5`
- Accepted World Art source candidate:
  `e2a6144448707c67792e6e0619d5e8dee1ba10bb`
- Accepted renderer product and proof candidate:
  `d41c2c68d5584c990e271af06c0b93ab50722f5e`
- Independent PLAY-075 focused approval:
  `74f2164da506a246af9335cab2d3a9e977624097`
- Integrated product plus independent evidence:
  `eb61182ec03114ee62d98ffdfa78a7a69a16d3fe`

Master was a verified ancestor of the renderer candidate and fast-forwarded
without conflict. The independent evidence commit was cherry-picked without
importing historical quality-branch product state. Its diff is evidence-only
across `docs/production/evidence/PLAY-075/`.

## Automated integration gate

- `swift test --package-path Native/CitySimNative`: 271 passed, 0 failed in
  223.720 seconds.
- `WorldRenderingTests`: 66 passed, 0 failed in 47.027 seconds.
- `git diff --check 10c2ed8..eb61182`: passed.
- `bash -n script/build_and_run.sh`: passed.
- `./script/build_and_run.sh --verify`: built, staged, and launched exact
  `eb61182ec03114ee62d98ffdfa78a7a69a16d3fe`.
- Staged bundle: `dist/CitySim.app`.
- Staged executable: `dist/CitySim.app/Contents/MacOS/CitySimNative`.
- Staged resource bundle:
  `dist/CitySim.app/CitySimNative_CitySimNative.bundle`.
- Staging manifest: `dist/manifests/master.manifest`.
- Exact integration PID `27373` was terminated with `SIGTERM`; a subsequent
  process check found no matching integration executable.

The accepted renderer packet additionally proves four Industrial L2
directions across three LODs, zero alias/mirror/rotation/recolor/fallback,
source-to-staged pack parity, zero geometry collisions, 5,727 packed-overlap
checks, 4.561 ms cold world update, 0.0007 ms unchanged pulse,
50,331,648-byte residency high-water, and bounded live RSS.

## Integrated staged-app operation

The exact integrated bundle launched into the existing production-default
session. Integration:

1. used the Right arrow with map focus to select City Hall at block 12,12;
2. directly clicked the visible City Hall and confirmed the same selected
   block and command-center identity;
3. confirmed AX exposed type, level, operational condition, road connection,
   utility/pollution cause, vitality consequence, and an honest response;
4. used Escape to close the command-center details;
5. used Space to pause; and
6. terminated only exact PID `27373`.

No Save command was invoked. The independent PLAY-075 packet remains the
binding Industrial L2 journey: it covers the exact changed family at regular
and 900 x 600 sizes, N/E/S/W and three LODs, pointer/keyboard identity,
construction, weathering, demolition/byte-exact Undo, Reduce Motion, AX,
pack identity, and visible comparison to exact pre-R1 `10c2ed8`.

## Disposition and remaining risk

R1 Industrial L2 is accepted for publication. This is a focused art-batch
approval, not the final Wave 009 20/20 release acceptance.

The integrated opening is still not the requested final production standard:
its world remains visibly mixed in fidelity and materially sparse outside the
developed road loop. Industrial L3/L4 breadth, shared material/light/outline
cohesion, public-realm richness, repetition control, and the full PLAY-073 /
PLAY-075 city-not-board closeout remain required.
