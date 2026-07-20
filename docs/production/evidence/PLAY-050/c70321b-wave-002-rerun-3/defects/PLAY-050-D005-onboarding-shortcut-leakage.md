# PLAY-050-D005 — Gameplay and Command-Guide Shortcuts Leak Through Onboarding

- Candidate: product `c70321b7c61465efe77f600878f74b8093013cb7`; playtest merge HEAD `8f692625c6821285036d29cc6f65379c6fa2f8b1`
- Severity: critical acceptance blocker
- Owner return: UI and Input
- Requirements: CONTRACT-002 modal/text focus containment; D001 blocking onboarding; keyboard/accessibility gate
- Disposition: reproduced in a separately reset live staged app

## Reproduction

1. Delete only candidate domain `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`, ensure its injected root is empty, and launch the exact staged bundle.
2. Confirm welcome, Day 1, $26,000, 300 residents, selected 1×, and `Start Building`.
3. Without dismissing the welcome, send `Space`, `1`, `2`, `3`, `B`, `V`, `Escape`, then `⌘/`.
4. Inspect the visible sheet and underlying accessibility tree.

## Expected

The blocking welcome owns input. Gameplay commands and the command guide do not execute; the authored speed/tool state stays unchanged; the welcome remains keyboard-operable through its explicit dismissal control.

## Actual

The guide opened above onboarding and focused its search field. After closing it, the welcome was still visible but `3×` was selected instead of `1×`. The city metrics remained frozen, so this is input/UI-state leakage rather than renewed simulation drift.

## Impact

A new player can unknowingly change the future simulation speed while reading onboarding and can enter a second modal command surface before accepting the start. This creates false modal containment, unpredictable first-pulse pacing, and an accessibility/focus stack the frozen gate expressly rejects.

Evidence: `../visuals/d001-modal-leakage.png`, `../visuals/d001-modal-underlying.png`, and `../d001-onboarding-retest.md`. No product fix was attempted.
