# Candidate Manifest

- **Disposition:** accepted
- **Integrated product commit:** `f75ab9106ba130a6ca317778eb20b48fa9d493b9`
- **Branch under test:** `codex/citysim-playtest-quality`
- **Candidate token:** `playtest-quality-wf967be0ab5b4`
- **Bundle and preferences identifier:** `com.jfmortensen.citysim.playtest-quality.wf967be0ab5b4`
- **Display name:** `CitySim [Quality wf967be0ab5b4]`
- **Staged bundle:** `dist/CitySim-playtest-quality-wf967be0ab5b4.app`
- **Executable:** `dist/CitySim-playtest-quality-wf967be0ab5b4.app/Contents/MacOS/CitySimNative-wf967be0ab5b4`
- **Isolated data root:** `dist/test-data/playtest-quality-wf967be0ab5b4`
- **Executable SHA-256:** `47b31de6dbef95bc5de35bee52b5bca5a81e422bae7566b206174315db344495`
- **Info.plist SHA-256:** `cc1ec2a4c4472d4c22c47ec5318fd8848a3a7ab5757e82045bf67c00f12f0afe`
- **Primary journey PID:** `83028`
- **Verified resume PID:** `86448`

The quality branch was clean and fast-forwarded to exact `f75ab91` before staging. The previously rejected PLAY-050 candidate and its evidence commit `3459f48` remain ancestors; no history was rewritten. The pre-existing isolated save root and onboarding preference were preserved under `/private/tmp` before this fresh run. Only the two exact executable PIDs above were targeted, and both were stopped after their respective duties.

No Swift, SpriteKit, SwiftUI, package, script, fixture, or gameplay surface changed in this acceptance slice.
