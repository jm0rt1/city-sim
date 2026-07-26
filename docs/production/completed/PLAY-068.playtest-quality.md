# PLAY-068 Completion — Closed Rejected and Superseded

## Disposition

- **traceDisposition:** `CLOSED_REJECTED_SUPERSEDED`
- **skillResult:** The candidate-blind Wave 008 gate preserved a rejection
  checkpoint; it did not produce an accepted release.
- **productBehavior:** Exact candidate
  `87e1e682566b68d20deb1a9e2028e2b885e0423a` remains unaccepted.
- **mutation:** Integration-management documentation only. No product,
  rejected evidence, or quality-branch history changed.

## Preserved authority

- Quality branch: `codex/citysim-playtest-quality`
- Quality worktree:
  `/Users/James/.codex/worktrees/71b0/city-sim`
- Clean preserved rejection checkpoint:
  `776cc9b7dfd9532bbf9eee09aca3359373b875a7`
- Candidate admission ancestor:
  `6e1d337`
- Candidate-blind preregistration integrated through:
  `1f63129`

The preserved checkpoint records an incomplete combined gate and retains its
candidate-bound evidence on the quality branch. Integration does not reinterpret
that material as an acceptance and does not need to copy the rejected binary
evidence into `master` to preserve it.

## Supersession

Wave 009 materially changes gameplay growth, deterministic visible-city
fixtures, renderer composition, and UI/input behavior. Continuing a stalled
fresh retest against the obsolete Wave 008 binary would not dispose the Wave
009 release. The fresh retest was therefore stopped without new evidence or
product mutation.

PLAY-075 is the only next release-quality authority. It keeps its stricter
20/20 bar, every category at 4/4, zero P0/P1 defects, zero automatic rejects,
and material preference over `87e1e68`.

## Integration consequence

This record closes the PLAY-068 workflow as rejected/superseded so it no longer
blocks PLAY-075 preregistration. It does **not** authorize PLAY-075 scoring
until integration supplies an exact combined candidate that has first cleared
integration's own real-app preflight.
