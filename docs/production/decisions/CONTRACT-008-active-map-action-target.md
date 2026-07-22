# CONTRACT-008: One active map-action target

**Status:** Approved for ordered implementation

**Date:** July 21, 2026

**Proposer:** PLAY-022 after the PLAY-051 placement-truth reproduction

**Evidence:** `docs/production/evidence/PLAY-051/NEXT_WAVE_HUD_AUDIT_2026-07-21.md` and the PLAY-022 Round 1 placement-target proposal

## Player outcome

Before a build or demolition commits, the grounded world preview, accessibility value/action, pointer click, and Return key describe and act on one coordinate with one authoritative availability and disabled reason.

## Current failure

SpriteKit hover/click and store-owned keyboard/accessibility paths already call the same `CitySimulation.validateBuild` rules, but they can ask about different coordinates. Pointer motion updates `CityScene.hoveredCoordinate`; keyboard navigation updates `CityGameStore.selectedCoordinate`. A stale hover can therefore display `VALID` while AX/Return correctly reject another tile, or display `BLOCKED` while Return successfully acts elsewhere.

This is a player-intent contract failure. Changing color, copy, or validation independently in the renderer is rejected.

## Approved contract

1. `CityGameStore` owns the sole active map-action coordinate for build and bulldoze modes. The existing selected coordinate may fulfill this role; no second persisted target is authorized.
2. Crossing into a new tile while build or bulldoze mode is active publishes that pointer candidate through one narrow scene callback. The store accepts it as the active target through its governed intent path.
3. Keyboard spatial navigation changes the same active target. Subsequent rendering ignores stale hover coordinates for action validity.
4. The store produces one `CityMapPrimaryActionPresentation` for the active target. SpriteKit consumes that coordinate and presentation for the grounded preview instead of revalidating a separately chosen coordinate.
5. Pointer click and Return dispatch the same store command/target path. The action mutates state iff the shared presentation is available.
6. Inspect-mode hover remains non-selecting and renderer-local. This decision does not turn all pointer movement into selection.
7. Modal/text-input quarantine, focus-generation rules, HUD-safe reveal, cancellation, and onboarding behavior remain authoritative and must not be bypassed by the candidate callback.

## Ownership and adoption order

1. Integration publishes CONTRACT-008 and PLAY-034.
2. PLAY-022 completes independent visual review without implementing player-intent policy.
3. After an accepted renderer base exists, UI/input implements PLAY-034. Narrow edits to `CityScene` and `CitySceneView` are explicitly authorized only for the callback/presentation adapter required by this contract.
4. PLAY-051 independently reruns pointer, keyboard, AX, and compact target switching.

If the renderer candidate is rejected, implementation waits for the next accepted renderer base rather than creating a parallel adapter on an obsolete branch.

## Required acceptance matrix

At default and exact 900 x 600, the following cases must expose the same target coordinate, availability, disabled reason, and mutation result through grounded preview, AX/custom action, click, and Return:

- occupied tile: `.occupied`, no mutation;
- empty tile without direct road: `.roadAccessRequired`, no mutation;
- road-connected but unaffordable tile: `.insufficientFunds`, no mutation;
- road-connected affordable tile: available, identical build/cost result;
- the same blocked tile immediately after an adjacent road is added: available through every route.

Tests must alternate pointer and keyboard target changes so stale hover cannot survive as action truth. Staged proof must cover pointer and keyboard at both viewports, accessibility inspection, cancellation, and no modal/text leakage.

## Compatibility and rollback

- No save schema, fingerprint, simulation, snapshot, package, or gameplay-rule change is authorized.
- Active target and presentation are transient store/input state.
- The change must be isolated in focused commits so the bridge can be reverted without reverting renderer art or simulation work.

## Rejected expansion

This contract does not authorize a general input-mode owner, two simultaneous action targets, renderer-owned build rules, hover-driven inspect selection, camera redesign, new gameplay commands, or persisted pointer state.
