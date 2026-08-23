# CitySim product instructions

Build the polished, playable city builder in the native SwiftUI/SpriteKit
package at `Native/CitySimNative`, inspired by SimCity 4 with original art and
assets. Read [`.codex/project.md`](../.codex/project.md) and
[`docs/PRODUCT_RESTART_BRIEF.md`](../docs/PRODUCT_RESTART_BRIEF.md) before
planning or changing product work. Explicit user direction supersedes a
sequence in those documents.

Use `swift build --package-path Native/CitySimNative`,
`swift test --package-path Native/CitySimNative`, and
`./script/build_and_run.sh` as appropriate to the claim. A build or test is
not UX acceptance: user-visible or UX work requires proof from the real native
app at exact 1280x800 and true 900x600, with composed-screen evidence
proportional to the claim.

## Delivery boundaries

- One Goal Driver owns integrated planning and acceptance, with a lightweight
  liaison. Use at most one independent, short-lived specialist for a genuinely
  bounded contribution.
- Use SOL/high for Goal Driver planning, cross-cutting diagnosis, and
  acceptance; Terra/high for bounded isolated implementation; and Luna/medium
  only for mechanical tests, benchmarks, or log collection. Do not create
  agents merely to demonstrate delegation.
- Do not recreate retired workstreams, company hierarchies, claims, routes,
  ledgers, handshakes, dashboards, routine handoffs, or ongoing agent job
  assignments.
- Preserve unrelated legacy Python code unless the user explicitly targets it.
- Contact the user only for critical unresolved product tradeoffs, material
  scope or budget changes, irreversible or external actions, or true blockers.
