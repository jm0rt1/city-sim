# PLAY-121 Claim — Make tax relief a visible recovery commitment

- **Lane / owner:** Gameplay — Agent 101 Gameplay Lead.
- **Authority/base:** `e30d6eb960ff32b4643975e4df7dcd4856515e8b`.
- **Player outcome:** In the ordinary Commercial pressure path, lowering tax through the existing Tax Policy control produces a truthful, visible recovery consequence at the next governed review, rather than leaving the player unsure whether the advertised remedy mattered.
- **Allowed paths:** `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`, `Native/CitySimNative/Tests/CitySimNativeTests/GameplayLoopTests.swift`, `docs/production/evidence/PLAY-121/`, and `docs/production/completed/PLAY-121.gameplay-tax-recovery-currente30d.md` only.
- **Contract:** Existing tax-rate input, messages, save schema, fingerprint version, strategy/recovery identities, UI routes, and renderer stay unchanged. The simulation may only publish an existing-message-model consequence derived from already-authoritative tax state at the existing daily boundary.
- **Focused proof:** A deterministic normal-UI-equivalent tax-rate change during Commercial pressure proves one causal recovery message/metric change at the governed review, preserves a no-change control, and leaves save/replay/strategy behavior intact.
- **Stop:** Any new public command/state, save/schema/fingerprint change, UI/renderer edit, balance redesign, or failed second focused attempt.
