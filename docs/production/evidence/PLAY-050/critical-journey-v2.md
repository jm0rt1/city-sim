# PLAY-050 Critical Journey v2 — Town Charter Contract

**Status:** Frozen amendment before PLAY-010 integration execution

**Task:** `PLAY-050`

**Authority:** `CONTRACT-001` at `87e83355058e0a5b54bf0a261bd8adde45545bb0`

**Minimum candidate:** Integrated commit containing both `CONTRACT-001` and accepted PLAY-010 implementation

## Inheritance

This journey inherits every player brief, timed phase, input/layout/accessibility variant, operational definition, threshold, and stop condition from [critical-journey-v1.md](critical-journey-v1.md). It replaces only the generic Town Charter milestone check with the exact durable-progression criteria below.

Do not execute this journey against the baseline or a standalone PLAY-010 worker commit. Integration must first identify the exact candidate commit and confirm that the approved contract and implementation are both present.

## Authoritative Town Charter behavior

The golden-session fixture and evidence must prove:

1. Qualification is evaluated only at daily simulation boundaries.
2. Award requires 12 consecutive qualifying daily checks.
3. A failed qualifying check resets progress to zero.
4. A later uninterrupted 12-check sequence can still earn the Charter after a reset.
5. The Charter awards exactly once and emits exactly one `Town Charter Awarded` message.
6. Once awarded, later failed checks do not revoke the Charter or repeat its reward/message.
7. Save/load, JSON round trip, and existing undo preserve the exact progression state.
8. Legacy state without `progression` decodes, remains readable, and normalizes to zero/not-awarded at the next daily boundary.

PLAY-050 does not define the economic qualification thresholds. The accepted PLAY-010 scenario must expose those standards, their current values, and their failure cause without developer coaching.

## Golden-session checkpoint sequence

| Checkpoint | Required state and player-facing result |
| --- | --- |
| Start | Fixture ID/version/seed/hash recorded; Town Charter not awarded; current consecutive-check count explicit. |
| First qualifying boundary | Count increments by exactly one and the interface explains why the day qualified. |
| Eleven qualifying boundaries | Count is 11; no award, reward, completion, or award message exists. |
| Reset branch | A named standard fails at a daily boundary; count resets to zero and the failed standard is discoverable. |
| Recovery branch | Player diagnoses and corrects the failure, then begins a new qualifying sequence. |
| Twelfth consecutive boundary | Count reaches 12; Charter awards once; one stable-title message appears; durable objective state and reward are comprehensible. |
| Post-award failed boundary | Award remains true and no second reward/message appears. |
| Save/resume | Pre-award partial progress and awarded state each round-trip exactly; loaded simulation is safe to inspect. |
| Undo | Existing snapshot undo restores the exact pre-command progression count/award flag represented by the fixture. |
| Legacy decode | Missing optional progression loads successfully and normalizes only at the next daily boundary. |

The timed primary session may use an authoritative fixture positioned close enough to the qualification window to reach the Charter within 20 minutes, but it may not skip or synthesize the 12 daily checks. Reset, legacy, exact round-trip, and post-award idempotence may use focused deterministic branches from named checkpoints.

## Critical failures

Reject the candidate if any of the following occurs:

- award before the twelfth consecutive qualifying daily check;
- award from a transient intra-day spike;
- failure to reset after a non-qualifying daily check;
- inability to qualify after recovering from a reset;
- duplicate award, reward, or `Town Charter Awarded` message;
- revocation after the Charter is awarded;
- save/load, JSON round trip, state hash, or undo changes the progression state unexpectedly;
- legacy payload decode failure or normalization before/after the wrong boundary;
- objective, message, HUD, or inspector disagrees with authoritative progression;
- the player cannot explain the current count, failed standard, recovery action, or awarded state without coaching.

## Required retained evidence

- exact integrated candidate commit and staged-app identity;
- authoritative fixture manifest and state hashes at start, 11, reset, recovered sequence, 12, post-award failure, save/load, undo, and legacy normalization checkpoints;
- ordered command/daily-boundary trace;
- proof that no award message exists at 11 and exactly one exists at and after 12;
- real-app captures of progress, reset explanation, recovery, award, and resumed awarded state;
- pointer, keyboard, 900×600 compact, Reduce Motion, and declared VoiceOver/Full Keyboard Access dispositions for the progression path;
- criterion dispositions and reproducible defects returned to their owning lanes.
