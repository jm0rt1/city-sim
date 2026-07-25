# PLAY-057 CONTRACT-014 Candidate Manifest

- **Branch:** `codex/citysim-ui-input`
- **Product commit:** `16dec0d7172557dc57518eea828c89d321544ffc`
- **Approved contract authority:** `82b5a1d7ae64174fccb9e3c7f6fc86517e120251`
- **Candidate ID:** `ui-input-wdbeadac6e0bd`
- **Worktree:** `/Users/James/.codex/worktrees/c8e2/city-sim`
- **Bundle:** `dist/CitySim-ui-input-wdbeadac6e0bd.app`
- **Bundle identifier:** `com.jfmortensen.citysim.ui-input.wdbeadac6e0bd`
- **Executable:** `dist/CitySim-ui-input-wdbeadac6e0bd.app/Contents/MacOS/CitySimNative-wdbeadac6e0bd`
- **Executable SHA-256:** `06a5a49c0cdd711b220a8799ec6b8c935931f89683891e04bd0fc3e986036140`
- **Isolated data root:** `dist/test-data/ui-input-wdbeadac6e0bd`
- **Loaded quicksave SHA-256:** `7d12f458ad9117e369862126314905538d2bde3a74548a68cd4c546a8722d1b7`
- **Staging manifest:** `dist/manifests/ui-input-wdbeadac6e0bd.manifest`

The bundle was built with `./script/build_and_run.sh --stage-only` from the
exact clean product commit. Computer Use then launched that executable
directly:

- regular proof PID `9655`, `CITYSIM_REGULAR_WINDOW=1`;
- compact proof PID `17589`, `CITYSIM_COMPACT_WINDOW=1` and
  `CITYSIM_REDUCE_MOTION_PROOF=1`.

The compact process was rechecked during evidence assembly: PID `17589`
resolved to the executable above. The retained regular frames are 1,278 x 768.
The retained compact frames are 900 x 652, representing exact 900 x 600
content plus the 52-point title bar.

All binding screenshots and accessibility trees under `live/` came from this
bundle, isolated data root, and loaded quicksave. Earlier PLAY-057 pointer
shield and state-restoration attempts remain under their rejected evidence
roots and are not candidate proof.
