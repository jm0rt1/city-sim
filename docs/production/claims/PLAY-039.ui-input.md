# PLAY-039 Claim

- **Title:** Make the world the hero of the HUD
- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Base commit:** Published Wave 006 integration baseline containing this claim
- **Claimed:** July 24, 2026
- **Planned surfaces:** SwiftUI HUD hierarchy and composition, existing command/store/focus routing, compact/default map aperture, accessibility, and exact staged evidence
- **Dependencies:** accepted PLAY-033; current active-map-target and catalog/store contracts
- **Validation/proof:** same-state default/compact before/after, measured interactive map aperture, priority/action/selection visibility, pointer/keyboard/FKA/AX routes, rejection recovery, command search, focus/Escape, Reduce Motion, full suite, and independent PLAY-053 handoff
- **Status:** accepted by integration. Product `f8f8006`, evidence `a895568`,
  and completion `b497f1d` are integrated; independent PLAY-053 accepted the
  combined world/HUD candidate at 19/20. PLAY-054 owns later legibility and
  compact command-center follow-up.

Make the city—not the chrome—the dominant visual surface. Preserve the
authoritative priority and every operable route while materially reducing the
visual weight and obstruction of the top metrics, floating priority, and lower
command deck.

Follow `docs/production/WAVE-006-WORLD-EXCELLENCE.md`. Do not edit SpriteKit
art or geometry, infer gameplay truth, create a second command/selection
authority, hide required information, or trade accessibility for a prettier
screenshot. Commit product, evidence, and completion separately; do not push,
self-integrate, or self-score.
