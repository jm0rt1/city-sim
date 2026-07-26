# PLAY-027 Industrial L2 East shadow-disabled isolation

`FINAL_DISPOSITION: FAIL_REPEAT_IDENTITY`

Three and only three fresh East V06 diagnostic processes ran from clean authority
`272bd40e00a4c30d06f1ac37abf09ddc18aac345`. The sole independent variable was
`--diagnostic-scene-shadows disabled`. Descriptor, materials, camera, lighting,
registration, contact polygon, authored southeast footprint-shadow vector,
no-MSAA factor-4 sampling, software Lanczos 0.25, quantizer, compositor, and
canonicalizers remained bound to their retained hashes.

The diagnostic does **not** converge:

- run A: raw `42da0ddd644a81439f2ae48ff9adbf7b0dbed86e5f7e27e00cfec5f024151206`
- run B: raw `37155157f2f7f3c7374b4cd5567168d5c22daa7eb6e42ef23d894dd2c1a09b5e`
- run C: raw `37155157f2f7f3c7374b4cd5567168d5c22daa7eb6e42ef23d894dd2c1a09b5e`

Run A differs from B/C by exactly 97 decoded pixels and 105 RGB channels inside
source bounds `[792,856,840,884]`; alpha is identical and the maximum channel
delta is 32. B and C are exact. These are exactly the same two file identities
retained by the current-shadow completion failure, only in the opposite run
ordering. Disabling SceneKit self/cast shadows therefore does not remove or
change the split and is exonerated as its sole cause.

The single bound comparison sheet places the approved East V05 primary beside
all three diagnostic outputs. It discloses the visual delta without authorizing
a descriptor revision or source selection.

No lighting or broader probe ran. No descriptor revision is proposed because
the binding `3/3 exact` precondition failed. South/West repeats, normalization,
catalog work, source authority, and production selection remain blocked.
