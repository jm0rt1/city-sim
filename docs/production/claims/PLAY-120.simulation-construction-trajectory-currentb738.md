# PLAY-120 Claim — Make completed construction visibly enter city response

- **Lane / owner:** Simulation platform — Agent 201 Simulation Lead.
- **Authority/base:** `b738653470199e8c07f9d76336d3ddf156891d60`, after accepted PLAY-121.
- **Player outcome:** A completed player-built utility or growth lot enters the existing deterministic city response on the first eligible governed tick with a truthful visible consequence, so players can see their construction alter capacity/pressure rather than infer an invisible update.
- **Allowed paths:** `Native/CitySimNative/Sources/CitySimNative/Services/CitySimulation.swift`, `Native/CitySimNative/Tests/CitySimNativeTests/CitySimulationTests.swift`, `docs/production/evidence/PLAY-120/`, and `docs/production/completed/PLAY-120.simulation-construction-trajectory-currentb738.md` only.
- **Contract:** Existing construction cadence, save schema, fingerprint version, command/store/UI/renderer contracts, and balance coefficients remain unchanged. Work may only expose already-calculated capacity/pressure transition through the existing message/state model at the established tick boundary.
- **Focused proof:** Deterministically build one utility or growth lot, advance to completion and the first governed response, prove the existing capacity/pressure metrics and one truthful causal consequence evolve in order; prove identical replay and no premature outcome before completion.
- **Replay provenance:** The exact frozen two-file candidate from e30d was cleanly replayed onto this base; its CitySimulationTests SHA-256 remains `0ea8039b411431daaa50aa3d6ee06b657de8b46f3a076e4476de2437847a91fd`.
- **Stop:** Any required textual or semantic conflict with PLAY-121, altered cadence/economics/save/schema/fingerprint/public command, UI/renderer edit, or second focused failure.
