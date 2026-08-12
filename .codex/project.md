# CitySim reset context

The active product is the Swift package at `Native/CitySimNative`.

Start with [`docs/PRODUCT_RESTART_BRIEF.md`](../docs/PRODUCT_RESTART_BRIEF.md).
Work from one bounded player-visible outcome at a time. Keep implementation,
tests, and player-visible proof proportionate to that outcome; do not recreate
agent roles, claims, routing packets, evidence ledgers, or standing operations
hierarchies unless the user explicitly asks for them.
