# PLAY-075 Industrial L4 focused family rubric

This candidate-neutral rubric is frozen before an exact 4/4 renderer candidate
exists. Five categories are evaluated from zero through four. Focused batch
approval requires `20/20`, every category `4/4`, zero P0/P1 defects, and zero
automatic returns. This is not the separate Wave 009 full-release score.

## 1. Atomic family identity and frontage — required 4/4

All twelve `N/E/S/W x City/Neighborhood/Block` runtime identities must use the
exact accepted L4 source for the real sole-adjacent-road frontage. They must
read as one premium Industrial L4 family without mirror, rotation, recolor,
alias, fallback, direction substitution, wrong-road entrance, or camera-based
selection. Each runtime direction must bind the exact
`citysim_source_pixels_v1` socket in the accepted bridge mapping: North
`[896,704]`, East `[896,832]`, South `[640,832]`, and West `[640,704]`.
Blender-native coordinates and DCC world labels are never QA direction
identities. Four requires complete bridge/source/pack/runtime identity and
materially coherent direction-to-direction massing, material, value, light,
shadow, outline, and scale.

## 2. Premium L4 progression and world cohesion — required 4/4

At first glance and without labels, every direction must read as a high-tier
heavy-industrial works rather than Residential, Commercial, civic, airport,
campus, generic warehouse, or sterile imported art. Hall, production hero,
freight/staff hierarchy, subordinate stack/equipment, frontage, and contact
must form a believable whole. L4 must be materially richer and more legible
than the exact published L3 baseline while remaining part of the warm/dark
brick, civic, utility, road, terrain, and public-realm world.

## 3. LOD, compact, construction, and condition meaning — required 4/4

City must preserve district and heavy-industry silhouette; Neighborhood must
preserve frontage/logistics and primary material grouping; Block must preserve
entrance, craft, condition, and construction detail. Regular and exact compact
color/grayscale views must retain family, level, frontage, ground contact, and
hierarchy. Construction and weathering may simplify or overlay art but may not
erase premium L4 identity or imply a different building.

## 4. Interaction, persistence, and accessibility — required 4/4

Pointer and keyboard must target the same lot once, with the same visible and
AX block, Level 4, workers, state, road context, action, selection boundary,
and Details identity. Hover/selection may cover less than `10%` of opaque
building pixels and may not obscure the entrance or frontage. Demolition must
change one exact lot; Undo and save must restore the exact preregistered state
digest. Full Keyboard Access, VoiceOver/AX, Escape, and Reduce Motion must
preserve target, action, identity, and meaning at both widths.

## 5. Shipping identity and bounded resources — required 4/4

Source, product, executable, bundle, Info.plist, staging manifest, packaged
atlas, generated-v4 manifest, fixture, defaults domain, data root, PID, and
capture hashes must bind one exact candidate. Four requires:

- zero fallback and exact source/staged resource parity;
- no more than four active `2048 x 2048` atlas pages;
- active-plus-next decoded residency no greater than `50,331,648` bytes unless
  Integration publishes a separate budget change before candidate admission;
- cold world update no greater than `6.03 ms`;
- unchanged pulse no greater than `2.1 ms`;
- LOD transition p95 below `16.7 ms` and maximum below `33.3 ms`;
- settled regular, compact, and Reduce Motion footprint at or below
  `333.8 MiB`;
- no unexplained regression over `20%`;
- no continuing texture, node, action, RSS, or footprint growth after three
  LOD cycles and a 60-second settle; and
- no unexplained growth from the retained `1,823/890` regular or `1,843/904`
  compact node/drawable references.

## Automatic returns

Return regardless of score for:

- fewer than four exact accepted directions in one candidate;
- bridge source authority other than `3e01ca6738d7574718f9aeff4b66771eee109feb`,
  mapping SHA-256 other than
  `5695927b78ceaba52eda6f78f23b0e719623b492f5c5ee36845235fea3c06ff7`,
  source order other than `[0,1,2,3]`, any per-direction transform, or any
  runtime-direction/source-pixel-socket mismatch;
- separate QA production acceptance requested for a direction cell;
- ambiguous commit, fixture, executable, resource, manifest, PID, window,
  camera, target, defaults, or data-root identity;
- author screenshots, partial retained frames, fixture-only proof, or a
  baseline rehearsal substituted for the fresh candidate journey;
- wrong level/frontage, alias, mirror, rotation, recolor, fallback, crop,
  blank/sparse LOD, or source-to-runtime hash drift;
- fake rotation, direction cloning, mixed family, sterile/chalky/clinical
  disconnect, generic-building ambiguity, or material/value/light mismatch;
- floating, pasted, detached, overlapped, clipped, misregistered, or
  road-disconnected building, shadow, court, entrance, or selection boundary;
- compact, City LOD, grayscale, construction, condition, or Reduce Motion
  collapse;
- pointer/keyboard target mismatch, hidden actionable identity, AX-only
  critical truth, broken focus/Escape, or failed exact Undo restoration;
- hard resource/frame failure, accumulation, nondeterminism, or staged/source
  mismatch;
- product/source repair, coaching, candidate substitution, rubric relaxation,
  author scoring, self-acceptance, push, or integration by QA; or
- one attractive direction, width, or LOD masking a failure elsewhere.
