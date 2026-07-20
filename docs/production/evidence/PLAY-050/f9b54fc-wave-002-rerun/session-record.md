# PLAY-050 Wave 002 Rerun Session Record — Rejected at Isolation Preflight

- Exact product candidate: `f9b54fc77a3d78fd4d8d5c80c8661d8d8852e209`
- Exact playtest candidate merge HEAD: `85ad9e266cfa0597d5d422008ebd2ef448fb25b3`
- Overall disposition: **rejected before player interaction**
- Player timer: not started
- Screenshots / AX / focus capture: not validly started
- Product changes: none
- Push/integration: none

## Gate results

| Gate | Result | Evidence |
| --- | --- | --- |
| Exact ancestry and clean merge | passed | `manifest.md` |
| Static checks and staged identity | passed | `automated-validation.md`, `manifest.md` |
| Full suite | passed | 78/78 in 40.558 seconds |
| Corrected dense v2 fixture | passed | full run plus two focused repeats |
| Exact staged process/path/hashes | passed | current candidate PID `32451`; `manifest.md` |
| Unique active preference identity | **failed** | D004: distinct active PID `59491` shares bundle/display/preference domain |
| D001 0/10/30/60 and modal dismissal | blocked; remains open | resetting the shared domain would contaminate another active candidate |
| D002 compact/FKA/VoiceOver/Reduce Motion | blocked; remains open | preference/window identity is shared and ambiguous |
| 32 commands, system routes, leakage | blocked | no valid isolated interactive session |
| Save/resume/undo/recovery | blocked | no valid isolated candidate session; data root remained empty |
| Two-candidate isolation | failed at preference identity | paths/roots differ, bundle/display/domain collide |
| 20-minute journey | blocked | manifest stop occurred before timer |

## Live disposition

No screenshot, AX tree, timing ledger, persistence mutation, or journey result is represented as candidate proof. The staged window was launched only for exact `--verify`; after the identity collision was confirmed, PLAY-050 performed no app UI action and stopped only its exact PID. The production quicksave remained byte-identical and the external candidate remained alive.

The repaired fingerprint contract passes, but the Wave 002 candidate cannot be accepted while its active preference identity is ambiguous. D001 and D002 remain open for a fresh rerun after integration supplies a candidate environment with no conflicting domain or an approved per-candidate identity contract.
