# Visual and Audio Direction

## 1. Creative target

CitySim should look like a city the player wants to care for: inviting at first glance, structurally believable under scrutiny, and expressive enough to reveal prosperity, strain, weather, time, and history.

The proposed visual direction is **stylized civic realism**. Forms, infrastructure, movement, materials, and scale relationships are credible, while silhouettes, color grouping, lighting, and detail are deliberately tuned for readability. Photorealism is not the goal. The current native key art at `Native/CitySimNative/Resources/CitySim-KeyArt.png` is a tone and palette reference, not a final camera or asset-quality target.

Final art style and renderer approval remain recorded in [08_OPEN_DECISIONS.md](08_OPEN_DECISIONS.md).

## 2. Visual pillars

### 2.1 Read the city at every scale

- Region view communicates terrain, districts, major networks, ecology, and expansion pressure.
- City view communicates density, mobility, service reach, landmarks, and active incidents.
- Neighborhood view communicates frontage, land use, activity, prosperity, maintenance, and local character.
- Street view communicates people, vehicles, operations, construction, and weather without requiring microscopic simulation detail.

The most important gameplay state wins visual priority over decoration.

### 2.2 Growth leaves history

Buildings construct visibly, age, maintain, upgrade, decline, damage, repair, and redevelop. Trees mature, infrastructure gains wear, neighborhoods densify, and landmarks acquire authored event states. A long-running city must not look like a newly generated map with larger numbers.

### 2.3 Systems live in the world

Power failures darken affected areas; water shortages change operations and warnings; congestion forms from actual trips; service vehicles depart real facilities; pollution follows sources; parks attract plausible activity; and disaster recovery appears as staged work.

### 2.4 Calm interface, expressive world

Native UI chrome is restrained and consistent. Color accents indicate state and category without turning the viewport into an arcade dashboard. Celebrations and warnings use motion and effects sparingly enough to retain meaning.

## 3. Camera and composition

The default is a three-quarter city-builder camera with bounded pitch, rotation, and perspective. Far views flatten enough for map readability; near views introduce depth and parallax without breaking placement precision. Orthographic-only and full free-camera alternatives require art and UX validation before approval.

The camera supports cinematic bookmarks, time-lapse, photo mode, depth-of-field as an optional photo effect, and safe framing around tall buildings. Gameplay mode avoids forced lens effects that obscure data.

Terrain, streets, parcel edges, foundations, and building entrances use a consistent scale grammar. Buildings may use modest silhouette emphasis at distance, but roads and vehicles cannot be exaggerated so far that capacity or density becomes visually misleading.

## 4. Color and material language

The base world uses region-specific natural colors with clear value separation between ground, networks, structures, and water. Functional categories use stable accents:

- Residential: cyan or cool green family.
- Commercial: magenta or violet family.
- Industrial and logistics: amber family.
- Civic and services: blue-white family.
- Environment and parks: green family.
- Critical hazard: amber through red with icon and pattern support.

These are UI and overlay associations, not instructions to paint every building by zone.

World assets use physically based material inputs appropriate to the selected renderer: base color, normal, roughness, metallic where valid, emissive, ambient occlusion or approved packed alternatives. Material families are shared to reduce memory and preserve district coherence.

## 5. Environment and lighting

### 5.1 Day and night

The complete time cycle includes sunrise, day, sunset, night, and region-aware seasonal variation. Windows, streetlights, signage, vehicles, facilities, and emergency lighting respond to operation and power state. Exposure transitions are smooth and preserve build-tool readability.

Night is atmospheric but never an accessibility penalty. Players can lock visual time separately from simulation time in creative settings and photo mode.

### 5.2 Weather

Rain, snow where region-appropriate, fog, wind, storms, heat, and clear conditions affect sky, light, surface response, vegetation, particles, sound, and selected gameplay. Wetness and snow use scalable techniques with explicit GPU tiers.

Weather effects must not obscure hazard boundaries, construction previews, selected entities, subtitles, or critical alerts. Intensity and flashes are accessibility-adjustable.

### 5.3 Water and terrain

Water communicates depth, flow direction where material, pollution, shoreline, flood extent, and weather response. Terrain blending prevents visible grid repetition while retaining buildable-slope legibility. Terraform previews distinguish intended grade from resulting water and ecological effects.

## 6. Buildings and infrastructure

Each asset family has a silhouette sheet, scale references, modular rules, material set, climate adaptations, density progression, night state, construction stages, damage stages, and LOD plan.

Growable buildings require enough roof, frontage, color, prop, vegetation, age, and lot variation to avoid adjacent clones. Variation is seeded and save-stable. District styles influence probabilities and allowed modules rather than replacing all simulation rules.

Roads, rails, bridges, tunnels, stations, utility networks, intersections, markings, sidewalks, medians, trees, and street furniture assemble from validated kits. Network seams, grade transitions, and intersection markings receive the same quality bar as hero buildings because players see them constantly.

## 7. Citizens, vehicles, and animation

Animation follows simulation intent. Citizens walk, wait, board, work, shop, recreate, respond, and evacuate based on selected authoritative activities. Vehicles indicate acceleration, turning, stopping, loading, service, emergency response, and damage.

Animation uses scalable rigs, instancing, clips, and crowd LOD. Distant agents can use simplified motion or impostors, but motion direction and density must remain truthful. Close repetition is controlled through clip phase, gait, appearance, prop, and route variation.

Construction, upgrades, repairs, demolition, utility work, fires, emergency care, policing, school arrival, waste collection, and public events each require a readable activity sequence.

## 8. Effects and feedback

VFX communicate state at the point of consequence:

- Construction dust, cranes, sparks, and staged completion.
- Utility flow or outage cues that remain subtle outside overlays.
- Smoke, fire, water, damage, repair, and emergency response.
- Weather, wind, foliage, traffic lights, exhaust, and industrial activity.
- Selection, placement, invalidity, service dispatch, milestone, and objective feedback.

Effects have intensity tiers, distance culling, accessibility variants, and deterministic trigger inputs. Important state also has icon or text feedback.

## 9. UI art and motion

UI art follows macOS interaction conventions while maintaining a distinct CitySim identity. Icons use a consistent grid, stroke, fill, optical size, and state family. Every icon has a text label in discovery and accessibility contexts.

Motion explains spatial or state change: a panel emerges from its anchor, a metric update identifies its source, and a notification points to its location. Decorative motion is secondary, interruptible, reduced by system and in-game preferences, and never delays input.

## 10. Asset performance contract

Every 3D asset declares:

- LOD meshes or approved procedural reduction.
- Screen-size transitions and hysteresis.
- Material and texture set.
- Draw, triangle, bone, animation, and memory cost.
- Collision and selection representation.
- Shadow and reflection policy.
- Day, night, construction, damage, and seasonal support.
- Platform-quality tier behavior.

Automated import validation rejects missing metadata, out-of-budget assets, invalid transforms, unsupported shaders, absent LODs, duplicate identifiers, or incomplete required states.

Scene budgets are owned by the renderer and art leads and tested against golden cities, not empty maps. Hero exceptions require a documented budget trade.

## 11. Audio pillars

### 11.1 The city is an instrument

Ambience is assembled from actual district, activity, traffic, transit, weather, nature, industry, crowd, service, and incident state. Moving the camera should reveal a legible sonic map without becoming a wall of noise.

### 11.2 Music supports stewardship

The score is warm, thoughtful, and forward-moving. It responds to city phase, time, region, pressure, recovery, and achievement through layered transitions. It avoids constant crisis scoring and leaves space for the city itself.

### 11.3 Every action has confidence

Placement, cancelation, invalidity, construction start, completion, budget change, policy enactment, selection, save, objective, and warning each have distinct, restrained feedback. Sonic feedback confirms the same state as visual feedback and never announces success before the command is authoritative.

## 12. Music specification

The proposed base-game floor is 90 minutes of composed material, delivered as adaptive stems and complete listening mixes. Music states include opening, calm growth, active planning, mature city, pressure, disaster response, recovery, milestone, and reflective night.

Transitions are phrase-aware and bounded. The system tracks recent material to avoid repetition, supports a music-frequency preference, and allows players to inspect the current track. Licensed music is not assumed.

## 13. Ambience and spatial sound

The mix combines global region bed, weather, time of day, district beds, network movement, point sources, interiors where relevant, incidents, and UI. Camera altitude controls detail and mix density. Important alerts remain intelligible without muting the city unnaturally.

Spatial audio is supported where the platform and output permit but is never required to identify a threat. Stereo, mono, headphones, and common speaker configurations receive authored mixes.

## 14. Voice, text, and accessibility

Release 1 may use voiced campaign briefings and selected advisor lines, subject to the voice-scope decision. All speech has synchronized subtitles, speaker identification, replay, and separate volume. Generated operational notices do not require recorded voice.

Audio options include master, music, ambience, effects, UI, voice, dynamic-range presets, mono mix, background-audio behavior, and critical-alert visual equivalents.

## 15. Visual and audio acceptance

The presentation is release-ready when golden cities remain readable and visually coherent across required camera distances, times, weather, overlays, hardware tiers, and accessibility modes; assets stay within measured scene budgets; visible and audible activity agrees with simulation state; no launch content appears unfinished in required states; and the mix communicates place and consequence without fatigue during long playtests.

