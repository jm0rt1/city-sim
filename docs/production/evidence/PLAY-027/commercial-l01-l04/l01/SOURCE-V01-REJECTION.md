# PLAY-027 Commercial L1 source-v01 rejection

**Disposition:** rejected before normalization and before any L2 work

**Production selected:** no

Integration's independent raw-source inspection rejected the first Commercial
L1 N/E/S/W render. North and south showed complete volumetric buildings, but
east and west did not reliably present the complete building body, footprint
plate, and southeast shadow. The result therefore fails the stable
footprint/pivot/shadow and four-view commercial-silhouette gates even though
the four authored scene descriptors pass schema and uniqueness validation.

The first render and its independent-process repeat are preserved exactly.
The native canonical-pixel validator also found that only east repeated
identically. North, south, and west each produced two pixel hashes, so
source-v01 independently fails the repeat-run determinism gate.

| Direction | retained raw SHA-256 | repeat raw SHA-256 | repeat pixels |
|---|---|---|---|
| north | `99105629cb5ed6a7ba70c6769340e17c2810f5dc644aa750b3562ec814dff116` | `6e9764c7cd99c9f6c66164471a6def2aa2299e87c56eeceb2c713fc0e01739ed` | different |
| east | `92b65ae69586c1570e04aa842e5d3f69f78ebdbf8ee541b695831fce0dd6de81` | `92b65ae69586c1570e04aa842e5d3f69f78ebdbf8ee541b695831fce0dd6de81` | identical |
| south | `85a55272ce445760af9355fe73220a5179a65d92315a57bf987912e617d85570` | `7b77641f62e21c4c0771af99521d41dbe2c9b4c6d0be129c9fd1c76c7740abfc` | different |
| west | `e0d341e43d4a32a4c222d8a8b041aef156ffb0f77c29598569b167afaef80871` | `5aea27ebdfa972edf73c010ef3c11385b4ded8a2e10e360a1ea9624cc3e3f5bf` | different |

Retained evidence:

- `SCENE-VALIDATION.json` records four unique descriptor hashes and four
  unique geometry IDs with no scene-contract failures.
- `SOURCE-V01-RAW-UNIQUE.json` records four unique N/E/S/W canonical pixel
  hashes.
- `SOURCE-V01-RAW-REPEAT-{direction}.json` records the binding repeat-run
  results.
- `source-v01-rejected/repeat/` retains every run-B raw and render record.
- task-owned `raw/commercial_l01/` and `provenance/commercial_l01/` retain the
  first raw and render record for every direction.

No source-v01 image is normalized, selected, ingested, packaged, or shipped.
The repair must advance all four directions to a new source revision and must
prove complete volumes plus repeat-run identity before normalization.
