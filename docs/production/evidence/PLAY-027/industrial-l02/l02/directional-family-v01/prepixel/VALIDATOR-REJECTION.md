# PLAY-027 Industrial L2 directional family v01 validator rejection

Disposition: `REJECTED_PREPIXEL_VALIDATOR_FALSE_NEGATIVE`

No Metal, SceneKit snapshot, governed raw, normalization, production selection,
renderer, shipping, package, build, gameplay, simulation, UI, or save process
was consumed.

The first deterministic freeze emitted three unique, independently authored
North/South/West descriptors and then stopped. The validator incorrectly used
the thin attachment-depth axis when calculating the native-2x identity size:

- North and South door planes are `8.5 × 11` world units with `0.8` depth, but
  the validator recorded `0.8`.
- West loading-throat planes are `15 × 21` world units with `2.4` depth, but
  the validator recorded `2.4`.

This is a typed evidence-tool failure, not an art pass or source rejection. The
descriptors remain non-authority and may not be automatically reclassified.
The next attempt must use the median of each identity component's three
dimensions, which excludes one thin attachment axis without becoming
direction-dependent or relaxing the frozen six-native-pixel minimum.

Frozen hashes:

- freeze tool source:
  `f5fc56656a1bf0f9be71e459d6262465f0f3a95cd35b5546fc5f5169dc4cc2b9`
- compiled binary:
  `20fe43a57af7f4a0be8b3175db3665a61e7332eb33c18cda1a0c073cdfe284e7`
- North descriptor:
  `ddcb8bb8542519015320a303368302c1d83855a039e930c6abb0ea22710b63ba`
- South descriptor:
  `64a44804068a7dc77539670c6514d5b552bb654e3d6cf46480e0661c15d6f2b7`
- West descriptor:
  `a83b12566b2ee522ebcb6257b2bf3c7715be8b8eb445215a9dc45706cb8b4670`
- failed validation:
  `8879b1a06597dd687a4fb71471fdfbe6204164864b5054c9293b7551e72668e1`

East v05 descriptor, material library, and governed raw hashes remained exact.
The candidate-to-retained-pixel hash intersection was empty.
