# PLAY-027 Industrial L3 source-v05 sensitivity matrix

`FINAL_DISPOSITION: DIAGNOSTIC_ONLY_NO_SOURCE_SELECTION`

This packet executes the exact four-row positive-2/255 diagnostic matrix
authorized by `78aba5442c675cc8664deaebffa13422ac2100c1` from attribution checkpoint
`a235546ef0a7ddf31cc2e78d16dfba62f08f82fe`. It does not create or select
source-v06. `sourceAuthority` and `productionSelected` remain false.

Exactly twelve fresh SceneKit processes were consumed: A/B/C for N1, W1, W2,
and W3. No normalizer process ran.

## Row results

| Row | Authorized material deltas | Result | Exact repeat result |
| --- | --- | --- | --- |
| N1 | charcoal-outline red +2/255; warm-trim red +2/255 | `REPEAT_FAIL` | A=C; B differs at `(796,746)` by one opaque red channel step of 32 |
| W1 | charcoal-outline red +2/255; warm-concrete blue +2/255 | `REPEAT_PASS` | A=B=C file and decoded-pixel identical |
| W2 | charcoal-outline red +2/255; restrained-safety blue +2/255 | `REPEAT_FAIL` | A=C; B differs at `(642,699)` and `(643,699)` by one opaque red channel step of 32 |
| W3 | charcoal-outline red +2/255; warm-concrete and restrained-safety blue +2/255 | `REPEAT_FAIL` | A=C; B differs at `(785,524)` by one opaque blue channel step of 32 |

W2 run B's two differing pixels also fall outside the projected envelopes of
the materials changed in W2. The packet records that ownership failure rather
than broadening the authorized material set.

## Invariant outcome

All twelve outputs retain non-chroma bounds `[509,387,1027,896]`, 159,510
non-chroma pixels, padding `[509,387,509,128]`, zero non-opaque alpha pixels,
zero hidden RGB pixels, complete rendered bounds, and exact
pivot/socket/frontage/contact/shadow/structural registration.

The complete source-v05 whole-image diff inventory, governed prequantized and
final neighborhoods, provenance, capability records, and projected changed-role
ownership are retained in `review/REVIEW-INVENTORY.json` and
`review/MATRIX-MANIFEST.json`.

Source, native-2x, compact, and grayscale comparisons show no visible geometry,
registration, silhouette, or family-material break. That visual observation
does not override the binding repeat failures.

## Closeout

- W1 passes this diagnostic row.
- N1, W2, and W3 fail exact three-process identity.
- No row is promoted to source-v06 or source authority.
- Frozen source-v05 inputs and all product, renderer, normalizer, shipping,
  package, and shared surfaces remain unchanged.
