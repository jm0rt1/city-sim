# PLAY-066 same-state baseline

- PLAY-066 authority: `0ed9f3a8ad28d6b29f734c97f3dd3111fd118cc6`
- Accepted world product represented by these captures:
  `02612e414912fdabcab858b0ca97e1f5edbc2757`
- Accepted integration product containing that world candidate:
  `f928696`
- Source packet:
  `docs/production/evidence/PLAY-062/candidate-02612e4/`
- State: Day 53, paused, authoritative Industrial L1 at displayed block
  15,12 with its real road directly south
- Windows: uncropped 1,278×768 regular and exact 900×600 content in the
  uncropped 900×652 compact decorated window
- Camera states: city, neighborhood, and block

`git diff f928696..0ed9f3a -- Native/CitySimNative` is empty. Wave 008 task
publication changed no product byte after the accepted world candidate, so
these immutable retained captures are valid visual baseline evidence for exact
authority `0ed9f3a`.

The candidate packet must recreate the same paused state and camera classes.
These files are not product acceptance and are not relabeled as candidate
captures.
