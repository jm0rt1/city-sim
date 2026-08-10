# PLAY-073 R6 Current-Master Claim

- **Title:** Keep the developed focus inside the honest camera aperture
- **Lane:** World rendering
- **Task/thread:** `019fec7c-28ee-7691-80fd-6ee62f33212c`
- **Branch:** `codex/citysim-world-rendering-r6-current302`
- **Worktree:** `/Users/James/.codex/worktrees/abfe/city-sim`
- **Base authority:** exact Integration master
  `302f6f84f4fbcec76db407ccd0b3abfe904c7eea`; the worker may receive no
  product authority until it is attached, clean, fast-forwarded to this
  governance checkpoint, and bound by a fresh validated schema-2 route.
- **Worker tuple:** `LUNA_IMPLEMENTATION / gpt-5.6-luna / high`.
- **Independent acceptance owner:** CitySim CTO task
  `019fe8df-faf7-7b50-a8a3-0d15b1191e10`, `gpt-5.6-sol / high`.
- **Integration owner:** task `019f7686-4491-7891-86a6-95a78d67e5c8` owns
  claim/route/dispatch publication, checkpoint adoption, aggregate/full native
  proof, and staged build. Distinct Playability/QA owns later real-app review.

## Exact ownership

The only product/test paths this successor may change are:

1. `Native/CitySimNative/Sources/CitySimNative/Rendering/CityScene.swift`
2. `Native/CitySimNative/Tests/CitySimNativeTests/WorldRenderingTests.swift`
3. `docs/production/evidence/PLAY-073/game-009-r6-focus-translation/`

Every fixture, asset, selector, simulation state, UI/store/input surface,
package/build file, claim, shared contract, and other evidence path is
forbidden. The exhausted `/ccd1` task and its dirty files are immutable inputs,
not bytes to copy, reset, clean, commit, or reuse as a worker baseline.

## Preserved failed lineage

Historical Renderer task `019fec2c-5a6f-7d73-a988-7a42a1520d03`, worktree
`/Users/James/.codex/worktrees/ccd1/city-sim`, branch
`codex/citysim-world-rendering-g010-current7a`, and HEAD
`600765ba2c896aae920a623501619f997eafacbf` remain evidence-only.

- held `CityScene.swift` SHA-256:
  `044b2901e9baa176abdbc2c951c5f86289ca1c1fbd1aa106c16ddc0b2404d68a`
- held `WorldRenderingTests.swift` SHA-256:
  `9b9415cb20a866be07f6a3f79347dc05db18afc2e24aca4be786b57538932f2d`
- held binary diff SHA-256:
  `8ff08b6a3377efce30c72bc277400f9fbe86af3c20249fba03e7c5986fc8def5`
- corrected three-invocation ledger:
  `/private/tmp/GAME-009-R4A-THREE-INVOCATION-LEDGER.json`, SHA-256
  `321b6a8916ff9eba0e3cf3cacab146bbe60e0e512de8f80a5599ea592d149647`

The two substantive failed repair attempts are exhausted. R6 is a distinct
fresh-owner implementation from current master, not a third repair or reuse of
that dirty diff.

## Immutable current-master inputs

- `CityScene.swift` SHA-256:
  `8d246d7f1b633d2c0c69261847afc5acc905eca2ffde2da750643d8ac5677c6c`
- `WorldRenderingTests.swift` SHA-256:
  `2ffa820835e5d2e97289e8606767ddf420e28cc14e87d2082436e669767774b6`
- fixture support SHA-256:
  `99e88fc27325462d843e33c26e8693356b3a4037edc88e7baa7f50d8cf65b56e`
- Commercial upgraded-v3 SHA-256:
  `b5b3ac416143405720f45e15831bd03735e671d2e48fde5fc7ee2dc8ce379940`
- Industrial upgraded-v3 SHA-256:
  `d6e60c425fb240c196655516c236eda1ee5cf7d17ad19b11b2b1149492715826`
- visible-state manifest-v3 SHA-256:
  `9eed6405adc84b8bdf025bb2ac1365b327c8659bdbf0384bc6f172d6c9a2aace`
- generated-v4 manifest SHA-256:
  `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92`
- block/neighborhood/city page SHA-256 values:
  `eb9231936bc9afb3cb43da5fc6ccddee7432455cd97c7adf7c0185da85e180db`,
  `ce6f7bee1a1810e6df3738e0bdc6bbaf1645ac72d2d77d3a3448dbfabdd9068f`,
  `99f350b1ec8366ad034e6ebeb486217f03788cc969acbe6caf7aef6b183389a0`.

Fixture identity must distinguish manifest scenario seed `42` from decoded
state RNG seed `10481999410520546993`. Both states bind tick `844`, 16 occupied
lots, focus `(4,8)`, and occupancy `89`; Commercial is `commercial/2`, and
Industrial is `industrial/3`.

## Frozen implementation contract

Implement only a deterministic focus translation after the existing
developed-core camera composition. Do not correct zoom. For each exact fixture
at regular `1229x768` and compact `1058x705`:

1. Focus ground bounds are `F=(-180,-234,72,36)`.
2. Preserve final scale exactly: regular `0.7352181673049927`, compact
   `0.6549999713897705`, tolerance `1e-6`, identical across fixtures and
   deterministic repeats.
3. Let `m=12*s` scene units, where 12 is the screen-point margin. Let `S0` be
   the existing developed-core safe viewport and `A=S0.insetBy(dx:m,dy:m)`.
   Stop if `A` cannot contain `F`. Otherwise calculate the minimal axis-only
   translation from the existing position `p0`:

   - `dx = F.minX < A.minX ? F.minX-A.minX : F.maxX > A.maxX ? F.maxX-A.maxX : 0`
   - `dy = F.minY < A.minY ? F.minY-A.minY : F.maxY > A.maxY ? F.maxY-A.maxY : 0`
   - `p1 = p0 + (dx,dy)`

   Final position must equal `p1` within `1e-6`. Only focus `(4,8)` controls
   translation; opposite-edge priority bounds may clip.
4. Final `safeViewportRect(insets).insetBy(dx:m,dy:m)` fully contains `F`.
5. Composition metrics remain exact within `1e-6` and occupied width remains
   at least `0.60`. Only this typed table is authoritative:

| Fixture / viewport | occupied `(x,y)` | priority `(x,y)` | network `(x,y)` |
|---|---|---|---|
| Commercial regular | `(0.6633708074041823,0.9341241107568152)` | `(0.7877528337924664,0.9827005569091181)` | `(0.7877528337924664,0.9229524768937528)` |
| Commercial compact | `(0.8621464229299972,1.5965483432544931)` | `(1.0237988772293718,1.67957226238106)` | `(1.0237988772293718,1.5774544634047722)` |
| Industrial regular | `(0.6633708074041823,0.92046198527648)` | `(0.7877528337924664,0.9690384314287829)` | `(0.7877528337924664,0.9229524768937528)` |
| Industrial compact | `(0.8621464229299972,1.5731978660001462)` | `(1.0237988772293718,1.6562217851267131)` | `(1.0237988772293718,1.5774544634047722)` |

   No alternate shorthand is authoritative or permitted in the route or tests.
6. Preserve LOD exactly: regular `city`, compact `neighborhood`; fallback count
   `0`; diagnostics empty; generated-v4 hashes above unchanged.
7. Focus root remains attached; inverse scene hit resolves exactly `(4,8)`;
   `configureProofInteraction` exposes hover and non-color feedback; inverse hit
   remains `(4,8)`; camera position/scale, state fingerprint, and tile bytes do
   not move during interaction; `activeActionCount=0`.
8. Translation-only node/drawable counts remain exact: Commercial regular
   `2277/1205`, compact `2296/1219`; Industrial regular `2304/1228`, compact
   `2323/1242`; hard ceilings are `4000/1500`.

No zoom, fixture, asset, resource-selection, occupancy, selection, LOD,
threshold, simulation tile/state, source-admission, shared-contract, or
renderer-gate change is authorized.

## Proof, durability, and acceptance

The fresh schema-2 route must freeze one exact focused command for the named
WorldRendering test and task-specific writable cache/scratch roots. Worker
focused PASS may produce only the two allowed file changes, the new task-owned
evidence root, and one coherent `PLAY-073:` checkpoint commit. Any failure
stops without retry, substitute command, evidence, staging, or commit.

Worker proof is not acceptance. CTO Sol/high independently reviews exact scope,
semantics, and focused evidence. Integration alone may later adopt the exact
candidate and run aggregate/full native proof plus staged build. A distinct
Playability/QA task later owns regular/compact block/neighborhood/city real-app
review. No source-admission, Renderer/runtime, production, release, merge,
push, or gate movement follows from this claim.

## R6C host-permission exception

R6B consumed its sole authorized command and exited `1` during SwiftPM manifest compilation, before package or test execution, with `0` tests because `sandbox-exec` returned `sandbox_apply: Operation not permitted`. This is environmental evidence only and provides no Renderer or product judgment.

R6C may begin only from HEAD `f95706c0246bf878934f3901e712d5ecaf3572bf`, empty index, no evidence/untracked bytes, and exactly:
- binary diff `17f349cbfcba2ee66702b89eb116e04cf9c3f2fc0f6838fa2a2990457ce9a0d3`
- `CityScene.swift` `3b953c311eb39b7a2dd9c52267d853de3b4eb917846195fcbb6141bc59eabeb3`
- `WorldRenderingTests.swift` `fa741d38566d67b6e79b245930197a6449c0059a07f313b21147e9ce0c9a74cf`

For this exact retained state only, the generic dirty-successor stop and R6B no-retry clause are superseded solely to permit one distinct R6C host-permission proof. R6C is `LUNA_LOCAL_DEBUG / gpt-5.6-luna / max`. It permits no further source or test edits.

Run the R6B command byte-for-byte exactly once under only the narrow host permission required for SwiftPM sandbox/module-cache execution. Any mismatch or nonzero result stops with no retry, substitution, evidence, staging, commit, cleanup, or further permission attempt.

PASS alone permits creation of `docs/production/evidence/PLAY-073/game-009-r6-focus-translation`, staging exactly that root plus the two held files, and one `PLAY-073:` checkpoint commit.

Every R6 oracle remains unchanged. CTO owns independent focused disposition; Integration owns adoption and aggregate/full/staged proof; distinct Playability/QA owns real-app review. No Renderer/runtime, source-admission, production, release, merge, push, or other gate opens.

## Stop and refill

Stop on any task/branch/worktree/HEAD/claim/hash mismatch; detached or dirty
successor; inability to meet the 12-point focus margin without changing scale;
metric, occupancy, LOD, fallback, diagnostic, hit-test, interaction, state,
node, drawable, fixture, resource, or threshold drift; path expansion;
shared-contract need; fixture/asset/source-admission mutation; self-acceptance;
or downstream gate request. Rollback is abandonment of only the fresh R6
candidate. Preserve `/ccd1`, master protected dirt, DESKTOP-005, South `0/43`,
Commercial terminal/no-retry, and every downstream gate.

Refill returns first to Integration for identity/route correction or to CTO for
semantic conflict; it never silently changes the frozen oracle.
