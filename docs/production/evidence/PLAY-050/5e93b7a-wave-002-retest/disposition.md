# PLAY-050 Repaired Wave 002 Independent Disposition — Rejected

- Product candidate: `1dd89f6af439238b192b9b60e666e8be2fbb302b`.
- Frozen quality candidate: `5e93b7a808aed7cb4fbb12c24e8386ba5f7e35f8`.
- Disposition: **REJECTED**.
- PLAY-050 remains open.

D001 quarantine remains fixed, but D006 is still reproduced in the exact repaired staged app. Return removes Welcome, yet the real app does not transfer first responder to `SKView`; Space remains inert across two fresh-state attempts while the city advances from Day 1 to Day 13. The new focused unit test passes, so it does not exercise the failing live composition boundary.

Return D006 to UI and Input. A replacement candidate needs real staged proof that the actual `NSWindow.firstResponder` is the shipped `SKView` after both Return and pointer dismissal before PLAY-050 is asked to repeat this gate. Per the supplied gate order, compact pointer, D002, command traversal, persistence, accessibility, performance, and the 20-minute journey remain unexecuted.
