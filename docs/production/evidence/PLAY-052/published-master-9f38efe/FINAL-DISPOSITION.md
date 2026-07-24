# PLAY-052 Published-Master Final Disposition

## APPROVED

Exact candidate:
`9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`

The final published-master release gate is **APPROVED**. No P1 contradiction
was reproduced. Two independent fresh no-coaching journeys reached Town
Charter well inside 20 minutes, four formal recovery routes are deterministic
and viable, exact live persistence and backup-only recovery passed, default
and exact compact controls remained playable, and the accepted renderer score
remains 17/20.

## Gate results

| Gate | Result |
|---|---|
| Exact staged identity / sole PID per route | PASS |
| Fresh Commercial default journey | PASS — Charter at `8:34` |
| Fresh Industrial exact compact journey | PASS — Charter at `4:42` |
| First decision <= `2:00` | PASS — Commercial `1:23`; Industrial `0:46` |
| No unexplained dead time > `0:30` | PASS — passive waits <= `0:10`; longer wall intervals were paused interaction/evidence work |
| Consequence latency < `0:15` | PASS — immediate construction/rejection plus bounded numeric feedback |
| At least three meaningful decisions | PASS — Commercial at least five; Industrial six |
| Recovery before minute 18 | PASS — Commercial cashflow/water recovery before `7:11`; Industrial utility/cashflow recovery before `2:17` |
| Four durable recovery routes | PASS — exact all-four gameplay, platform, and terminal tests |
| Save -> terminate -> relaunch -> load paused | PASS |
| Backup-only recovery | PASS |
| Victory explanation / New Region pointer, Return, semantic Space | PASS |
| Default + exact compact map, command search, focus/Escape | PASS |
| One-target placement and durable rejection truth | PASS |
| Full native suite | PASS — **185/185**, 0 failures, 83.670 test seconds |
| Explicit replay-value finding | PASS — see `PERSISTENCE-AX-AND-REPLAY.md` |

The authoritative suite ran from `2026-07-23 23:55:13.804 -0400` through
`2026-07-23 23:56:37.487 -0400`. The first restricted attempt was blocked
before manifest evaluation by macOS `sandbox-exec`; the same command was rerun
with the required host permission and passed. The quality tree's product and
script paths are byte-equivalent to `origin/master`.

## Renderer preservation

No live regression was found against the accepted independent renderer
approval at `b2e318cf78c03cbe0490ba12af40a4f0a85100a3`.

| Frozen category | Preserved score |
|---|---:|
| Composition / map occupancy | 3/4 |
| Projection / material / light / road coherence | 3/4 |
| Useful city / neighborhood / block LOD and depth | 3/4 |
| Believable life / state / interaction restraint | 4/4 |
| Systemic shipping credibility / performance | 4/4 |
| **Total** | **17/20** |

The retained default and compact frames preserve the inhabited connected
crossroads, coherent road/ground/building language, readable selection and
construction states, and non-obscuring HUD. The full run's 36/36 renderer
tests passed; diagnostics reported zero asset fallback, a stable 4,286-pulse
soak, and the same bounded three-LOD resource set. No automatic-reject
condition was observed.

## Disclosed limitations

- The no-coaching Commercial city earned Charter before its scheduled formal
  complication produced a named recovery-resolution suffix. Its live
  insufficient-funds and utility setback was nevertheless recovered through
  player action. Both formal Commercial alternatives are covered by the exact
  all-four deterministic tests.
- Full Keyboard Access and semantic AX activation were exercised through the
  focused victory button and compact semantic map/guide. VoiceOver speech
  audio was not recorded; the complete AX descriptions, values, help, focus,
  and actions were retained.
- This disposition does not rescore or expand the frozen renderer rubric; it
  checks only for regression from the accepted 17/20 renderer.

## Evidence index

- `JOURNEY-CONTRACT.md` — preregistered thresholds and stop conditions;
- `CANDIDATE-IDENTITY.md` — source, bundle, manifests, resources, PIDs, and
  viewports;
- `PLAYED-JOURNEY-LEDGER.md` — timestamped decisions and consequences;
- `PERSISTENCE-AX-AND-REPLAY.md` — save hashes, relaunch/backup proof, AX
  parity, four recovery routes, and replay-value finding;
- `live-commercial/` — 13 uncropped live captures;
- `live-industrial/` — 10 uncropped live captures.

No product files were changed, no branch was pushed, and no integration action
was performed.
