# PLAY-113 — Civic L1 four-view source candidate

Status: `PASS_CANDIDATE_SOURCE_HANDOFF` — source candidate only; not Integration-admitted, Renderer-quarantined, production-selected, staged, or player-accepted.

- Branch/base: `codex/citysim-world-art-civic-l01-v0-current374b` at `374b914a98c3b34ff735de28f7894e483f6d9ae2`.
- Claim: `docs/production/claims/PLAY-113.world-art-civic-l01-v0-currentb758.md` (`6472055e8c9839e12318a07a13c361081b289b0e26804cc60fdee162a588f4b5`).
- Family: `civic_l01_v0`, four independently generated road-facing public-library/community-hall masters with pale sandstone, teal civic doors, brick base, slate roofs, forecourts, and distinct north/east/south/west entrance compositions.
- Source hashes: north `b5bd3b6259d04626f59513f8ced0aa069fd72a4281a6ac04b7ca678255692fb9`; east `38fa961caf29e11c839ee58f6cd61b3cc311352ae9a268d64f34747153e2e6f1`; south `a55562c33064dd6dcd5d4e063f52cafe3c593b804a9eec2ec15e8ac6d8319af7`; west `938e71d8c938519302719b22d15bd117e8ea0ffcb5661f22442e3edf8915c529`.
- Fixed-registration packet: `1536x1024` source canvas, profile pivot `[768,896]`, four fixed frontage sockets, and 12 deterministic block/neighborhood/city LODs.
- Focused result: `validate_civic_l01_v0.py` PASS after two isolated output-root replays; alpha/chroma/frame, direction distinctness, registration, replay, and Renderer-boundary gates passed. Validation record SHA-256: `c10674bcb6ef4403cb04c5655ae8b20c109e1a57d223d22f2833bf616d16d76d`.
- Visual source sheets: color `6ba1ac82d390c4dbb45b7b3d4bb83983c781cf3399214ce9e0570b8bf2f1615e`; grayscale `90063c32c7e5a2ef5e2cb63d607d9fb6b8efae74f6a78e3ec68353f6aea1620a`.
- Immutable handoff: `docs/production/evidence/PLAY-113/civic-l01-v0-family/RENDERER-HANDOFF.json` (`120db6f50010cdca691c619c92b47bac133635b91973c5fca73a3267584ce105`).

Renderer intake is the next authority boundary. No shipping manifest, atlas, catalog, renderer, UI, simulation, gameplay, build, or master path changed here.
