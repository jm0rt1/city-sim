# Temporary generated-pack validator receipt

The first combined validation command completed both fresh pack builds and
proved their directories byte-identical. It then invoked the production pack
validator directly against generated-only pack A and stopped with:

- `rollback resource missing: manifest.json`
- `rollback resource missing: terrain_grass_0.png`

Those two legacy rollback files are intentionally present only in the
canonical `WorldAssets.atlas`; the generated-v4 builder owns the generated
manifest and four generated pages. The authoritative canonical validator had
already passed with zero failures, and the follow-up reused—not rebuilt—the
same A/B directories to prove:

- A and B remain byte-identical;
- the generated manifest and four pages equal canonical source bytes;
- production geometry passes; and
- the staged resource bundle equals source bytes.

`reports/TEMP-PACK-OVERBROAD-VALIDATION.json` preserves the exact stopped
receipt. No threshold, validator, product byte, or rollback policy changed.
