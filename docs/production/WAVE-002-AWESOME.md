# Wave 002 — Make CitySim Feel Awesome

**Status:** Dispatched from the wave-two baseline

**Date:** July 19, 2026

## Product promise

This wave must materially change how the staged game feels. The player should enter a stable city, understand pressure immediately, control the entire command deck from the keyboard, see neighborhoods visibly react, experience a strategy-specific city story, and trust save/resume. The wave is rejected if it merely adds hidden infrastructure, test count, or decorative polish without improving the real journey.

## Target journey

1. Onboarding holds the authored city still until the player starts.
2. The player diagnoses the opening pressure and makes a first decision within two minutes.
3. Commercial and industrial strategies create visibly and numerically different consequences.
4. Construction, growth, stress, decline, and recovery read directly in the world.
5. Every non-spatial action is discoverable and keyboard-operable through one command catalog.
6. The HUD arbitrates compact surfaces and remains a usable command center at 900 x 600.
7. Save, leave, resume, undo, and corrupt-save recovery preserve authoritative state and explain what happened.
8. Independent PLAY-050 testing completes the pointer, keyboard, compact, accessibility, and isolated save/resume gate without coaching.

## Lane orders

### Gameplay — PLAY-011

- Build two deterministic strategy-sensitive arcs on the accepted PLAY-010 loop.
- Each arc needs advance warning, an opportunity, a recoverable setback, at least two valid responses, and a payoff.
- Preserve the accepted Town Charter timing and existing recovery path.
- Stop before inventing a general event framework or new UI/render contracts.

### World — PLAY-020

- Turn the preserved lot-lifecycle checkpoint into a complete, proof-backed player outcome.
- Make construction, healthy growth, stress/decline, and recovery distinct through silhouette, motion, props, labels/effects, and non-color-only cues.
- Retain default, compact, and camera-level real-world proof plus renderer diagnostics.
- State plainly which utility/prosperity/pollution cues remain blocked on snapshot analytics; do not fake them.

### UI and input — PLAY-030

- First fix PLAY-050-D001: blocking onboarding freezes the simulation and dismissal returns control from the exact authored start.
- Then fix PLAY-050-D002: at 900 x 600, objectives and command-center details arbitrate into an operable, accessible layout with visible scrolling/focus.
- Implement CONTRACT-002 as one command catalog, intent router, menus, searchable command guide, shortcuts, disabled reasons, focus rules, and coverage/collision tests.
- Provide real staged pointer and keyboard proof at default and compact sizes.

### Simulation platform — PLAY-040

- Implement CONTRACT-003 in coherent checkpoints: fingerprint, schema-1 envelope with schema-0 compatibility, backup recovery, injected root, immutable presentation snapshot, fixture commands, and performance diagnostics.
- Implement CONTRACT-004 so every worktree stages a uniquely identifiable app with isolated save/preferences/process targeting.
- Prove exact PLAY-010 state, progression nil semantics, undo, save/resume, corruption recovery, and two simultaneous isolated candidates.

### Playtest quality — PLAY-050

- Preserve the rejected integrated-wave evidence and treat D001/D002 as open until independently reproduced as fixed.
- Prepare the authoritative catalog-derived keyboard inventory and isolated-root journey harness while product lanes work.
- After integration supplies a candidate, rerun the full fresh-start pointer journey, keyboard-only route, 900 x 600 compact/accessibility route, save/resume, undo, corruption recovery, and two-strategy comprehension gate.
- Reject the wave for any critical false feedback, inaccessible action, uncontrolled simulation during onboarding, ambiguous candidate identity, or coaching requirement.

## Contract and merge order

1. Integration decisions: CONTRACT-002, CONTRACT-003, CONTRACT-004.
2. PLAY-040 persistence/isolation contracts.
3. PLAY-011 gameplay arc.
4. PLAY-020 world consequence presentation.
5. PLAY-030 blocker repairs and command system.
6. PLAY-050 independent evidence and disposition.

Workers must merge the published wave-two `master` baseline into preserved branches without rewriting their existing commits. No worker pushes or integrates.

## Integration acceptance gate

- Every candidate is clean, claimed, coherently committed, and tied to a complete record.
- Full native tests, `git diff --check`, build-script syntax, staged `--verify`, and affected performance evidence pass.
- Integration operates the real staged build with pointer and keyboard at default and 900 x 600.
- The world visibly communicates the named lifecycle states.
- The command catalog has 100% declared non-spatial inventory coverage and no collisions/focus traps.
- Save/load/undo/recovery use isolated roots and exact fingerprints.
- PLAY-050 independently passes the complete journey. A green suite cannot override a failed hands-on gate.

## Significant-improvement test

Wave 002 is significant only if a returning player can immediately point to all five improvements: a stable start, richer strategy reactions, a more alive and legible city, a substantially more capable HUD/keyboard command system, and trustworthy session continuity.
