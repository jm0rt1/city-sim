# Candidate-neutral preregistration validation

- **Published authority:** `9950906e8dbbc3cf48a0dc5b05e9a7d38b7a76d8`
- **Authority merge carrier:** `b8683874a49cd23b52d08cedc4230255f203325e`
- **Source-stage schema SHA-256:**
  `93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7`
- **Disposition:** `PREREGISTRATION_STRUCTURE_VALID`

Validation established:

- the published authority and preserved fixture-materializer checkpoint are
  both ancestors of the QA carrier;
- the on-disk v2 source-stage schema matches its published SHA-256;
- all five preregistration JSON files parse;
- North/East/South/West directions, PLAY tasks, branches, logical IDs,
  source-pixel sockets, and evidence roots are exact and unique;
- every slot has null packet, admission-receipt, and recommendation bindings;
- every slot explicitly denies staged-app evidence and production acceptance;
- the input contract requires `source_candidate`, candidate-ready true, all
  source/Integration/Renderer/production flags false, exact v2 identity, and a
  published Integration source-admission receipt before literal review; and
- the final staged-app gate remains
  `BLOCKED_AWAITING_EXACT_4_OF_4_RENDERER`.

`git diff --check` passed. No source candidate, actual pixel panel, author
assessment, product/resource file, app process, fixture derivative, score, or
acceptance disposition was inspected or created by this preregistration.
