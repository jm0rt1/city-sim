# PLAY-027 Industrial L2 source-v03 prepare matrix

Disposition: no authored node, geometry, material, texture, group, cumulative
threshold, or ordering interaction is the cause. The smallest failing
diagnostic object is an empty cloned `SCNScene`.

All 19 reports were produced by separate fresh diagnostic processes. Each
process rebuilt the unchanged North source-v03 scene, cloned only its selected
root nodes, emitted inventory JSON, called
`SCNRenderer.prepare(scene, shouldAbortBlock:nil)`, wrote no PNG/provenance,
and exited 0 on success or 2 on false.

## Complete inventory

The unchanged complete scene contains:

- 130 uniquely named root nodes;
- 2,046 primitives;
- 381 geometry sources and 145 geometry elements;
- 127 material references;
- 0 texture/resource paths;
- 0 duplicate identities;
- 0 missing identities;
- 0 non-finite transforms, dimensions, or bounds;
- 0 invalid/empty geometry or material assignments.

The deterministic group inventory is foundation/plate 1, structural mass 5,
windows 66, roof/process 29, frontage/gantry/props 26, and
shadow/light/camera 3.

## Per-group and cumulative outcomes

Every isolated group returns false, including the one-node foundation group
and the three-node light/camera group. Every cumulative set returns false:

| Selection | Nodes | Prepare |
|---|---:|---|
| foundation | 1 | false |
| + structural mass | 6 | false |
| + windows | 72 | false |
| + roof/process | 101 | false |
| + frontage/gantry/props | 127 | false |
| + shadow/light/camera | 130 | false |

## Root-node and empty controls

Each individual foundation, assembly-hall, northwest-key, ambient-fill, and
contract-camera root returns false. The zero-node cloned scene also returns
false.

Because a zero-node scene contains no descriptor geometry, materials,
textures, identities, transforms, bounds, order, or cumulative threshold,
there is no failing source-v03 subgraph to bisect. The identical production
error is upstream of authored scene content, inside renderer/backend
preparation availability or the synchronous API result contract.

This checkpoint makes no repair and does not retry candidate rendering.
