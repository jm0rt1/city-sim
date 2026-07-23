# PLAY-052 corrected UI pre-integration retry — candidate b4fb061

## Disposition

**BLOCKED — no product ACCEPT/REJECT disposition.** The updated Computer Use
retry still did not return a capture or AX tree for the exact isolated UI
candidate. Per dispatch, quality stopped without substituting a master bundle,
an author capture, a stale PID, or a harness-only result.

This record is separate from and does not modify the historical `94f68ac`
false-negative record. It is also separate from the renderer candidate
disposition at `docs/production/evidence/PLAY-052/renderer-2cf18b0/`.

## Frozen candidate identity

- Product: `b4fb061bd25bdbbba7c50aef31d9021a7e29efac`
- UI worktree:
  `/Users/James/.codex/worktrees/c8e2/city-sim`
- UI worktree state at retry: clean at the exact product commit.
- Bundle:
  `/Users/James/.codex/worktrees/c8e2/city-sim/dist/CitySim-ui-input-wdbeadac6e0bd.app`
- Executable:
  `Contents/MacOS/CitySimNative-wdbeadac6e0bd`
- Bundle ID: `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- Manifest SHA-256:
  `82d889a892125f4798bd4fa176412a3d405be839ddec4fafebfff87a549f5261`
- Executable SHA-256:
  `e2df85c9bd39a5e11aefbd57873074ead22980ddb276bfd07ead588b58b60b2a`

## Exact retry record

1. Process preflight found unbound exact-candidate PID `40309`. It was not
   reused; quality terminated it with SIGTERM and verified zero matching
   processes.
2. Quality targeted the exact full bundle path through Computer Use.
3. The request launched sole exact executable PID `54853`, but returned no
   screenshot and no AX tree.
4. Exact tool failure:

   `Computer Use server error -10005: timeoutReached`

5. Because no capture returned, quality could not bind an AX window to PID
   `54853` and did not treat the launch itself as acceptance evidence.
6. Quality terminated PID `54853` with SIGTERM and verified zero
   `CitySimNative-wdbeadac6e0bd` processes remained.

No older PID, older screenshot, master app, author conclusion, or harness
output was substituted.

## Required matrix status

The following candidate-bound checks remain **unexecuted** in this corrected
retry because the required first live capture did not succeed:

- visible and AX command-guide entry in default and compact;
- Command-/ routing from City map;
- fresh tax search result and exact Tax Policy availability;
- pointer, Return, Space, and AX activation exactly once;
- semantic map identity/actions;
- Right and Shift-Right selection;
- Full Keyboard Access selected action;
- Command Center then Objectives topmost-first Escape order;
- exact 900 x 600 compact parity.

This is an acceptance-infrastructure blocker, not a demonstrated product
defect. A future retry must start from zero matching processes, launch exactly
one fresh PID for this same manifest/executable pair, receive a successful
candidate-bound screenshot plus full AX tree, and then run the complete matrix.
