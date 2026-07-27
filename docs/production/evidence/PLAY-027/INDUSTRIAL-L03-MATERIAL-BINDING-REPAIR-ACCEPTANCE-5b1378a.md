# PLAY-027 Industrial L3 material-binding repair acceptance

- Exact accepted repair candidate:
  `5b1378a2c81d7d55a39b19366b5206c28f70d9f7`
- Repaired family manifest SHA-256:
  `78fef5beed40229d0637ba74e85737c939bbaa460f42a17b49f24769e92704a1`
- Validation SHA-256:
  `02ffc9c5cd932de24a7ad0e85af23ba1839d6d5c32a409a16fa27e6847595430`
- Integration disposition:
  `ACCEPT_METADATA_REPAIR_RESUME_REPLACEMENT_R2_INGESTION`
- Source authority: `true`
- Family authority: `true`
- Production selected: `false`
- Shipping acceptance: `false`

Integration independently compiled and replayed the candidate's native
validator. The replay report was byte-identical to the committed validation
report.

The accepted repair:

- changes only East/South descriptor material-library file and SHA bindings,
  their two family-manifest descriptor hashes, and metadata-derived repair
  records;
- binds East/South consistently to cohesion material library
  `f39bbf5914ba15f90f100bfed5ac65e537b5a6a62d677be82698ac89cf982b65`;
- preserves North/West descriptor bytes and every material/provenance file;
- preserves all four raw and all 24 normalized PNG files byte-for-byte from
  source candidate `0aefb804c59b4ff9b919dc81fdca907cd4b85c5e`;
- retains 12/12 unique production output identities and all repeat, alpha,
  chroma, padding, registration, and contact-shadow passes; and
- rejects swapped-library and wrong-hash negative cases.

This record supersedes the prior manifest hash in
`INDUSTRIAL-L03-SOURCE-FAMILY-ACCEPTANCE-0aefb80.md` as the exact renderer
ingestion authority. The prior visual acceptance remains valid because no
pixel changed.

The World Rendering lane may resume the exact replacement-R2 ingestion from
its clean checkpoint, after synchronizing this published authority. All
constraints in the prior source-family acceptance remain binding, including
exact 12-asset ingestion, source-to-pack identity, descriptor revision and
material binding validation, preservation of unrelated catalog bytes, staged
regular/compact proof, independent QA, and no self-acceptance.
