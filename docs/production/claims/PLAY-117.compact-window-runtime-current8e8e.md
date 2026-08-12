# PLAY-117 UI/Input Claim — Honor Compact Window Geometry

- **Lane / owner:** UI/Input — Agent 301, UI/Input Lead.
- **Authority / base:** `8e8e39f9b09ee90b13851d7c662f8861f9e5be6d`.
- **Player outcome:** A `CITYSIM_COMPACT_WINDOW=1` staged launch renders true
  900 × 600 AppKit content, while normal default/minimum window behavior and
  the accepted PLAY-114/PLAY-115 map-first behavior remain unchanged.
- **Exact mutation roots:**
  `Native/CitySimNative/Sources/CitySimNative/Support/ProofWindowConfigurator.swift`,
  `Native/CitySimNative/Sources/CitySimNative/App/CitySimNativeApp.swift`, and
  `Native/CitySimNative/Tests/CitySimNativeTests/ProofWindowConfiguratorTests.swift`.
- **Frozen contracts:** No map-first layout, command, AX selection, keyboard,
  art, renderer, gameplay, save, minimum content size, or default regular
  sizing change. Preserve QA evidence and PID 88258; this lease owns no
  process lifecycle.
- **Proof / stop:** Focused proof must cover compact 900 × 600 request and
  regular/default behavior. Include one isolated smoke that observes a true
  compact content window only if safely possible without touching existing
  QA processes. Stop on a required path outside this list, shared scene/window
  contract change, compact/default contradiction, or a second focused failure.
  One bounded local repair is allowed. On PASS commit only the coherent packet;
  no aggregate, stage, QA, push, or release.
