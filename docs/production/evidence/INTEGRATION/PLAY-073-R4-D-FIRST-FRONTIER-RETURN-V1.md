# PLAY-073 R4-D first frontier return

**Disposition:** RETURN

**Reviewed renderer product:** `a4796c5194586eaf729e2aab11c0bfec852eef4c`

**Reviewed renderer evidence:** `9e762d4abc0b7539a6f7351c832b7623a877317f`

**Next execution tier:** `LUNA_IMPLEMENTATION / gpt-5.6-luna / high`

The focused 72-test result is credible for the assertions it runs, but the
candidate does not satisfy the frozen visual or proof contract. It is not
eligible for the aggregate build or independent PLAY-075 journey.

## Binding defects

1. **The exported exact pair is not the asserted adjacent pair.**
   `makeR4DContactSheet` positions the first node at
   `panelCenter - isoPosition(first) * scale`, while the second is positioned
   at `panelCenter + (isoPosition(second) - isoPosition(first)) * scale`.
   Node positions are not subsequently scaled by their own `setScale`, so the
   two placements use incompatible coordinate frames. The retained sheet
   visibly separates the buildings by hundreds of pixels instead of the
   required scaled `(-36,-18)` center delta.
2. **The viewport contract is not exercised.** The exporter creates one
   900-by-600 scene and four 438-by-288 panels. It does not render regular
   1280-by-800 city, neighborhood, and block views plus an exact 900-by-600
   compact neighborhood view as required.
3. **The garden-grove misses the frozen design.** The visible canopy is two
   flat, single-fill ellipses. It is not an asymmetric multi-lobed deciduous
   crown and has no convincing northwest highlight, interior value variation,
   or grounded contact language.
4. **The terraced court is not grounded.** In color and grayscale it reads as
   a bright sign-like slab across the building facade, not warm paving beside
   the building. The required paving/step rhythm is absent.
5. **Separation proof is incomplete.** The pair check covers the grove against
   the South neighbor envelope and each composition against only its own road
   envelope. It does not prove the court against the North neighbor envelope
   or both compositions against both selected road envelopes. Point-only
   exclusion can also miss a path segment crossing an envelope when its
   vertices remain outside.
6. **The sheet is not decision-useful.** Most pixels are blank background and
   the governed pair occupies too little of every panel to review silhouette,
   grounding, or material/value quality.

Reviewed artifacts:

- Color SHA-256: `cf201721f7f85d96a276910bbd8cfbb610bdbcbfb14f3942b1ab2193ee5e96f8`
- Grayscale SHA-256: `80c29029948f5a8db133134e46032a7b772f05c92656dab7eabafb21f32283c5`

## Frozen V2 repair

Preserve both R4-D commits and repair only the existing R4-D product, test, and
evidence paths.

- Put both lot nodes in one coordinate frame:
  `panelCenter + (isoPosition(tile) - isoPosition(first)) * scale`.
- Export four independently sized source frames: regular 1280-by-800 at city,
  neighborhood, and block; compact 900-by-600 at neighborhood. Assemble those
  exact frames into a labeled contact sheet without substituting miniature
  panels for the governed viewports.
- Center the exact pair consistently and choose a deterministic review scale
  that lets its occupied pixel bounds use 45-70% of each frame's shorter
  dimension while preserving all geometry. Record the measured bounds and
  center delta per frame in `RESULT.json`.
- Replace each flat canopy with at least three visibly overlapping authored
  lobes plus a distinct northwest highlight/value role and southeast
  shadow/contact role. Preserve the existing total silhouette minimums and
  envelopes.
- Reposition and reshape the court as an isometric ground plane beside the
  building. Add at least three visible paving or step rhythm marks. It must not
  cover the facade in the exact pair at any governed LOD.
- Prove both compositions against both road/frontage envelopes and the opposite
  building-contact envelope. Validate path-segment/envelope intersection, not
  vertices alone.
- Add raster assertions for occupied pair bounds, exact scaled center delta,
  non-empty lobe/value separation, court ground-plane orientation, and absence
  of facade occlusion. Retain deterministic color and integer Rec.709 grayscale
  repeat identity.

Run only the targeted R4-D export, the related adjacent-repetition regression,
focused `WorldRenderingTests`, JSON/hash/diff checks, and exact byte-repeat
comparisons. Produce one repair commit and one replaced evidence commit. Stop
after this one V2 repair or on any mandatory escalation trigger. Integration
retains aggregate and subjective acceptance; PLAY-075 remains the independent
final real-app reviewer.
