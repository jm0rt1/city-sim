# PLAY-051 — PLAY-022 Round 1 Independent Gate

**Status:** frozen preparation; no Round 1 candidate supplied or tested

**Preparation authority:** synchronized quality baseline `313a16b`

**Rejected comparison only:** product `4887ebad9519fccb08844e2746f9bfbbc93aaa4d`, evidence `8cb45b5848f070c25803213ee48b2523e8057d09`

This is the quality-owned admission and execution gate for PLAY-022 Round 1. It supplements the frozen whole-wave PLAY-051 rubric without relaxing it. It does not authorize renderer implementation, accept source art, or substitute tests and harness frames for the real staged application.

## Candidate admission

Integration must supply one exact clean Round 1 product commit and candidate identity. Quality does not infer or substitute either from a worker branch. Before any scoring or app interaction, retain:

- product and evidence commits, branch, accepted-base ancestry, ordered renderer commits, and clean status;
- candidate ID, bundle and preference identifiers, staged bundle, executable and `Info.plist` hashes, exact PID/command, launch time, isolated data root, save path/hash/fingerprint, seed, tick/day, and production-selected asset pack;
- `world_asset_pack_id`, manifest schema/digest, packaged-resource digest, complete page/source inventory, explicit fallback count, decoded-byte inventory, and rollback selection;
- window content and decorated sizes, display ID/scale, unobstructed world rectangle, viewport insets, camera center/scale/detail stop, accessibility settings, and Reduce Motion state for every capture;
- a same-save, same-seed, same-camera baseline/candidate A/B where the authorized rollback switch permits it. The rejected `8cb45b5` build is comparison evidence only and may never be operated or scored as the candidate.

Reject admission for an ambiguous identity, dirty or changing candidate, production save/default access, missing packaged-manifest identity, silent fallback, or evidence from a substitute branch, renderer harness, cropped window, or old candidate.

## Required Round 1 packet

The exact staged app must retain uncropped default and exact 900 x 600 proof for city, neighborhood, and block stops in normal, selected, valid preview, invalid preview, every visible construction stage, representative overlay, and Reduce Motion states. Color captures require grayscale derivatives with distinct hashes. Also require:

- a deterministic opaque-bounds/collision report and road/terrain seam mosaic tied to the exact manifest;
- a real continuous pan/zoom recording of at least 20 seconds with start/end camera telemetry;
- separate uncoached pointer and keyboard journeys through opportunity discovery, valid/invalid classification, commit, visible construction, and exact undo;
- an AX/focus transcript distinguishing selection, hover, and pending placement and announcing coordinate, kind, construction stage, condition, and active consequence truth;
- focused renderer tests, full native suite, staged verification, isolation, hit testing, save/load, undo, Reduce Motion, manifest validation, and `git diff --check`;
- changed/unchanged renderer timing, node/draw/action stability, active pages and named decoded bytes, settled regular and compact RSS/physical footprint, and repeated city↔neighborhood↔block high-water.

## WR-001…WR-028 executable matrix

`AR` means the observed condition rejects Round 1 immediately and cannot be averaged away by the score.

| ID | Independent real-app check | Retained proof | Pass / automatic-reject boundary |
| --- | --- | --- | --- |
| WR-001 | At each LOD, pan the exact corridor across every neighboring building, road, entrance, shadow, and parcel edge; reconcile the visible result with the exact-manifest geometry report. | Collision report, manifest excerpt, three-LOD stills, recording timestamps. | Pass only with complete footprint/pivot/opaque/shadow records and no visible contract violation. **AR:** missing geometry identity, any unintended opaque intrusion, or LOD contact jump over 0.5 world point. |
| WR-002 | Inspect the full focal corridor at default and compact, then select each adjoining lot while panning through block detail. | Uncropped normal/selected stills and collision mosaic. | **AR:** any building/building, building/road, entrance, or separate-lot overlap that reads unintended. |
| WR-003 | Traverse the entire visible opening, one construction, and undo at all LODs; compare every visible terrain, road, lot, construction, vegetation, prop, and service path. | Visible-set inventory, pack/fallback log, color and grayscale contact sheet. | **AR:** mixed generated/legacy/procedural art language or any silent fallback in the accepted journey. |
| WR-004 | Pan quiet and developed acreage at city/neighborhood/block, including road edges, in color and grayscale. | Seam mosaic and continuous recording. | **AR:** repeated oversized terrain plates, visible tile diamonds/seams, or terrain covering roads/lots. |
| WR-005 | Pan across foreground/background crossings and select objects on both sides while cycling LOD twice. | Recording plus depth/contact report. | **AR:** wrong occlusion, cross-tile pop, road/entrance hidden by depth, or unstable ordering. |
| WR-006 | Measure developed content plus truthful expansion corridor against the unobstructed world rectangle at default and compact for all three stops. | Window/inset/camera telemetry and annotated occupancy stills. | Pass at 55–70% developed/opportunity occupancy with useful framing. **AR:** mostly empty city/default frame or over-crowded core that hides choices. |
| WR-007 | Repeat selection and valid/invalid previews with normal chrome, Details, objectives, and overlay legend at default and compact. | Full-window stills and active-coordinate telemetry. | **AR:** HUD/chrome hides the active parcel, preview, construction, or necessary world context; compact map ceases to dominate. |
| WR-008 | Exercise hover→selection→valid→invalid→overlay transitions and deliberately attempt the previously stacked state. | Ordered state captures and recording. | Pass with at most one primary world affordance and one secondary confirmation while the parcel remains readable. **AR:** stacked cues obscure the target or duplicate a primary message. |
| WR-009 | Compare normal and localized authoritative consequence presentation at the same coordinate; inspect with overlay on and off. | Truth-matched color/grayscale pairs and HUD/AX cross-check. | Round 1 must at least preserve the place and keep glyphs secondary; full embodied trouble/recovery closure is subject to the Round 1/Round 2 authority question below. **AR:** annotation is the primary readable signal or contradicts accepted truth. |
| WR-010 | Measure settled launch, post-interaction, and post-ten-cycle LOD high-water separately at regular and compact. | Timestamped `ps` RSS, physical-footprint samples, named residency log, cycle table. | **AR:** either window exceeds its approved baseline +128 MiB, active decoded bytes exceed 128 MiB, residency grows after warm cycling, or the required metric is missing. |
| WR-011 | Follow every road mask, intersection, frontage join, and visible terminus in the corridor through continuous pan/zoom. | Road seam mosaic and recording timestamps. | **AR:** unexplained end, seam, overlap, pasted strip, broken curb/sidewalk/crossing, or false opportunity cue. |
| WR-012 | Select every visible building and verify entrance/frontage orientation against its adjacent supported street at neighborhood/block. | Selected-lot contact sheet and AX coordinate/kind transcript. | Fail for any building that visually faces away, floats, or disagrees with its declared road relationship; **AR** when it misleads placement/opportunity. |
| WR-013 | Commit one real project and observe prepared, foundation/frame, finishing, and complete stages without source/fixture mutation. | Timestamped staged-app sequence, save/load/undo identity. | **AR:** conspicuous placeholder/mixed-fidelity construction, footprint/road obstruction, false progress, or stage drift across save/load/undo. |
| WR-014 | Compare door, floor, road, curb, tree, vehicle, one-tile building, and landmark scale at neighborhood/block. | Scale-sheet validation plus uncropped contact sheet. | **AR:** obvious inconsistent projection/light/scale or landmark exception that destroys parcel/road coherence. |
| WR-015 | Inspect architecture edges, baked landscaping/shadows, renderer vegetation, frontage, and props at block scale. | Layer-role manifest excerpt and close live frames. | Fail for double ground, shadow, planting, or props; **AR** where double-counting causes overlap or mixed art language. |
| WR-016 | View empty and developed terrain at city scale in color and grayscale, then zoom continuously to block. | Grayscale contact sheet and recording. | **AR:** tile grid or ground texture dominates city hierarchy, hides opportunity, or produces a placemat boundary. |
| WR-017 | Stop at city, neighborhood, and block, state aloud the new useful information at each, then traverse continuously twice. | Three distinct still hashes, camera telemetry, recording, transition log. | **AR:** LOD only changes resolution, contact point jumps, required information disappears, or no continuous recording exists. |
| WR-018 | Hover open land and buildings, then select, enter build, use keyboard navigation, and trigger feedback. | State-order recording and tooltip bounds. | **AR:** hover billboard obscures the target/city, persists into a higher-priority state, or covers the active coordinate. |
| WR-019 | Trigger the same invalid placement once by pointer and once by keyboard. | Full-window captures, AX transcript, feedback inventory. | **AR:** the same reason is presented in more than one prose surface, conflicts across surfaces, or is silent/inaccessible. |
| WR-020 | Select at least five distinct parcels at normal and representative overlay states. | Color/grayscale selection contact sheet. | **AR:** selection uses an obscuring cue stack, hides the selected building/lot, or lacks a grounded non-color boundary. |
| WR-021 | Inspect City, Utilities, Pollution, Happiness, and Traffic overlays at all useful LODs, including affected and unaffected land. | Full-window color/grayscale frames and glyph-area measurement. | **AR:** overlay erases local roads/material/buildings, patterns unrelated land, obscures interaction, or persistent glyphs exceed 3% of world viewport. |
| WR-022 | From a fresh uncoached launch, time identification of one opportunity; then classify five candidate sites without Details. | Monotonic ledger, five trial captures, authoritative outcomes. | Pass when one useful opportunity is found within 5 seconds and at least 4/5 valid/blocked classifications agree with store authority. **AR:** false buildability cue, hidden-coordinate coaching, or failure of either threshold. |
| WR-023 | Maintain distinct keyboard selection, pointer hover, and pending placement targets while reading visual and AX state. | Per-state coordinate/role transcript and screenshots. | **AR:** stale or contradictory coordinate/role, visually indistinguishable targets, or accessibility names the wrong authority. |
| WR-024 | Pan the accepted corridor at neighborhood/block and compare vegetation clusters across coordinates and LODs. | Vegetation contact sheet and identity samples. | Fail for conspicuous repeated lollipop forms or a visible fidelity break; **AR** when mixed art language remains in the accepted journey. |
| WR-025 | Observe neighborhood/block activity, then repeat with Reduce Motion from the same state. | Short normal/Reduce Motion recording and static-equivalence stills. | Fail if the city remains visibly uninhabited. **AR:** gameplay meaning exists only in motion, actions accumulate, or Reduce Motion removes necessary state. |
| WR-026 | Trace lamps, street furniture, parked service object, and small props along curb/frontage geometry while panning. | Prop/socket contact sheet and block recording. | Fail for detached/floating/misoriented props; **AR** where they obscure roads, parcels, or interaction. |
| WR-027 | Compare identical default/compact states in color, grayscale, and declared common color-vision simulations. | Hashed contact sheets with source capture mapping. | Fail for inconsistent world/interaction/warning hierarchy; **AR** when critical state is color-only or mixed grading makes the place unreadable. |
| WR-028 | Repeatedly cycle every LOD and exercised state, then reconcile all resident pages/textures with the production-selected manifest and rollback pack. | Named residency inventory at launch, each cycle, and settled high-water; fallback/orphan report. | **AR:** orphan/superseded resource remains resident without authority, silent fallback, over-four active pages, decoded-byte/RSS budget breach, or monotonic residency growth. |

## Round 1 scoring

After every admission and automatic-reject check passes, quality scores the exact staged candidate 0–4 for:

1. composition and hierarchy;
2. projection and physical coherence;
3. material, light, and depth;
4. density, variety, and life;
5. state and interaction clarity.

Acceptance requires at least 17/20, no category below 3, and an explanation for every lost point. An automatic reject ends scoring for disposition even when a diagnostic score is still recorded.

## Execution order after integration supplies the candidate

1. Freeze identity, ancestry, manifest, hashes, exact process, isolated root, save, viewport, camera, display, and baseline budgets.
2. Reconcile automated geometry/manifest/fallback/performance evidence, run the full native/static/staged/isolation gate, and reject before live interaction on identity or budget failure.
3. Run the fresh default pointer corridor: five-second opportunity discovery, five-site classification, valid/invalid preview, commit, construction stages, selection, overlay, save/load, and exact undo.
4. Run the fresh exact-900 x 600 keyboard corridor without pointer rescue, then the FKA/VoiceOver focus and accessibility checks authorized by the integrated input candidate.
5. Capture city/neighborhood/block normal and interaction matrices, continuous pan/zoom, color/grayscale/color-vision derivatives, and Reduce Motion equivalence.
6. Run repeated LOD/state cycling and settle memory/residency; verify other candidate processes remain untouched.
7. Classify WR-001…WR-028, automatic rejects, five score categories, limitations, and exact evidence paths. Quality does not repair or coach a rerun.

## Missing proof mechanisms and integration questions

The gate is ready, but the following must be resolved or supplied before candidate operation:

1. **Memory authority:** publish exact accepted regular and compact baseline values separately for RSS and physical footprint, the sampling command/tool, settle duration, sample statistic, and whether `baseline +128 MiB` applies independently to both metrics. The current authority names an approximate 205.8 MiB baseline but not a complete two-window measurement contract.
2. **Round boundary for WR-009:** the production recovery plan defers embodied consequence/recovery to Round 2, while the older world-playability directive requires it in Gate A-P. Confirm whether Round 1 closes WR-009 or only proves interaction restraint and truth preservation before Round 2.
3. **Keyboard spatial authority:** identify the exact accepted PLAY-032/input commit that makes the no-pointer Round 1 placement journey legal and testable. Quality will not invent spatial keyboard routing or accept pointer rescue.
4. **Style anchor:** identify the exact accepted source/hash that governs Round 1 projection/material/light. CONTRACT-006 calls the Gate A source provisional, and the later Gate A candidate was independently rejected as staged geometry.
5. **Occupancy telemetry:** require candidate output for unobstructed world rectangle, developed/opportunity bounds, and computed occupancy percentage at each window/LOD so screenshot scoring can independently cross-check the 55–70% claim.
6. **Overlap and residency formats:** the candidate must supply machine-readable collision and named-residency reports tied to manifest digest and camera/LOD. No repository-wide quality parser currently exists; screenshots alone cannot prove invisible alpha collisions, decoded bytes, fallback count, or eviction.
7. **Live capture mechanism:** require a reliable, exact-bundle 20-second recording path and responsive Computer Use/AX capture. Harness frames, start/end stills, or source-derived coordinates cannot substitute if live tooling blocks.

Until integration supplies the exact Round 1 candidate and these identities/authorities, PLAY-051 remains prepared and waiting. No product acceptance is implied.
