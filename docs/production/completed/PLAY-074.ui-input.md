# PLAY-074 Completion — Make Building and Recovery Obvious on the Map

- **Lane:** UI and input
- **Branch:** `codex/citysim-ui-input`
- **Status:** ready-for-independent-quality-review
- **Published authority:** `e38059e721dae05c8df421754e3cb63ddf3fa153`
- **Baseline-audit commit:** `deeca72f44d38921d23a5b67d5c6917b96cd4caf`
- **Product candidate:** `93693d0125f6cdd9ee660ea918891c23ed76bb4d`
- **Evidence root:** `docs/production/evidence/PLAY-074/candidate-93693d0/`

The evidence/completion commit containing this record is reported in the lane
handoff because a commit cannot embed its own identity.

## Outcome

The map-first build loop now answers the decision before commitment:

- what is selected and where it will land;
- its footprint, construction cost, and upkeep;
- whether it is available and the accepted reason when it is not;
- the likely consequence from existing authoritative constants;
- how to cancel without changing the city;
- the one honest existing command that starts recovery.

Blocked Return attempts continue through the existing store-owned durable
rejection. Occupied targets route to Bulldoze, road-required targets route to
Road, and unaffordable targets route to Finances/Tax Policy. A valid visible
commit uses the existing map-primary intent once. The implementation adds no
command, rule, target, renderer behavior, or persistence truth.

## Verification

- New focused tests: **2/2 passed**
- `CityCommandCatalogTests`: **45/45 passed**
- Complete native suite: **242/242 passed**
- Exact staged candidate verify: passed
- Regular binding frame: 1278 x 768, **463 px map aperture**
- Compact binding frame: 900 x 652 with exact 900 x 600 content,
  **362 px / 60.3% map aperture**
- Pointer recovery and valid commit, Return rejection, Escape, guide, macOS
  menu, FKA Space, AX/VoiceOver-critical semantics, and Reduce Motion:
  retained in the evidence ledger
- Undo and save/load continuity: passed
- `git diff --check` and repository shell syntax: passed
- Candidate process: stopped; zero matching process at handoff

Known limitations and the transient-free, candidate-bound evidence inventory
are recorded in `VALIDATION.md`. No contract blocker remains.

## Integration-return viewport settlement

- **Accepted return base:** `f8124286f0b12a8433dc5d58d467909cba37e4e5`
- **Viewport product repair:** `6bb06ee291fe3e7cac8ea7b7c74e367033650ab5`
- **Evidence root:**
  `docs/production/evidence/PLAY-074/candidate-6bb06ee-viewport-repair/`

The returned compact LOD defect was a SwiftUI measurement defect, not a
renderer-fit defect. Valid live HUD frames now supersede startup fallback
floors, animated closed/decision/Details transitions publish their settled
current frames, and Focus City retains the pre-focus measurement until the
restored chrome reports.

At exact 900 x 600 content, visible map height is now 416 px closed, 362 px
with the active build decision, 304 px with Details open, and 416 px after
close. The corresponding renderer-safe heights are 396 / 342 / 284 / 396 pt.
Regular deterministic outputs are 554 / 510 / 410 / 554 pt. Selected City
Hall block 12,12 and its active Residential rejection remain visible and
authoritative throughout the transition journey.

Focused tests passed 5/5 and the repeated complete suite passed 243/243. The
exact staged candidate passed verification; FKA Space, topmost Escape, the
live accessibility tree, Focus City continuity, and Reduce Motion were
retained. No renderer, gameplay, simulation, command, save, undo, or package
surface changed. The evidence commit containing this addendum is reported in
the lane handoff because a commit cannot embed its own identity.
