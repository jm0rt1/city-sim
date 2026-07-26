# PLAY-072 Final Reconciliation Validation

- **Original matrix authority:** `e38059e721dae05c8df421754e3cb63ddf3fa153`
- **Retained baseline checkpoint:** `e0ac81494529a278fb22764e4c8c055b32f5b8d5`
- **Accepted PLAY-071 handoff:** `5cb532cb515a911ff8f47f4d509a50a5071d369f`
- **Non-rewriting merge:** `12460c72c557dff6c6a86afe5ae77819f54d1ffb`
- **Platform adoption:** `2881675d3013451b7bea2caf5bb4387d287d8b6b`
- **Lane:** `codex/citysim-simulation-platform`
- **Date:** July 25, 2026

## Outcome

PLAY-072 now retains two immutable historical fixture generations and adds
current post-PLAY-071 truth without changing a production contract:

- StoryStates v1 remains authentic missing-`secondAct` legacy truth.
- StoryStates v2 remains the complete pre-PLAY-071 Regional Capital corpus.
- StoryStates v3 adds twelve current post-PLAY-071 story identities.
- VisibleCityStates v1 remains the byte-exact `e38059e` comparison matrix.
- VisibleCityStates v2 adds fourteen current visible-city identities.

The current matrix covers vacant, construction, active, pressured, recovering,
upgraded, and terminal districts for Commercial and Industrial. Upgraded
identities use genuine strategy-family development. Pressured identities have
two Regional-damaged route lots below 0.4 condition. Recovering identities
have no distressed lot and exactly one weathered route-family scar in
`0.4..<0.75`.

No production source, model, Codable shape, save envelope, schema identifier,
fingerprint version, presentation contract, command, package, build script,
renderer, UI, or legacy Python file changed in the platform adoption commit.
The only production delta is the accepted PLAY-071 ancestor brought in by the
explicit merge.

## Corpus identity

Two fresh explicit generation runs were compared recursively:

```text
Story A:   /private/tmp/citysim-play072-story-a-20260725
Story B:   /private/tmp/citysim-play072-story-b-20260725
Visible A: /private/tmp/citysim-play072-visible-a-20260725
Visible B: /private/tmp/citysim-play072-visible-b-20260725
```

Both pairs were byte-identical, including their manifests. Frozen manifest
SHA-256 values:

```text
StoryStates v1     3614c6f7cd6eeed473c499f05a29c122aa92858744a717cc2e34bdb98f72fef0
StoryStates v2     a793dc9ea5cfc50b7482fb7f4bf4e7a3a3c5e9cfb1cad6e47722fc17cbf22153
StoryStates v3     bb27da325a259eb4186c54a749e6eb0391731a7f277860103099813ded7fba69
VisibleCity v1     e9ee17bc14a5d61334a9598bddb5d25bc1cfe0cb12443f0b08cb6100526af236
VisibleCity v2     babc84514ccae064f3d1b856868ef14a4bc0d54e3477597b24e41349601a5eeb
schema-0 legacy     28c41c2a8c44adc0de49110ebb05ba0952f9deb4f9cb59c3f10035e7a925e908
schema-1 legacy     56ea7704735540d2a573aea7d96575d34d363e3583b5c90bb81ceb8b620e01b9
```

The complete file, state, spatial, diagnostic, activity, tick, strategy,
phase, status, and focus-coordinate identities are frozen in the two new
manifests. Their manifest hashes are the compact corpus identities; no
historical manifest or fixture file was regenerated.

## Drift classification

Expected PLAY-071 semantic drift:

- strategy-family lots can now develop beyond level 1;
- development carries marginal revenue, upkeep, utility, and pollution;
- Regional pressure damages two strategy-family lots;
- recovery clears distress while retaining one weathered lot;
- terminal timing changes where qualification can now finish earlier;
- state, spatial, diagnostic, and activity digests therefore change for the
  new v3/v2 identities;
- the dense terminal state is renamed
  `dense-24x24-terminal-post-play071-v7` and freezes digest
  `65e5f505f7b1c4532de2dc20401222e11121b21b2be0def8333a203b6f6daeaa`.

The four current terminal identities are:

```text
commercialTaxRelief                 tick 1024  d3dc139bc5fbb65f23a898f5b3cfbad8d441de03acfc5fe21546c375836026ff
commercialPublicRealmInvestment     tick 1024  50f9d91f17c21f045872f4050705e0dcb5ceb490b464b06dfd11235fbbc98644
industrialUtilityExpansion          tick 1036  4287b7c38ff2323d418ca929d6d0fe936eb5fbfc1ba3af621a2a2f7069134421
industrialGreenBuffer               tick 1040  3de8dc77d7f662d199d50b09e0ee1c1210feb463abccbf2863533e6feb6feb2a
```

No unexpected schema, save, optional-field decoding, fingerprint-version, or
public snapshot drift was found. Authentic legacy inputs and every historical
corpus hash remain unchanged and directly asserted.

## Platform validation

The focused platform-owned matrix ran:

```text
ProductionStoryStateFixtureTests    7/7
SessionPlatformTests               16/16
SpatialConsequenceTests            15/15
StrategyResolutionPlatformTests     6/6
TerminalVictoryPlatformTests        2/2
VisibleCityStateFixtureTests        6/6
Total                              52/52 in 65.221 seconds
```

This proves two-build identity, exact v1 fingerprints, schema-0/schema-1
decoding, primary save/load, corrupt-primary backup recovery, paused load,
cleared Undo, uninterrupted/grouped-speed/save-resume/replay equality,
immutable analytics and spatial snapshots, all four terminal routes,
post-terminal rejection, and historical byte preservation.

Representative measured maxima remained within the existing budgets:

```text
Story generation pair       6.198 s / 6.264 s    limit 20 s each
Visible generation pair     2.248 s / 2.235 s    limit 20 s each
Largest current fixture     134,164 bytes        limit 2 MiB
Current fingerprint         1.671 ms max         limit 500 ms
Current snapshot            4.796 ms max         limit 500 ms
Current save                10.988 ms max        limit 1,500 ms
Current load                3.457 ms max         limit 1,500 ms
Retained snapshot sample    92,160 bytes         existing bound
Dense simulation            48.137 ms            existing bound
```

Repository checks:

```text
git diff --check                 passed
bash -n script/build_and_run.sh  passed
./script/build_and_run.sh --verify
                                  passed at 2881675d3013451b7bea2caf5bb4387d287d8b6b
```

The staged candidate used:

```text
candidate_id       simulation-platform-w8bb1822a1e25
bundle_identifier  com.jfmortensen.citysim.simulation-platform.w8bb1822a1e25
data_root           dist/test-data/simulation-platform-w8bb1822a1e25
manifest            dist/manifests/simulation-platform-w8bb1822a1e25.manifest
```

## Dependent gates and blocker

The requested downstream inventory ran without crossing lane boundaries:

```text
CityCommandCatalogTests   43/43 passed
GameStatusOverlayTests     7/7 passed
WorldRenderingTests       59/60 tests passed; 6 assertions in one test failed
Complete native suite     250 tests; 244 passed; the same 6 assertions failed
                         in 203.274 seconds
```

The only failing test is renderer-owned
`testIndustrialStrainCameraPrioritizesTheDominantDistrictWithoutHidingRemoteTruth`.
PLAY-071's authoritative developed bounds changed the regular and compact
camera inputs:

```text
1280x800 actual  scale 0.3127969503, width 0.7473417932, height 1.1477840952
1280x800 frozen  scale 0.3229652047, width 0.7238124428, height 1.2444660631
900x600 actual   scale 0.5447090268, width 0.6133673431, height 1.5631998000
900x600 frozen   scale 0.5763456821, width 0.5796985019, height 1.6539108633
```

This is disclosed as a renderer adoption blocker. PLAY-072 does not re-bless
renderer camera expectations or change renderer thresholds. The full-run
renderer pulse telemetry averaged 2.021 ms against the retained 2.1 ms limit;
the threshold was not relaxed.
