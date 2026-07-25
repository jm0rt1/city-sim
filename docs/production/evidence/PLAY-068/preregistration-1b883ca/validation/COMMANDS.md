# PLAY-068 Preregistration Validation

All commands ran from the quality worktree at exact published authority
`0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`.

## Startup, ancestry, and parity

```text
pwd
git branch --show-current
git status --short --branch
git rev-parse HEAD
git merge-base --is-ancestor 1b883ca HEAD
git diff --quiet 1b883ca..HEAD -- Native/CitySimNative script/build_and_run.sh
```

Results: exact worktree, expected lane, clean initial status, exact authority,
ancestor exit `0`, and product/build parity exit `0`.

## Staging and resource identity

```text
./script/build_and_run.sh --verify
```

Result: passed at exact authority. The script reported the quality candidate
ID, bundle/defaults/data identities, bundle, executable, resource bundle,
manifest, and PID. The manifest is retained at
`identity/staged-baseline.manifest`.

```text
cmp -s \
  Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json \
  dist/CitySim-playtest-quality-wf967be0ab5b4.app/CitySimNative_CitySimNative.bundle/WorldAssets.atlas/generated-v4-manifest.json
```

Result: exit `0`; both SHA-256
`4aac94eb37ec3a17dc345177519a1e5d43b284ede870170e12ca6a9bf0521bd8`.

## Live baseline

Each route used `/usr/bin/open -n` with exact staged bundle, isolated
`CITYSIM_DATA_ROOT`, explicit regular or compact window, optional proof scale,
and optional Reduce Motion proof. Computer Use loaded the quicksave, allowed
transients to expire, selected the exact block, operated pointer and keyboard
surfaces, and retained original screenshots plus full AX trees.

`ps eww` bound each route to exact PID, executable, root, window mode, scale,
Reduce Motion state, and RSS. Every exact quality PID was terminated with
SIGTERM.

## Accepted baseline performance authority

The byte-identical product's accepted independent PLAY-063 evidence is:

- `docs/production/evidence/PLAY-063/candidate-f928696/VALIDATION.md`
- `docs/production/evidence/PLAY-063/candidate-f928696/IDENTITY.md`

It records focused 55/55, full 226/226, staged verify, deterministic pack,
zero geometry collisions/fallbacks, 41,943,040-byte repeated LOD high-water,
cold/update profiles, 4,286-pulse soak, and bounded RSS. PLAY-068 does not
reinterpret these values as new contract ceilings.

## Final packet checks

```text
git diff --check
test "$(wc -l < ledgers/aperture-matrix.csv)" -eq 7
test "$(wc -l < ledgers/post-charter-strategy-routes.csv)" -eq 7
test "$(wc -l < ledgers/activity-public-realm-truth.csv)" -eq 11
find live -type f -name '*.jpg' -print0 | xargs -0 sips -g pixelWidth -g pixelHeight
shasum -a 256 <all retained packet files>
git status --short --branch
```

Expected: clean diff, exact ledger schemas, regular 1278 x 768, compact
900 x 652, distinct city/neighborhood/block hashes, complete `SHA256SUMS`, and
a clean worktree after the focused PLAY-068 commit.
