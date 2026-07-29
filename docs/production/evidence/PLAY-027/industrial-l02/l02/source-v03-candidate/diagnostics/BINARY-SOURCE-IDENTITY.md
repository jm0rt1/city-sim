# PLAY-027 Industrial L2 source-v03 binary/source identity

Disposition: stale binary or stale renderer source is ruled out before scene
instrumentation.

## Frozen inputs

- Diagnostic base: `47c86a38ec3b899346baec4a35b89ab39ccfc3d2`.
- Frozen descriptor checkpoint: `c0ae6ed`.
- Last commit that changed any renderer compilation source:
  `e2690f524dbf468255605cfe77a236404a015fa9`.
- `git diff --quiet e2690f...HEAD` over all five renderer compilation
  sources exits 0.
- Material SHA-256:
  `166a19d5569a927d6ccdbaf1b29131835238bb3622e66d3b376d9eb33008f1ef`.
- Toolchain fingerprint SHA-256:
  `201ef1a1bdc54fb048f7bb00708e97c1605c0ca48814ba28c8dc6fdc65d3fccd`.

The provenance value `e2690f...` is therefore intentional: it identifies the
last renderer-source mutation, while `c0ae6ed` identifies the later frozen
Industrial L2 descriptors. Using the task checkpoint as
`rendererSourceCommit` would incorrectly claim that descriptor-only commits
changed the renderer.

## Fresh compilation check

The unchanged HEAD sources were compiled twice from fresh invocations with the
frozen Swift 6.3.3/macOS 26.4.1 toolchain:

| Binary | SHA-256 | Mach-O UUID |
|---|---|---|
| fresh A | `b16033441105ce1d379e5a1645a73fb47a6c5107224d164d5d5dce69c0397b46` | `91AEA9BF-0F1B-32D9-BD43-C67393A61BF2` |
| fresh B | `dc0f113f2c0c05584906d223a3ec544a7634a7e9b361c7c26f682e4bbf84d3e1` | `A40993BE-60BC-37D5-B8C2-0BCE37888BAC` |
| prior task binary | `69bb7500ff435ea43bf549eb6ca249b3a88c435d3f4f54e6bacad2bb290ab94a` | `10A67E10-A0D7-3339-8DF3-4F6059E099ED` |

All three have identical Mach-O segment sizes. Fresh A/B differ at 49 bytes,
including their linker-generated UUIDs, so raw executable SHA is not a
repeat-build identity contract.

Fresh binary B was then invoked against the unchanged North source-v03
descriptor and material library. It exits 133 with the same
`SceneKit could not prepare the complete scene graph` error and emits neither
PNG nor provenance. This independently reproduces the failure from current
source and rules out a stale executable as its cause.
