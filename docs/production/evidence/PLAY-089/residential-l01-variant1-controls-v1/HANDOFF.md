# PLAY-089 Residential L1 controls repair handoff

Status: `INTEGRATION_REPAIR_VALIDATED`.

Integration's independent review returned the first repair because its future
route receipt lookup was circular and its positive shared-route proof mocked
the real validator. The accepted follow-up separates `receiptCommit` from the
prior route authority, binds the current published claim authority, and runs a
committed six-row schema-2 receipt through the real shared validator without
mocks. Stale and post-commit-mutated receipts fail. The focused suite passes
21/21; the live schedule remains truthfully blocked pending lane synchronization
and separately committed route receipts.

This descendant preserves candidate `8b97870d` and repairs its returned
semantics across the same six files. The validator now executes legal batch and
row transitions from `contract_pending` through exact-candidate QA and
integration. It resolves claim and contract bytes from the declared Git
authority, rejects valid-but-stale dispatch heads, requires committed schema-2
route receipts and the real model-route validator for every dispatchable row,
and binds canonical QA preregistration thread
`019fc0b0-74cb-70e1-8923-8c9d9600484d` separately from frontier final reviewer
`019f7686-4491-7891-86a6-95a78d67e5c8`.

The schema and semantic gate now require timezone-bearing live observations,
structured dependencies/refills, authority acknowledgements, execution
accounting, a compute envelope, measured cross-row overlap, exact ledger and
dispatch projections, and `ledgerSha256`. Twenty adversarial tests include
positive acknowledged prelock, direction-local return without sibling
demotion, exact 4/4 readiness, and atomic candidate-to-final-QA transitions;
partial activation, fabricated overlap, route stubs, stale heads, projection
drift, missing accounting, and unbound DCC capacity fail closed.

The current schedule remains truthful at `contract_pending`: every worktree is
clean at its recorded head, every head is marked `stale_pre_authority`, route
receipts and acknowledgements are null, useful concurrency is zero, and
`dispatchReady` is false. Integration must independently accept this repair,
synchronize lanes, and publish exact committed routes before dispatch.

No lane was dispatched or synchronized. No product, claim, contract, DCC,
full/staged gate, acceptance, integration, push, or pin action occurred. The
exact repair SHA is the enclosing descendant commit reported after creation.
