# PLAY-050-D006 Revision — Repaired live handoff still fails

- Severity: critical acceptance blocker.
- Product: `1dd89f6af439238b192b9b60e666e8be2fbb302b`.
- Quality merge: `5e93b7a808aed7cb4fbb12c24e8386ba5f7e35f8`.
- Prior immutable rejection: `docs/production/evidence/PLAY-050/d947b7d-wave-002-final/defects/PLAY-050-D006-post-welcome-gameplay-focus.md`.
- Current result: reproduced after the repaired Return route.

Welcome quarantines the authored Day 1 state correctly for 77 seconds and disappears on Return. A fresh full AX read then reports the standard window as focused. Space is inert twice without any intervening click: Pause remains unselected, 1x remains selected, and the city advances Day 1 to Day 6 to Day 13. The candidate's focused coordinator test passes, but the real staged SwiftUI/AppKit composition does not make its shipped SKView first responder.

See `../d006-retest.md` for exact steps and `../session-record.md` for deliberately unexecuted gates. No product fix was made in PLAY-050.
