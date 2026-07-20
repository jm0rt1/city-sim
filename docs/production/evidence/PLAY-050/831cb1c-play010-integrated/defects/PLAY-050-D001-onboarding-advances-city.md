# PLAY-050-D001 — Blocking onboarding still advances the integrated city

- Severity: Priority 2
- Owner lane: UI and input
- Candidate: `831cb1c11d3a26883cf40a11a5af87f7e94176d0` containing accepted PLAY-010 baseline `f96ff8022ee12e0ac32f0250621993d23f2f0d23`
- Reproducibility: reproduced again through an explicit stopped-process first-run preference state
- Original reproduction: `c446025-baseline/defects/PLAY-050-D001-onboarding-advances-city.md`
- Requirement impact: PLAY-050 decision-by-02:00, false feedback, deterministic golden start, UX-008/session continuity

## Start state

Repository-staged `dist/CitySim.app`, regular window, no quicksave, original local preference recorded, staged process stopped, then only `hasSeenCitySimWelcome` set false before launch.

## Steps

1. Launch the staged bundle with the first-run welcome surface enabled.
2. Do not select `Start Building` while reading the mandatory welcome content.
3. Observe the Day value, objective, treasury, utility spare, and notice count behind the blocking surface.
4. Select `Start Building`, then Pause.

## Expected

The authored golden city remains unchanged until the player dismisses blocking onboarding. The two-minute first-decision clock starts from one deterministic state.

## Actual

The first full accessibility state reported Day 4 while `Start Building` was still present. The retained capture shows Day 17 with five notices. A later state reached Day 27 with eight notices before dismissal. Dismissal returned at Day 31, and Pause took effect at Day 36. Treasury, residents, cashflow, utility spare, objective progress, and notices all changed without player agency.

The integrated pressure loop increases the impact: the player can accumulate budget/reserve/hiring consequences before gaining control, so reading speed changes the starting problem.

## Evidence

- `../visuals/first-run-day17-onboarding.jpeg`
- Screenshot SHA-256: `f5e45e1911c711a7074f49fc9cdf2b403088aeea8c8df984ea1fb628a9b750e4`
- AX checkpoints: Day 4, Day 27, dismissal Day 31, paused Day 36

## Player impact and disposition

Critical PLAY-050 precondition failure. A fresh session cannot measure first decision, confusion, dead time, recovery, or strategy from a stable golden city. The integrated candidate is rejected independently even though the deterministic simulation tests pass.

No product fix was made in PLAY-050.
