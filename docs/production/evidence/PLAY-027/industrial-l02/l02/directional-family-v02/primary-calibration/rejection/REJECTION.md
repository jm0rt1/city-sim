# PLAY-027 Industrial L2 V02 North primary decoder rejection

Disposition: `REJECTED_PRE_RENDER_DECODER_GATE`.

The first authorized North process exited with code 133 before SceneKit
capability acquisition, scene construction, Metal snapshot, or output
creation. The production decoder rejected the frozen North descriptor because
`entrance.stepCount` is required but absent:

```text
DecodingError.keyNotFound: Key 'stepCount' not found in keyed decoding
container. Path: entrance.
```

No North raw or provenance directory exists. West, South, repeats, and
normalization were not invoked. The immutable East v05 anchor remains
byte-preserved. `sourceAuthority=false` and `productionSelected=false`.

The smallest next action is a separately reviewed pre-render schema-completeness
repair that adds the required entrance contract fields to each frozen N/S/W
descriptor through the task-owned generator, reruns deterministic descriptor
validation, and commits that boundary before any new process. This checkpoint
does not authorize that repair or another render.
