# PLAY-068 Frozen Journey Protocol

## General rules

- Operate the exact integration-nominated staged app through visible pointer
  and keyboard input; lane automation may supplement but never replace played
  routes.
- Start each route with a fresh isolated data root/defaults domain and one
  exact PID. Record launch, window, manifest, executable, root, seed, state
  digest, and timestamps.
- Do not use developer fixtures, implementation notes, hidden thresholds, or
  coaching during the no-coaching route.
- Pause only to write evidence. Exclude evidence-writing time from elapsed
  player time and retain both timestamps.
- Record every confusion, false affordance, dead-time interval, causal
  hypothesis, meaningful decision, setback, recovery, milestone, and terminal
  result in `ledgers/no-coaching-journey.csv`.

## NC-1: fresh no-coaching 20-minute journey

Timer starts when Welcome becomes visible.

1. Dismiss Welcome through the player's chosen visible route.
2. Establish map focus and make the first meaningful strategic decision.
3. Build, diagnose, and commit either Commercial or Industrial without being
   told which strategy to choose.
4. Reach Town Charter, observe that play continues, encounter a warned
   second-act pressure, make a recovery choice, and reach meaningful
   post-Charter play, Regional Capital recognition, or an explicit truthful
   loss inside 20:00.
5. Use at least one pointer placement, one keyboard selection/action, one
   command-guide search, one menu route, Details, Focus City, an overlay, undo,
   save/terminate/relaunch/load-paused, and recovery from one invalid action.

Pass thresholds:

- first meaningful decision at or before 2:00;
- no unexplained dead time over 30 seconds;
- relevant visible consequence within 15 seconds of an action or the exact
  daily boundary that contractually evaluates it;
- at least three materially different decisions;
- warning at least one useful decision interval before setback;
- a concrete recoverable failure and understandable recovery before 18:00;
- no required coaching, false feedback, unexplained terminal state, or
  milestone-as-ending behavior; and
- player can explain the final cause/effect chain and why the chosen recovery
  worked.

## C-1 and I-1: exact strategy second-act routes

Run one Commercial and one Industrial route from fresh authored starts or
integration-approved deterministic continuations. The two routes must prove:

| Checkpoint | Commercial | Industrial |
|---|---|---|
| Charter transition | Second act begins once | Second act begins once |
| Warning | Strategy-specific and actionable | Strategy-specific and actionable |
| Setback | Commercial pressure, no unrelated penalty | Industrial pressure, no unrelated penalty |
| Primary recovery | Concrete, affordable, causal | Concrete, affordable, causal |
| Alternate recovery | Viable and meaningfully different | Viable and meaningfully different |
| Qualification | Exact consecutive daily checks | Exact consecutive daily checks |
| Failure | Next daily boundary resets progress | Next daily boundary resets progress |
| Recognition | Regional Capital once | Regional Capital once |
| Persistence | undo/save/load/backup/replay exact | undo/save/load/backup/replay exact |

The primary recovery is played. The alternate recovery must be independently
exercised at least through recovery and qualification; deterministic
automation may establish repeated checkpoints but cannot replace visible
pointer/keyboard initiation and real-app consequence.

## Qualification boundary checks

For each strategy retain:

1. state immediately before the first qualifying daily boundary;
2. eleven consecutive qualifying checks with no award;
3. the exact final required check and one-time award;
4. one failed standard followed by reset at the next daily boundary;
5. repeated later qualification with no duplicate award;
6. undo before/after a second-act action with exact fingerprints;
7. save, terminate, relaunch, load paused with exact digest equality;
8. corrupt-primary backup recovery preserving the corrupt original; and
9. legacy decode with missing optional second-act state, followed by exact
   round trip.

## Replay-value disposition

Quality must explicitly decide whether:

- warning, setback, recovery, standards, and payoff create two recognizable
  strategic identities;
- both strategies remain viable without one being obviously dominant;
- the second act creates new planning rather than merely extending a counter;
- recovery changes later decisions rather than serving as a cosmetic label;
  and
- the player would reasonably choose a different strategy on a replay.

Failure of this finding prevents approval even if automated progression tests
pass.
