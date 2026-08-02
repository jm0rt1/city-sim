# PLAY-075 R4-B recovery-baseline disposition

Disposition: **RETURN** before launch for exact candidate
`c3e577fe3174cfd50a6858200ed45ac747e89d81`.

The selected route, QA branch/HEAD/tree, claim, candidate source commit/tree,
candidate receipt, exclusive lease, manifest, executable, Info.plist, bundle
identifier, source cleanliness, absent output root, and zero matching candidate
applications all passed admission.

The final staged-build identity check did not. The candidate receipt and lease
bind the 82-file whole-app inventory to
`eaa891eb52071d866924dead0b0b36f797c18221d38baf4f08b397bf171abcd4`;
the staged app currently resolves to
`dcd2137387feec55c30d2df416db0c974ff63b5eefe8ce0fa522a8160ab7c059`.

This is not treated as a command-method discrepancy. The same relative-path,
sorted, null-delimited inventory command reproduced the retained prior R4-B
candidate receipt's 82-file digest exactly. The recovery candidate therefore
failed its immutable resource identity gate.

Per the route stop condition, QA did not launch the app, consume the exclusive
attempt, capture pixels, inspect gameplay, transfer a visual score, or infer a
terrain/overlay/interaction result. The known adjacent residential duplication
remains disclosed as a release blocker but was not reassessed in this stopped
gate.
