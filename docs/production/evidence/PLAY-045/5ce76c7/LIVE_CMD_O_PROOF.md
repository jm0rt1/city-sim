# PLAY-045 Live Backup-Only Cmd-O Proof

## Candidate identity

- Commit: `5ce76c783ce96fbfb958bb4388f34c5cefce2ebc`
- Candidate: `simulation-platform-w8bb1822a1e25`
- Bundle identifier: `com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25`
- Display name: `CitySim [Simulation w8bb1822a1e25]`
- Staged bundle:
  `/Users/James/.codex/worktrees/e909/city-sim/dist/CitySim-simulation-platform-w8bb1822a1e25.app`
- Isolated data root:
  `/Users/James/.codex/worktrees/e909/city-sim/dist/test-data/simulation-platform-w8bb1822a1e25`
- Relaunch proof PID: `26850`

The staged executable and exact isolated root are independently recorded by the
retained relaunch harness under `relaunch/`.

## Retained save identity

Before relaunch the isolated root contained only
`quicksave.backup.json`; there was no primary.

- File size: `131197` bytes
- File SHA-256:
  `e79dc93eb6e5a806711599de39134aaf8acdbbb8eb28fadeee1ce172f3095186`
- Schema: `1`
- Fingerprint version: `1`
- Authoritative digest:
  `413c3fcadd064b544db7d5f7fd2483f26bac1b97cbaf8e7f1ff1402c1784d2fd`
- Tick: `36` (Day 10)
- Strategy: `commercialStewardship`
- Phase: `opportunity`
- Next scheduled tick: `88`
- Recovery resolution: `nil`

The relaunch harness recorded the same sole backup, byte count, and SHA-256
after loading. No primary was fabricated or promoted and the backup was not
rewritten or deleted.

## Before-fix reproduction

The unmodified authority candidate
`ab722bd1ea7c8c132525362bc94bc12d154a78f5` was staged with the same
candidate identity. Its matching valid primary was moved to a recoverable
temporary location while the valid backup remained in the isolated root.

- Pressing Cmd-O did not load, pause, or show recovery feedback.
- File menu accessibility state exposed `(disabled) Load City`.
- The backup SHA-256 remained unchanged.
- Exact staged PID `9895` was terminated after reproduction.
- The preserved primary was restored after reproduction.

## Repaired exact-app journey

1. `./script/build_and_run.sh --verify` staged and launched exact commit
   `5ce76c7`; manifest PID was `25790`.
2. The matching primary was moved to a recoverable temporary location, leaving
   only the valid backup above.
3. `script/persistence_relaunch_gate.sh start` terminated only PID `25790` and
   relaunched the same bundle compact against the exact isolated root as PID
   `26850`.
4. File menu accessibility state exposed enabled `Load City`.
5. Loading restored Day 10, selected Pause, disabled Undo, and exposed:
   `Recovered last known-good city · Simulation paused`.
6. The recovery feedback was dismissed and 1x was selected so the session was
   running again.
7. Cmd-O restored Day 10 again, selected Pause, disabled Undo, and reproduced
   the exact existing recovery feedback.
8. `script/persistence_relaunch_gate.sh finish` recorded post-load inventory
   and terminated only proof PID `26850`.
9. The temporarily preserved primary was restored only after evidence capture
   so the retained local proof root was returned to its prior state.

## Accessibility evidence

The post-Cmd-O accessibility tree exposed:

```text
Open New Arcadia command center, Value: Day 10
Pause simulation, Value: Selected
Action update, Value: Recovered last known-good city · Simulation paused
Undo, disabled
```

This is an accessibility-tree command proof, not a claim of a spoken VoiceOver
session.
