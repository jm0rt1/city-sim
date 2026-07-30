# Industrial L4 source-admission receipt v1 authority

Integration publishes this fail-closed receipt contract before any Industrial
L4 direction produces pixels. Publication creates no source admission,
appearance lock, Renderer quarantine, production selection, or shipping
authority.

## Frozen inputs

| Surface | SHA-256 |
|---|---|
| `industrial-l04-source-admission-receipt-schema-v1.json` | `08ad183eb90dc8eb14567a432c00841b010f90f8d8e4d359b60d4735c4ca4f66` |
| `validate_industrial_l04_source_admission_receipt_v1.py` | `497f4e696cb6da3740e9dd60877cd25ea631268df1124513b1468ad6d51158cf` |
| `test_validate_industrial_l04_source_admission_receipt_v1.py` | `11350ac584dbbde580624b3f7f12e7056aaf522116b6a4f62e27e1ca3c202430` |
| source-stage schema v2 | `93efe9ca6d000a2d145098f722338c8e85829d6de6724c3f231a93c06eadf3d7` |
| source-stage semantic validator v2 | `7a0613af9998a222a583a70930ce3afc5ec1902793f03201f899a2bb4129f340` |

The validator requires the complete source-stage v2 schema, reruns the exact
semantic validator in the separate clean, exact-branch, exact-HEAD source
worktree against the exact worker packet, and requires its output to equal an
Integration-owned retained semantic-validation receipt. It verifies
independent technical and literal-scale review bindings, exact raw and decoded
hashes, declared authority blobs at their commits, Git ancestry, and the
Integration ledger admission revision. Repository inputs are regular,
non-symlinked, repo-relative files; traversal and outside-root paths fail
closed.

## Admission order

1. A direction returns a `source_candidate` packet that keeps worker
   `sourceReady`, `integrationAdmitted`, `rendererQuarantined`, and
   `productionSelected` false.
2. Integration independently runs the semantic validator and retains its exact
   output below
   `docs/production/evidence/INTEGRATION/industrial-l04-semantic-validations-v2/`.
3. Independent technical and literal-scale reviewers bind their dispositions
   to the exact packet, content commit, raw identity, and decoded identity.
4. Integration first commits the shared ledger direction as
   `integration_admitted`, including the admitted content, packet, and raw
   hashes.
5. Integration then publishes the direction receipt below
   `docs/production/evidence/INTEGRATION/industrial-l04-source-admissions-v1/`,
   binding that committed ledger blob.
6. Renderer may quarantine that exact admitted direction. It may not activate
   the family until all four exact directions are admitted and quarantined.

The publication check passed with zero live admission receipts. The 17 focused
tests cover the complete source-stage schema gate, fresh semantic-result
identity, review and hash drift, authority escalation, traversal, symlinks,
schema integrity, a real clean-source-worktree subprocess, Git ancestry/blob
identity, duplicate keys, all four direction identities, and the
zero-live-receipt boundary.
