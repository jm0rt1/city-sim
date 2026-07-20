# PLAY-050-D001 Restart 2 Retest — Failed for Modal Shortcut Leakage

## Stable authored start

Candidate A's tokenized preference domain was deleted and its injected data root was empty before launch. The authored New Arcadia start opened, but the full-window capture measured 900×652 pixels including 52 pixels of chrome rather than the frozen default 1440×900 requirement. The state invariants below therefore pass at the observed compact frame; the D001 default-frame subcriterion does not pass.

| Checkpoint | Day | Treasury / cycle | Population | Happiness / approval | Jobs | Utilities | Notices | Result |
| --- | ---: | --- | ---: | --- | ---: | --- | ---: | --- |
| T+0 | 1 | $26,000 / -$61 | 300 | 58% / 56% | 190 | 100%, P54/W48 spare | 1 | stable |
| T+10 | 1 | $26,000 / -$61 | 300 | 58% / 56% | 190 | 100%, P54/W48 spare | 1 | stable |
| T+30 | 1 | $26,000 / -$61 | 300 | 58% / 56% | 190 | 100%, P54/W48 spare | 1 | stable |
| T+60 | 1 | $26,000 / -$61 | 300 | 58% / 56% | 190 | 100%, P54/W48 spare | 1 | stable |

The welcome remained visible with `Start Building`, its goal and build/balance/diagnose copy, and the identical objective. T+10/T+30/T+60 full-window captures were byte-identical. Pointer dismissal preserved the Day 1 authored values immediately; after 2.2 seconds the app reached Day 2 with $25,939, 301 residents, and two notices, proving mutation began only after dismissal.

## Critical modal leakage

A separate reset run launched the same candidate from an empty root and deleted domain. While the welcome remained open, Computer Use sent `Space`, `1`, `2`, `3`, `B`, `V`, `Escape`, and `⌘/` in the frozen sequence.

Actual result:

1. The welcome stayed visible and authoritative Day 1 metrics remained frozen.
2. The underlying speed control changed from selected `1×` to selected `3×`, proving unmodified gameplay keys changed UI/input state through onboarding.
3. `⌘/` opened the CitySim command-guide sheet above the welcome and focused `Search CitySim commands`.
4. Closing the guide returned to the still-visible welcome with `3×` selected.

Expected: no game command or catalog-guide shortcut leaks through the blocking welcome; speed/tool state remains the authored start and only `Start Building` dismisses onboarding.

Disposition: **failed / reproduced as a new critical input facet**. The original hidden-simulation drift is not reproduced, but D001 cannot close because the modal input contract fails and the run did not open at the required default frame. Pointer dismissal passed; keyboard dismissal and first-decision timing were not credited after the critical failure.

## Visual evidence

- `visuals/d001-t00.png` — SHA-256 `5a77fdaac4538cfc3182d9b5fb5c12784c15dcd8586c93ca06e298c3e2fad63c`.
- `visuals/d001-t10.png`, `d001-t30.png`, `d001-t60.png` — shared SHA-256 `94db2ba1825b984b3b4cd2d60caec4ea84f866f47dfabb230a1714e682eae38c`.
- `visuals/d001-pointer-dismiss.png` — SHA-256 `1e384f6dc5f2c7eeb917f0c5e3f3543c22c348b493b1117fa2ba5442f9623b26`.
- `visuals/d001-first-pulse.png` — SHA-256 `08f55c336d8d42fd7228c4c8cef3f113936ca5a2fc794d7f7da7f31abdcbe746`.
- `visuals/d001-modal-leakage.png` — SHA-256 `ce691a9f1c9fa14d03622227d2ae95494e4587ce583d849cac6297e18e835282`.
- `visuals/d001-modal-underlying.png` — SHA-256 `7dcc770b849782bce7e994362c9ebd79d1427ede4c99dfd4c0dd0327c42706aa`.
