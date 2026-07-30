# Industrial L4 current-master authority refresh

Date: 2026-07-30

This prospective authority refresh supersedes stale live hash bindings without
rewriting the retained Industrial L4 evidence trail. It does not admit source
art, authorize a DCC process, select production assets, activate runtime
resources, or mutate the shipping manifest.

## Exact refreshed authority

- Shipping manifest:
  `317802265010fc758b232bea9198f18ec0ca4d75b5ceb6f759206238717cec92`
- Accepted-master non-alias input:
  `d1d75fdc30d9a2f21d49b59fd13dbc6fe7d81669f76f801d1087b35a7fb70044`
- Accepted-master non-alias loader:
  `83716838d310b5a5a3be51091b255d2a5eabb1b2f28d9af72a89a885779f3a7d`
- Source-stage schema v2:
  `85f6a2824c273a1e63354df79a97e5a59c2909a68771613b325664d649ac53ec`
- Source-admission validator:
  `46a9af769c1d3cf291c4859c79858373c576a70e17c8ccffd62d5619db0ef731`
- Source-candidate locator authority:
  `ddc9c5562bc2ff9e57ba15277113e058f535afe5339efef307e310de75e8d0fe`
- Source-candidate locator schema:
  `3c4fa6fe4372bd7beb54a7c2fc1fa8951c3134877a643317727dcc9daf7c8395`
- Renderer intake plan:
  `ca6c31bbafe0afcf537d1b58093c11c8485d3af734ac1e9a041438c271e68abe`
- Renderer intake validator:
  `d8f73de53e2212ce0af30cc1801ddbbb1805a63aa3019da98444ef04dec6cadc`

The accepted-master replay remains 44 unique logical sources with inventory
SHA-256
`9a5f561327ba5ed3a5178c03caae19d79204401b9b7dfd5c53ac716d2e6ab3af`
and forbidden decoded set SHA-256
`265c564785a5fa4ce14fbd04898ef04aaed883e2ca56f6a0660a9937464926ea`.

## Validation disposition

- Python source-admission publication check: pass.
- Python source-admission validator tests: 17/17 pass.
- Focused Swift locator, adapter, and admission harness tests: 28 executed,
  2 caller-fixture skips, 0 failures.
- Renderer intake plan validator: pass.
- Renderer intake validator tests: 37/37 pass.

Worker-local runner bindings and live claims must consume this published
authority in new prospective checkpoints. Historical receipts, rejected
attempts, accepted art bytes, the accepted-master inventory, and prior
dispatch receipts remain immutable.
