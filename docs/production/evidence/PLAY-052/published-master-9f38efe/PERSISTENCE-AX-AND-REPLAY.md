# PLAY-052 Persistence, AX, and Replay Evidence

## Exact live persistence

The Commercial Charter state was saved twice through the product command to
create primary and backup bytes.

- primary SHA-256:
  `bfb4a3de4b0829c194cee3fcf88944c2a13d9ae35b8989f53530e47c6020066c`
- backup SHA-256:
  `bfb4a3de4b0829c194cee3fcf88944c2a13d9ae35b8989f53530e47c6020066c`

PID `87112` was terminated. The same exact executable was relaunched as sole
PID `99563` with the same injected root. Command-O loaded the won city in
1,930 ms; the background HUD reported `PAUSED`, and the blocking result
retained 511 residents, `$11,618`, `+$126`, 61% happiness, and
**Commercial Stewardship**. See
`live-commercial/09-relaunch-load-paused.jpeg`.

For backup-only recovery, PID `99563` was terminated and the primary was moved
inside the isolated root to the preserved, non-loadable name
`quicksave.primary-preserved.json`. No save bytes were edited. The only
loadable file was `quicksave.backup.json`. Relaunch PID `1584` loaded the same
Charter result from backup; both preserved files retained the SHA-256 above.
See `live-commercial/13-backup-only-load.jpeg`.

The Industrial terminal save independently produced matching primary/backup
bytes with SHA-256
`d2e23dfc1dd6150bfd5adb7785e4be142fbc5b178046e786d14836a492552d8e`.

## Victory and Start New Region parity

The live victory AX container disclosed:

> Town Charter Secured. New Arcadia Earned Its Town Charter. Your 511
> residents sustained a solvent, fully served town. The Charter records how
> you grew and how you recovered.

Its focused action was:

> Start a New Region — Starts one fresh authored city and closes this result.

On separately restored copies of the won Commercial quicksave:

- pointer activation produced the authored Day 1 city:
  `live-commercial/10-new-region-pointer.jpeg`;
- focused Return activation produced the identical authored Day 1 city:
  `live-commercial/11-new-region-keyboard-return.jpeg`;
- focused semantic Space activation produced the identical authored Day 1
  city:
  `live-commercial/12-new-region-ax-space.jpeg`.

The result action was the focused AX button in both keyboard routes. The
Industrial victory independently exposed the same semantic action and the
distinct story text:

> Industrial Expansion. Freight and industry led the city's growth, creating
> jobs while demanding deliberate utility and livability choices. Recovery ·
> Utility Expansion.

## Four durable recovery routes

The two live routes are the required non-fixture journeys. The exact published
product's full suite supplements them with all four durable formal recovery
branches:

- Commercial Tax Relief;
- Commercial Public Realm Investment;
- Industrial Utility Expansion;
- Industrial Green Buffer.

The authoritative run passed:

- `GameplayLoopTests.testAllFourDurableResolutionsReachTownCharterInsideTwentyMinutes`;
- `GameplayLoopTests.testCommercialSetbackSupportsTaxReliefAndParkRecovery`;
- `GameplayLoopTests.testIndustrialSetbackSupportsUtilityAndGreenBufferRecovery`;
- `StrategyResolutionPlatformTests` — 6/6, including exact backup, digest,
  replay, save/resume, undo, and snapshot agreement for every resolution;
- `TerminalVictoryPlatformTests` — 2/2, including all four terminal routes.

The four frozen terminal digests from that exact run were:

| Resolution | Terminal digest |
|---|---|
| Commercial Tax Relief | `d34d24c739e92c61e0396c3218bde1a56ef16bba6b7ed68ba354f74a601ec6a1` |
| Commercial Public Realm Investment | `de5e7c9200f02f044a1798cf29587d9de41b2de74eb7a8853739b14e0918f6b5` |
| Industrial Utility Expansion | `7354b7cbdb9fc8d2e599d2057769a41e619b702d7d4940c329e644604439929c` |
| Industrial Green Buffer | `98daef105054ac7f672bb2d5211b9011c0893745ffcbcd81e8ea10a80073cb38` |

These are deterministic supplements, not substitutes for the two retained
hands-on journeys.

## Replay-value finding

**Explicit finding: replay value is present and material.** The live
Commercial route paid for utility recovery through storefront margin and won
more slowly with higher happiness. The live Industrial route created jobs and
cash faster, but forced larger utility capital and upkeep decisions and ended
with lower happiness. The alternate tested branches add a second recovery
identity to each strategy: tax relief trades demand/happiness for liquidity,
public-realm investment spends for livability, utility expansion buys reserve,
and green buffer mitigates industrial externalities. These are observable
tradeoffs, not four labels over one outcome.
