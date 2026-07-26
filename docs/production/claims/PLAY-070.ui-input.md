# PLAY-070 Claim

- **Title:** Make Regional Capital victory actionable and truthful
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Prepared authority:** Published master `1f6312927a84d84a03e59bea9672717b25e26862`
- **Required mutation base:** Exact controlled integration commit
  `c9d4baef3bd52fce9970c2e02d42ab646905be50`, containing accepted PLAY-064,
  PLAY-067, and PLAY-069. This commit is intentionally not published because
  its only failing full-suite assertions are the seven UI adoption assertions
  owned by this claim.
- **Planned surfaces:** Existing notice-action catalog and explicit authored-title inventory; existing terminal victory presentation and tests; regular/compact staged evidence and completion records
- **Dependencies:** Integrated PLAY-064/069; CONTRACT-015; clean completion of PLAY-067
- **Validation/proof:** Honest actions for all four Regional warning/critical titles; legacy Charter versus current Regional terminal copy; pointer/keyboard/menu/guide/Escape/FKA/AX replay; regular/compact screenshots and AX trees; full native suite; staged verification
- **Status:** Claimed. Integration may send exact `BASELINE READY` for
  `c9d4baef3bd52fce9970c2e02d42ab646905be50`; no other unpublished or dirty
  integration state is authorized.

## Controlled adoption boundary

The exact mutation base executed 234 native tests. All non-UI suites passed.
The only failures were seven assertions in two existing
`CityCommandCatalogTests`:

1. Four Regional warning/critical titles require explicit typed action
   dispositions.
2. The current strategy HUD inventory must adopt the authoritative 12-state
   v2 corpus instead of expecting the legacy eight-state corpus.

The worker must make precisely this boundary green while also implementing
legacy-versus-current terminal identity. Any additional failure, renderer
change, fixture regeneration, gameplay rule change, or save/schema change is
a stop and return to integration.

Adopt the already durable second-act truth into existing player-facing
surfaces. Do not add commands, infer gameplay state in views, change saves,
edit renderer assets, regenerate platform fixtures, or relabel authentic
missing-`secondAct` Charter victories.
