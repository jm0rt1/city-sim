# PLAY-052 Wave 005 baseline admission — BLOCKED

Date: 2026-07-22

This is an interim admission check against the frozen Wave 005 baseline. It is not the PLAY-022 renderer disposition and not the final integrated PLAY-043/037/014/044 disposition.

## Exact candidate identity

- Product commit: `52fc2c17643e7987f78bc360196599e3297967da`
- Staged bundle: `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/CitySim.app`
- Executable SHA-256: `eae6e8b0c7884cdcbb425a78bd591b1023797316d1170a108f219b52c765b7e0`
- Manifest SHA-256: `a9e868577b8ae668f0e47d054dd559674db1774e07184f9d32b109e47b173830`
- Manifest commit: exact `52fc2c17643e7987f78bc360196599e3297967da`
- Manifest identity: production bundle identifier and preferences `com.jfmortensen.citysim`, `candidate_id=master`, `data_root=production-default`
- Initial default PID: `59230`, exact manifest executable, initial observed RSS `152480 KiB`
- Explicit compact PID: `69564`, exact executable, `CITYSIM_COMPACT_WINDOW=1`, no data-root substitution, initial observed RSS `747744 KiB`
- Exact-PID cleanup: both `59230` and `69564` terminated; no process remained for the supplied production bundle path.
- Quality branch after normal baseline merge: `c022dfd25281b29db3b955fb5c0c14e9555da107`; both `52fc2c1` and prior evidence commit `dc07390` are ancestors.

## Admission results

| Criterion | Default | Explicit compact | Result |
|---|---|---|---|
| Invalid Return retains exact accepted reason beyond four seconds | `4.895 s` | `4.986 s` | PASS |
| Commercial remains selected | Yes | Yes | PASS |
| Selected occupied City Hall remains selected and unmodified | Yes | Yes | PASS |
| Fresh `tax`, `budget`, `storefront` search results | Guide could not be opened | Guide could not be opened | BLOCKED |
| Pointer activation | No reachable result | No reachable result | BLOCKED |
| Return activation | No reachable result | No reachable result | BLOCKED |
| Space activation | No reachable result | No reachable result | BLOCKED |
| AX Press activation | No reachable result | No reachable result | BLOCKED |

## Accepted PLAY-035 live check

Starting from a paused production-default city, the player selected City Hall block 12,12 in Inspect, switched to Build → Commercial without moving the selected target, then pressed Return.

Default after `4.895 s` and explicit compact after `4.986 s` both retained:

- `BLOCKED · COMMERCIAL`;
- `Demolish the existing structure before building here.`;
- visible `SELECTED` state;
- Build mode and `Selected Commercial` in AX;
- no construction, treasury mutation, or Undo availability.

PLAY-035 therefore passes this admission in both required layouts.

## Blocking PLAY-036 defect

Severity: P1 admission blocker

Owner: UI/input, PLAY-036 integration

### Reproduction

1. Launch the exact staged production bundle at the frozen manifest identity.
2. Dismiss any topmost surface and inspect the live command deck and macOS title toolbar in default mode.
3. Inspect the full AX tree for `Open command guide` or a `Commands` toolbar control.
4. Press Command+/ using the Command modifier and the `slash` key.
5. Repeat with a newly launched exact executable carrying only `CITYSIM_COMPACT_WINDOW=1`.

### Expected

The persistent command deck or title toolbar exposes the Commands entry point; Command+/ opens a fresh Command Guide. Fresh `tax`, `budget`, and `storefront` queries each produce the sole truthful Tax Policy result, and pointer, Return, focused Space, and AX Press activate it in both default and compact.

### Actual

- Neither default nor explicit compact exposed a visible Commands control in the persistent command deck.
- The title toolbar exposed Objectives, Command Center, Save, and Undo, but no Commands control.
- The full AX tree contained neither `Open command guide` nor a `Commands` button.
- Command+/ did not open a sheet and left focus on the generic `SKView`.
- Eighteen default-mode Tab presses remained on `SKView`; no command control entered the focus path.
- The Help menu exposed only `CitySim Help`, which reported that help was unavailable; it did not supply the command guide.

Because the guide was unreachable, no honest fresh query or activation assertion could be made. Author-lane tests and retained screenshots do not substitute for this exact staged-app failure.

### Acceptance for repair/reintegration

Against a fresh exact production-default bundle and a separate exact compact launch:

1. expose a visible and AX-reachable command-guide entry point;
2. make Command+/ open the guide from map focus;
3. prove each guide opening starts with an empty focused query;
4. prove `tax`, `budget`, and `storefront` each return exactly one available Tax Policy result;
5. prove pointer, Return, focused Space, and AX Press each activate the existing route exactly once at both sizes;
6. retain exact PIDs, screenshots, and AX state for the integrated candidate.

## Evidence

| Artifact | SHA-256 | Meaning |
|---|---|---|
| `live/default-return-rejection-after-4s.jpeg` | `d64a5596d27aef0ab9355cdfc13284d386f1db1ad85a34f0530884485b9e64e0` | Default PLAY-035 pass and absent Commands controls |
| `live/compact-return-rejection-after-4s.jpeg` | `d3ed44fb1c4ef57918fd469ba8a1b79264226d764d93ae3964b701e27a7f2545` | Compact PLAY-035 pass |
| `live/compact-command-control-absent.jpeg` | `1a1575b2bbfa6eff82b22ac8fd7e6069165fb1c92f56e10cd99bd4bd32251820` | Compact PLAY-036 entry-point failure |

All three captures are `1278x768` Computer Use screenshots from the exact staged executable. World quality was not scored.

## Admission disposition

**BLOCKED / RETURN PLAY-036 TO UI-INPUT INTEGRATION.** PLAY-035 independently passes. PLAY-036 cannot be admitted because the exact staged app does not expose or open the Command Guide, making every governed search and activation route inaccessible. This does not accept or reject Wave 005 as a whole.
