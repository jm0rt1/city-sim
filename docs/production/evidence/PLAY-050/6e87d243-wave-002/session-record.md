# PLAY-050 Wave 002 Session Record — Rejected at Preflight

- Exact product candidate: `6e87d24398fb204cbb4bc2612239d7e295730949`
- Exact playtest candidate HEAD: `dfc9a67ca826a12e0df5c0eac11ae336dc314776`
- Frozen journey: `critical-journey-v4.md`
- Overall disposition: **rejected / blocked before live journey**
- Player timer: not started
- Product code changed: no
- Production or other-lane state touched: no

## Gate results

| Criterion | Result | Evidence / reason |
| --- | --- | --- |
| Exact candidate ancestry and clean merge | passed | `manifest.md` |
| Lane-specific identity declaration | passed | `--print-identity`; `manifest.md` |
| Static diff and script syntax | passed | `automated-validation.md` |
| Full native suite | passed | 78/78 in `automated-validation.md` |
| Frozen canonical digest agreement | **failed** | D003; published `fe710ac9…`, repeated actual `7b6454ec…` |
| Complete pre-published digest inventory | **blocked** | Required tick-4, partial/awarded, undo, and horizon constants absent from candidate handoff |
| D001 onboarding retest | blocked / remains open | Critical fingerprint stop occurred before staged launch; not marked fixed |
| D002 compact retest | blocked / remains open | Critical fingerprint stop occurred before staged launch; not marked fixed |
| 32-command live reconciliation and system routes | partial | Eight catalog tests passed; live pointer/keyboard/FKA/modal equivalence not started |
| Isolated save/resume, undo, recovery, two-candidate proof | blocked | Trustworthy expected checkpoint set unavailable after preflight failure |
| 20-minute uncoached journey | blocked | Frozen preflight prohibits starting the timer |
| Visual, AX/focus, journey timing evidence | not run | No live session was validly opened |

## Disposition rationale

The independent run did not substitute a green test count for the frozen acceptance contract. The deterministic digest mismatch is critical and repeatable, and the required expected-digest catalog is incomplete. Continuing into D001/D002 or the golden session would mix evidence gathered after a failed identity/fingerprint precondition and could not accept the wave.

Integration should retain D001 and D002 as open and return D003 to the simulation-platform/integration evidence owner. A later candidate must identify an exact commit, publish the complete authorized digest set before execution, and receive a fresh independent run; this record must not be edited to make that candidate pass.
