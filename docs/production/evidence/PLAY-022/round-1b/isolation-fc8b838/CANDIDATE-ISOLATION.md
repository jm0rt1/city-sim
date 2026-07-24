# PLAY-022 Round 1B candidate isolation

- **Recorded:** 2026-07-22T11:51:12Z
- **Branch:** `codex/citysim-world-rendering`
- **Exact product commit:** `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`
- **Git tree:** `1277422dabd28c67469b11516ba06692f978bc1a`
- **Published authority ancestor:** `5df04fa` (`0/43` left/right to the candidate)
- **Result:** `CITYSIM_CANDIDATE_ISOLATION status=PASS`

## Method

Before verification, the canonical staged manifest recorded the exact full
commit `fc8b838d6d33ee8091ce6c54c125ea0cee279f5b`; both the working branch HEAD
and each clean disposable clone resolved to that same commit and tree
`1277422dabd28c67469b11516ba06692f978bc1a`.

Two clean shared clones were created under a unique `/private/tmp` root and the
repository verifier was run once with the required process/build permission:

```text
git clone --shared --branch codex/citysim-world-rendering --single-branch /Users/James/.codex/worktrees/cac1/city-sim /private/tmp/citysim-play022-isolation-fc8b838.r0Hf1M/candidate-one
git clone --shared --branch codex/citysim-world-rendering --single-branch /Users/James/.codex/worktrees/cac1/city-sim /private/tmp/citysim-play022-isolation-fc8b838.r0Hf1M/candidate-two
bash script/verify_candidate_isolation.sh /private/tmp/citysim-play022-isolation-fc8b838.r0Hf1M/candidate-one /private/tmp/citysim-play022-isolation-fc8b838.r0Hf1M/candidate-two
```

The complete command output and exit status are retained in
`candidate-isolation-verifier.log`. The verifier exited 0 and reported PASS.

## Exact identities

Candidate one used token `w8b84324591c2`, candidate ID
`world-rendering-w8b84324591c2`, bundle/preference domain
`com.jfmortensen.citysim.world-rendering.w8b84324591c2`, PID `39309`, and a
candidate-specific data, bundle, executable, and manifest path. Its clean build
completed in 9.24 seconds.

Candidate two used token `w0f3bd27829df`, candidate ID
`world-rendering-w0f3bd27829df`, bundle/preference domain
`com.jfmortensen.citysim.world-rendering.w0f3bd27829df`, PID `39658`, and a
second candidate-specific data, bundle, executable, and manifest path. Its
clean build completed in 8.60 seconds.

The repository verifier confirmed distinct roots, tokens, candidate IDs,
bundle identifiers, preference domains, display names, data roots, staged
bundle paths, executable paths, manifest paths, and live PIDs while retaining
the same branch and exact product commit.

## Packaged product and resource identity

Source, canonical staged bundle, candidate one, and candidate two each contain
the same 159-file world-resource inventory. All four relative-path inventories
compare byte-for-byte equal and have SHA-256
`64fa52246102f5e298bed63ec949c2504729abeccaa10f8a8849ee3f06aa4361`.
The generated-v4 manifest SHA-256 is
`900287027256d7f5ea960b7b17c9208f3ff990de532feb87448eb01328076e78`
in source and every packaged bundle.

Each app contains 162 files. Candidate executable, Info.plist, and complete
app-inventory digests differ by design because each isolated build embeds its
unique identity. Exact values and full relative-path inventories are retained.

## Preservation and cleanup

The verifier ran only from the disposable clone roots. Before and after the
run, canonical manifest/executable/Info.plist size and modification-time tuples
were identical: `982/1784720845`, `6726384/1784720845`, and
`832/1784720845`. Its staged resource inventory remained byte-identical to
source. No audit command launched, terminated, or rewrote the canonical app,
domain, data root, or any unrelated process.

PIDs `39309` and `39658` were matched to their exact temporary executables
before receiving `SIGTERM`. No process with either temporary executable name
remained afterward.

## Boundary

This evidence proves candidate identity separation and exact packaged-resource
identity at launch. It does not replace live visual, interaction, performance,
memory, accessibility, or independent-score gates.
`CONTRACT-008-active-map-action-target.md` remained identical to tracked blob
`bc519df6974c80ff9b1f2cc9e516882dd62dc407`, with empty worktree and cached
diffs for that file. No active player-intent target surface was changed.
