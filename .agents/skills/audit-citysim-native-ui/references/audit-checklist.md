# CitySim Native Audit Checklist

Use this checklist as coverage guidance, not as a source of expected findings. Record what the current build actually does.

## Session evidence

- Date, commit/working-tree state, app bundle identity, window size, saved-city state.
- Initial speed, overlay, inspector, objectives, and visible event count.
- Default-layout screenshot and at least one constrained-layout screenshot when capture is available.
- Accessibility tree before interaction, while running, and while paused.

## Player flows

### Orientation

- Can a first-time player identify the city, treasury, population, happiness, employment, objectives, and current speed?
- Is the primary next action obvious without reading persistent instruction text?
- Does map content retain visual priority?

### Build

- Select road, zone, infrastructure, and service tools.
- Check selected state, hover/footprint preview, validity, affordability, upkeep, road and utility requirements, cancellation, result feedback, and undo.
- Check behavior over open, occupied, invalid, and edge tiles without making irreversible changes.
- Check build-tool discovery at narrow widths and with keyboard navigation.

### Inspect and diagnose

- Open each top metric and verify labels, denominators, and actions.
- Select a building and open city-wide and tile-specific information.
- Follow an objective and an event into the relevant inspector section.
- Switch every data overlay, read its legend, locate its reset state, and assess map legibility.

### Time and feedback

- Exercise pause and every speed.
- Observe whether event volume, repeated messages, feedback toasts, and changing metrics remain comprehensible.
- Check whether notifications obscure intended map actions and whether their dismiss controls are contextual.

### Window and input

- Inspect regular, minimum, and narrower practical layouts where allowed.
- Check inspector/objectives open and closed combinations.
- Test mouse/trackpad pan and zoom, Escape cancellation, Tab focus, menu commands, and documented shortcuts.
- Verify destructive modes have persistent, unmistakable state and a recovery path.

## Accessibility

- Inspect names, roles, values, help text, selected/disabled state, and target uniqueness.
- Compare element identity and focus stability while paused and at maximum speed.
- Verify map tiles/buildings expose type, coordinates, status, selection, and available actions.
- Check that icons and close buttons have contextual labels.
- Check color-only communication, contrast, text size, motion, and pointer-only instructions.
- Record unverified VoiceOver, Full Keyboard Access, reduced-motion, or contrast behavior explicitly.

## Information and game-state sanity

- Compare HUD summaries with inspector details and identify denominator mismatches.
- Check consistent player-facing time units and cost/upkeep units.
- Assess whether treasury scale, costs, demand, objectives, and notifications produce meaningful decisions in the audited save.
- Separate save-specific balance observations from structural UI findings.

## Finding quality gate

Every P0/P1 finding must include:

- reproducible current observation;
- affected user and task;
- source correlation or an explicit statement that the cause is unknown;
- concrete remediation direction;
- a measurable acceptance criterion somewhere in the report.

Reject findings that are only taste, restate the UI without impact, rely solely on old reports, or claim universal behavior from one saved city.
