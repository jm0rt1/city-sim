# PLAY-089 lane rebaseline divergence audit

Result: evidence-only audit with unresolved product deltas.

The corrected carrier `e2b208b306caac911f7f857734730583d7144b32` resolved the
receipt exactly and the selected route validated. The current OS lane HEAD
`634a336ad4693a458e4521e6e08865e785c95876` is a preserved synchronization merge,
but its tree is not equal to the later published master.

The key unresolved finding is Renderer. Its branch contains different blobs for
`LotContextRenderer.swift`, `LotRenderer.swift`, and
`WorldRenderingTests.swift`; these product/test bytes are absent from master.
The current Renderer evidence says `intake_preparing`, with no runtime
activation, shipping mutation, or independent acceptance, so the bytes are not
treated as accepted.

World-art direction branches likewise retain source/tooling deltas absent from
master. UI, gameplay, and simulation also retain product/test deltas. OS and QA
contribute evidence-only branch paths in this comparison. Explicit failed,
rejected, retired, or superseded records remain in their respective categories;
unknown status remains unresolved.

The bounded Integration proposal is to preserve all original commits, create
fresh clean baselines from accepted master bytes, and require an explicit
product-delta admission receipt before unresolved bytes become a lane baseline.
No branch or product mutation was performed.
