# PLAY-050 Wave 002 Candidate Manifest

**Status:** Required template for an integration-supplied candidate

**Authority:** `CONTRACT-004` at `efe23eeeaf0eec6c975dfead07fd8b8394f840e3`

Copy this template into the candidate run directory and replace every blank with observed output. Do not begin the player timer while any required identity field is blank or ambiguous.

## Repository and build identity

- Accepted integration base:
- Candidate branch:
- Candidate full commit:
- `git merge-base --is-ancestor <accepted-base> HEAD` result:
- Pre-build `git status --short --branch`:
- Post-build `git status --short --branch`:
- Build invocation:
- Build/verify stdout proof path:
- Staged bundle path:
- Executable path:
- Executable SHA-256:
- `Info.plist` SHA-256:

## Isolated application identity

- Bundle identifier:
- Display name:
- Preference domain:
- `CITYSIM_DATA_ROOT` exactly as launched:
- Canonicalized data-root path:
- Data-root ownership/preflight state:
- Launch timestamp with timezone:
- Launch arguments and test-isolation flags:
- Exact PID:
- Exact process command/path:
- Verification method and output:
- Stop method and output:

For a worker branch, the bundle identifier must be a sanitized lane-specific descendant of `com.jfmortensen.citysim`, the display name must visibly distinguish the lane, and the data root must be lane-specific under this worktree's ignored `dist/test-data/`. The preference domain must not equal another active candidate. The exact process path/PID must resolve to the staged bundle above. A global process-name lookup or kill is insufficient.

## Fixture and session identity

- Journey version:
- Fixture ID/version/seed:
- Fingerprint version:
- Expected start digest:
- Actual start digest:
- Progression nil/zero state:
- Window size and scale:
- Input variant:
- Accessibility settings:
- Tester allowed knowledge:
- Session start/end:

## Data-root inventory

Record relative path, byte size, SHA-256, and role for every primary, backup, temporary, corrupt-preservation, diagnostic, or fixture file created in the isolated root. No path may escape the root. Record the production Application Support path as read-only preflight only; do not use it for the candidate run.

| Relative path | Size | SHA-256 | Created/modified checkpoint | Role |
| --- | ---: | --- | --- | --- |
| | | | | |

## Two-candidate isolation proof

Stage and launch candidate A and candidate B simultaneously. Neither may be `master` production state unless integration explicitly supplies an isolated master flag. Record exact identities before changing state.

| Check | Candidate A | Candidate B | Pass condition |
| --- | --- | --- | --- |
| Branch/full commit | | | Exact and intentionally distinct or explicitly identical control |
| Bundle identifier/display | | | Unique identifiers and visibly distinguishable names |
| Preference domain | | | Unique domains |
| Data root | | | Disjoint canonical paths under their owning worktrees |
| Bundle/executable path | | | Resolves to each staged candidate |
| PID/process command | | | Exact and simultaneously alive |
| Welcome dismissed in A | changed | unchanged | No preference leak |
| Reduce Motion toggled in A | changed | unchanged | No preference leak |
| Save created in A | present | absent | No data-root leak |
| Diagnostics changed in A | changed | unchanged | No preference/data leak |
| Stop/verify A | stopped | alive | No global process targeting |
| Relaunch both | own state | own state | Each resolves to its own bundle/root |

## Stop conditions

Classify the run `blocked` before interaction if the commit, bundle, executable, preference domain, data root, or process is ambiguous; the root escapes `dist/test-data/`; another lane's state appears; production preferences/save paths would be touched; verification relies on global `pkill -x CitySimNative` or ambiguous bundle lookup; the exact candidate changes during the run; or either simultaneous bundle cannot remain independently alive.
