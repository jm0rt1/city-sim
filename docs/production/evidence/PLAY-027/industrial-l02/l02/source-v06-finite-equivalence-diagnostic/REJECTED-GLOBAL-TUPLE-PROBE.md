# Rejected broad tuple-application probe

The first complete offline application mapped each of the 15 proven unstable
RGB tuples everywhere that tuple appeared in the 4x frame. It converged the
three frames, but the common colors occurred at 58,985 pixels and caused
42,318–42,330 pixels to change even though only 57 coordinates were unstable.
The resulting source image changed 132 pixels versus frozen source-v06.

That scope was rejected before handoff because it did not credibly leave every
stable coordinate byte-exact. The rejected probe used derivation-tool source
SHA-256
`07d8909ae532d400ede1cd52ee2ab63a8fd85f470ffdb391653a4d37a4f74433`
and binary SHA-256
`f9ff3ded83d822953a6255132472b4be532f707740c85027116caf6228b5adf4`.

The governed proposal instead binds the same two equivalence classes and 15
tuples to the exact 57 coordinates where the retained frames prove
instability. It rejects an unknown tuple at any governed coordinate and leaves
every other coordinate byte-exact.

Two incomplete application outputs caused by an orchestration path move and
the rejected broad probe remain locally preserved under
`/private/tmp/play027-v06-equivalence-failed-attempts/`. They are not source
authority, do not enter the proposed mapping, and are excluded from the
committed governed packet.
