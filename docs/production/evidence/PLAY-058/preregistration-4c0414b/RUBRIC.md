# PLAY-058 Frozen 20-Point Rubric

Score each category from 0 to 4 using the exact combined candidate only.

## 1. Public-realm coherence — mandatory 4/4

- 4: Parks, plazas, crossings, furniture, vegetation, people, and service
  activity form a believable, readable civic system at city, neighborhood,
  and block scales. Ground contact, seams, spacing, and state truth hold.
- 3: Shipping-quality and coherent, with one explained minor presentation loss.
- 2: Noticeably sparse, repetitive, decorative, or inconsistent.
- 1: Major collision, floating, seam, or state-truth failures.
- 0: Broken or absent.

## 2. World/HUD composition — mandatory 4/4

- 4: Regular and compact materially improve useful world occupancy while
  retaining priority, treasury, speed, notices, objectives, selected target,
  actions, exit, and topmost surface truth. Closed and Details-open states are
  readable, stable, and unclipped.
- 3: Shipping-quality with one explained minor composition loss.
- 2: Important world or HUD hierarchy is crowded, obscured, or unstable.
- 1: Critical information/action is hidden or contradictory.
- 0: Inoperable.

## 3. Overlay and causal truth

- 4: Land Value, Traffic, Utilities, Happiness, and Pollution each produce
  localized, state-consistent map truth with a legible legend, selection, and
  correction path in both viewports.
- 3: All five are actionable; one has a minor legibility loss.
- 2: One or more overlays are mainly legend-only or obscure selection.
- 1: Multiple overlays mislead or contradict state.
- 0: Overlay truth is unusable.

## 4. Interaction, accessibility, and motion continuity

- 4: Pointer, Return/Space, FKA, and AX identify and activate the same target
  once; modal/text quarantine, focus generation, Escape restoration, and
  Reduce Motion preserve complete truth.
- 3: Complete and shipping-quality with one explained minor loss.
- 2: Discoverability, focus, AX semantics, or Reduce Motion is materially weak.
- 1: Required input mode is inaccessible or contradictory.
- 0: Critical interaction cannot be completed.

## 5. Identity, determinism, and performance

- 4: Exact tree/bundle/manifest/resource/PID/data-root identity; three useful,
  distinct deterministic LOD states; zero fallback; at most four atlas pages;
  bounded residency and RSS with no continuing high-water; no unexplained
  frame or update regression.
- 3: Meets every shipping ceiling with one explained minor regression.
- 2: Identity is complete but performance or determinism is materially weak.
- 1: Ambiguous identity, fallback, accumulation, or serious regression.
- 0: Candidate proof is invalid.

## Automatic rejects

- decorative or toy-like public-realm treatment;
- repetitive vegetation rows, floating assets, ground-contact failure,
  reciprocal seams, road/public-space discontinuity, or unintended overlap;
- ambient animation that implies false simulation truth;
- any required overlay that is legend-only, misleading, or obscures
  selection/architecture;
- mixed projection, material, light, fidelity, or LOD language;
- a mostly empty city/neighborhood view or materially useless LOD;
- hidden or clipped priority, treasury, speed, notice, objective, target,
  action, or exit truth;
- state/camera/target drift when opening panels, changing input mode, or
  enabling Reduce Motion;
- pointer/keyboard/AX target or activation contradiction, modal leakage,
  broken focus generation, or wrong Escape order;
- AX-only access to information/actions that must also be visually reachable;
- candidate substitution, ambiguous PID, stale manifest, crop/downsample that
  conceals defects, or reuse of author scoring;
- resource/source hash mismatch, silent fallback, more than four active pages,
  unbounded residency/RSS, or an unexplained material frame/update regression;
- failure to materially prefer the exact candidate over this baseline in
  either regular or compact view.

## Binding threshold

`>=19/20`, categories 1 and 2 exactly `4/4`, every other category `>=3`,
zero P0/P1, zero automatic rejects, and explicit regular plus compact material
preference.
