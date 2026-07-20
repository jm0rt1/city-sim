# PLAY-021 Exact Candidate AFTER Evidence

- **Product commit:** `7ba6f982f7c26b3296a75c00f20bc248de3b31a3`
- **Evidence commit:** `86a956ba51e67fd32be934bc3a0fb9e67f0a7c2d`
- **Integration authority ancestor:** `43be4f40f92827c081663ed41fcc93090ce506fc`
- **Candidate:** `world-rendering-w5f893ad1da1b`
- **Bundle identifier:** `com.jfmortensen.citysim.world-rendering.w5f893ad1da1b`
- **Executable:** `dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b`
- **Data root:** `dist/test-data/world-rendering-w5f893ad1da1b`

All files below came from the exact staged candidate. The compact capture is a
900 x 652 window containing the requested 900 x 600 content area plus 52 pixels
of native chrome. The same-camera AFTER uses the exact baseline camera scale
0.72; the current product window is 1278 x 768 versus the immutable baseline's
1228 x 768, a 50-pixel width difference disclosed rather than cropped away.

## SHA-256 manifest

```text
d6d08164c8dc1069b08b8cf359dd02d16138b6b382e2a2013fd7b1d0e3f2ebff  after-accessibility.txt
d8f7c6314fded5bed4d116694a6eb572910f1a4221cde675d96591572010f8b8  after-block-live.jpeg
61682f73a8c788d1681db92b6cb6ecce9ba55a294289ce3f249063bf9bf82cb4  after-city-live.jpeg
0d5c9b7580dce93432fd6f85e0e7de009260c5f6a2619f1042f16835051a1137  after-compact-live.jpeg
d8f7c6314fded5bed4d116694a6eb572910f1a4221cde675d96591572010f8b8  after-default-live.jpeg
e8efee1716e4f62e914aab5d1f3df4b5e10675047cafb2c851137ddfd161a4ef  after-frame-developed-live.jpeg
45bd1f4fd0c0b56c74f4b536780650dfa0c6ac178c852fe617845363b861fad4  after-neighborhood-live.jpeg
a92606b6dade3f7bd421ea43f1f8955369380ad64c38d6f71c86a6332f1754c0  after-overlay-live.jpeg
07f885739c230ab1f4510410a9d64e99dcd034beec37d18a2d0d4d07bc90419e  after-pan-live.jpeg
c8001cfe1f5baa212ae7375a043714b9d23ab0a89d89b0174ffc3eb5d07bcce5  after-pan-zoom-live.jpeg
1ef099a18236dec88daa8f29ca47273fa0a64fcee7d7639545db4b1ffd39c4b1  after-placement-committed-live.jpeg
d6296afe12964f0b73ba13a31f5daf4320765233622939339263ddb8ef58ae4e  after-placement-invalid-live.jpeg
9374defa82bb482d4d749549bd447c53561ac9cd7a2e4f6bdb93b6cb246a9df9  after-placement-undone-live.jpeg
9837e76e5d8e8cea0a127f97f9a41b6dbdcb4ca65316f7039669935080e5fb01  after-placement-valid-live.jpeg
30bd34df118e9735347193faf03e4e0a0b5a748c00a1d06c1ed02c52b5e530a5  after-reduced-motion-live.jpeg
cde718a26c410015b2d17c1e188df9cf655af36ff86ef8ce6271967add684c7f  after-same-camera-live.jpeg
ea02f73b83575c0e732fdafe21b9bf0e5b689c043e90ab33a3d66e8a866ed6f6  after-selection-live.jpeg
```

The rejected synchronized start is retained separately at
`rejected-synchronized-start-live.jpeg`, SHA-256
`668eb4bf6d7eb70a1f16eff8fb87ea15d80f28790ec0558d21c284832c747212`.
Immutable BEFORE source commit and hashes remain in `BEFORE.md`.
