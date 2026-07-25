# Residential L3 West schema-2 quantizer diagnosis

Disposition: exact input split localized; no source-art or geometry change.

Three fresh descriptor-bound schema-2 renders retained both the prequantized
composite and the final quantized PNG. The prequantized images vary at six
foliage-edge channel samples by exactly one integer value. Five variations
remain within the same step-32 palette bucket. One crosses the current palette
threshold:

```text
coordinate:       x=733, y=778
prequantized:     green 23 versus 24
other channels:  red 4, blue 2, alpha 255
quantized result: [16,16,16,255] versus [16,48,16,255]
```

The current quantizer uses step 32 and midpoint offset 8. Integration
authorized exactly one additive schema-2 post-quantization canonicalizer
revision:

- read every decision from an immutable copy of the quantized RGBA buffer;
- consider only a fully opaque 3x3 neighborhood;
- for each RGB channel independently, require at least 7 of 9 samples to equal
  the same majority value;
- require the center channel to differ from that majority by exactly the
  frozen 32-value quantization quantum;
- replace only that center RGB channel;
- never mutate alpha or exact chroma pixels.

Schema 1 does not invoke this rule and remains byte-identical. Failed schema-2
contract v1 remains reproducible. The new schema-2 contract revision must bind
the algorithm, version, quantum, neighborhood, opacity requirement, majority
threshold, immutable-buffer requirement, RGB-only scope, alpha preservation,
and chroma preservation. No authored descriptor geometry, accepted source,
registration, material, normalized output, or source revision is changed.

The repair must first pass three fresh Residential L3 West processes. Only
then may the complete schema-2 diagnostic sample restart from a new retained
regression root. Residential L4 and normalization remain blocked until the
full raw gate passes.
