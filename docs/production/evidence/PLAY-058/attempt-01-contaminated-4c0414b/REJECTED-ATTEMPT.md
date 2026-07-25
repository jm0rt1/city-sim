# PLAY-058 Baseline Attempt 01 — Rejected

- **Product authority:** `4c0414b003a178948c62128f425b6d534ac2e7a7`
- **Claim/source head:** `22f6d7c6422d88ad0c3ef2fc95eb70050e575cec`
- **Disposition:** preserved but not binding

This attempt is rejected because `baseline-regular-block.png` contains an
expiring `Action cancelled` toast and other frames may retain load/action
toasts. Those transients obscure world/HUD pixels and cannot be reproduced at
an exact future candidate checkpoint.

The dark `Utilities` control inside the freight-strategy band is not a
contaminant. It is the legitimate persistent priority action and must remain
visible in baseline and candidate truth.

The first `stage-only` run is also retained as
`validation/stage-only-sandbox-failure.log`; it failed on sandboxed `ps` and
Swift module-cache access and left a stale prior manifest. The successful
follow-up stage proved the exact current claim head, but its captures remain
nonbinding because of the transient contamination above.

No image in this directory may be reused as the accepted preregistration
baseline or candidate score.
