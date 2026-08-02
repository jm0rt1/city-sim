# PLAY-073 R4-E second repair return

**Disposition:** `RETURN`

**Integration authority:** `00a06738d17cbdfb90de3c8b0fdc5ae8a7b94359`

**Renderer checkpoint base:** `1c3d59c7f36750195ade80f382b3a280762e2e5f`

**Claim:** `docs/production/claims/PLAY-073.world-rendering.md` at SHA-256
`51b347c22df6b04e33b0cb59046c774b65f770465bea21d1073db55cca75b897`

## Frontier disposition

The bounded R4-E proof repair has exhausted its two-attempt Luna local-debug
authority. The v2 exporter produced truthful evidence, but the frozen visual
architecture still fails the binding gates:

- court survival is `0.1346081085` to `0.1385323949`, below `0.55` in every
  governed view;
- foreground/facade overlap is `4812` pixels in regular views and `2734` in
  compact, where the gate is exactly `0`;
- color luma deltas are `8`, `3`, `12`, and `1`, below the required `18`;
- grayscale luma deltas are `8`, `3`, `12`, and `1`, with only one view
  reaching the required `12`; and
- visible-court pixel counts exceed their minimums, so the failure is not an
  empty-mask or missing-output artifact.

The current renderer-only strategy is returned. It is not a product candidate,
must not be integrated, and receives no third Luna repair. The next product
authority must be a fresh frontier decision about authored frontage and
ground-contact architecture, potentially consuming independently admitted
source art; it may not be disguised as another threshold, mask, opacity, or
coordinate tweak.

## Preservation boundary

One Luna-mechanical checkpoint may preserve the exact current dirty state and
add only
`docs/production/evidence/PLAY-073/r4-e-depth-layered-residential-frontage-v2/FAILED-CHECKPOINT.md`.
It must not rerun tests, modify the frozen source/test/evidence bytes, claim
readiness, run aggregate or staged gates, score, accept, merge, push, or pin.

The exact frozen state is:

- binary source/test diff SHA-256:
  `7095aa365ad33236261156b4c85488e3d5db27883aabd373a8830ba15baf95ae`;
- `LotContextRenderer.swift` SHA-256:
  `bdd539cbee92f23076604319d52afebcd23665a13ce2f351b1fcef999ef8f9e2`;
- `WorldRenderingTests.swift` SHA-256:
  `cd6718bfcfcba19f50db616d599c6a0155eee030f80bde7cf1df79ace3a3f6a1`;
- `HANDOFF.md` SHA-256:
  `2908bc801de8926bc0782f7ff8574250eed3af2cf47354bdb778962477d03c92`;
- `PIXEL-ROLE-LEDGER.json` SHA-256:
  `4a62ec53064919c9a7cb4daa920187a9c6a672354ede1060b946a22423ce9678`;
- `RESULT.json` SHA-256:
  `9e342889ea26c22c8ad3acf966afb31f7eaf21af09f5cb115459f5b30118ff91`;
- color contact sheet SHA-256:
  `f98af1f5e1cde2571330c4d5a44ad2349d402fb88711671ff158d980cb2ba6ec`;
- grayscale contact sheet SHA-256:
  `46bf566c01800043cdfb2cdb8c1d08901df64916b39c381ca9132c1f9afcd5bf`.
