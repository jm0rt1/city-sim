# PLAY-050-D001 — Blocking onboarding advances the city

- Severity: Priority 2
- Owner lane: UI and input
- Candidate: `c4460255ca810ce4de878f20f98a883983cf3dbd`
- Reproducibility: reproduced once through explicit first-run preference state
- Requirement impact: PRD-005, UX-008, session continuity

## Start state

Staged `dist/CitySim.app`, regular proof window, welcome preference false, normal fresh-city simulation speed.

## Steps

1. Launch the staged app with the welcome surface enabled.
2. Do not select Start Building.
3. Observe the day and HUD values behind the blocking welcome surface.
4. Continue waiting, then dismiss and pause.

## Expected

The player reads onboarding from a stable starting city and begins the first-decision clock from the authored starting state.

## Actual

The welcome surface was visible at Day 19, and the city continued to advance to Day 42 before dismissal and pause. Treasury, residents, jobs, approval, objective progress, and notices changed without player agency.

## Evidence

- `../visuals/first-run-day19-onboarding.jpg`
- Accessibility state reported Day 19 while `Start Building` remained available.
- Later paused state reported Day 42.

## Player impact

The first-run journey does not begin from a stable golden city. A player who reads onboarding slowly receives a materially different economy and objective state from a player who dismisses immediately, invalidating the two-minute decision measure and deterministic starting pressure.

## Limitation

The welcome preference was forced false to expose the surface after launch because the local profile had previously completed onboarding. A clean-profile harness is still required for release-grade reproduction.
