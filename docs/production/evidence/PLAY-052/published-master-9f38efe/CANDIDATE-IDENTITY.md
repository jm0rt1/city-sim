# PLAY-052 Published-Master Candidate Identity

Disposition candidate: `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`

The quality branch merged `origin/master` normally at
`0f9311f1085e35e63aa4fa45a1f533b95174ac0c`. Both the published candidate
and the preserved quality history at
`d2de6d4246b69d91f36cbc3bc32c31d7b3cd52b8` are ancestors. The duplicate
`combined-704784b` evidence was byte-identical before the merge; Git merged
without a conflict.

## Exact staged product

- bundle:
  `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/CitySim.app`
- executable:
  `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/CitySim.app/Contents/MacOS/CitySimNative`
- executable SHA-256:
  `ce57495d32edbcf02fa3cc9e219b32c629d2e40de0aac9c6f91cdbe2ef598e00`
- manifest:
  `/Users/James/Library/Mobile Documents/com~apple~CloudDocs/James's Files/Programming/Python/city-sim/dist/manifests/master.manifest`
- manifest SHA-256:
  `5686d6ea2747e20b253991bbdb0bac199f0c53013fe46f8223f5b5792aa4797f`
- manifest commit:
  `9f38efec4877ab7c3f0d77bf3bd4e36b56e3c034`
- candidate / bundle identifier / preference domain:
  `master` / `com.jfmortensen.citysim` / `com.jfmortensen.citysim`
- resource bundle:
  `CitySim.app/CitySimNative_CitySimNative.bundle`
- generated-v4 manifest SHA-256:
  `eab12ce0838be9dca6ae00927accac60b15eb41617b39c0e33dd1e727e759692`
- packaged world atlas manifest SHA-256:
  `411934e492a66216787f8c93dd91d3f68cc16637110dba9ed7186b22dda96d3d`

The quality branch has no product or script diff from `origin/master`; only
quality-owned history and evidence differ. No rebuild or lane bundle was
substituted.

## Route process binding

Before each route, every exact production-bundle PID was enumerated and
terminated. Every capture belongs to one of these sole exact executable
processes:

| Route | PID | Isolated data root | Content |
|---|---:|---|---|
| Commercial played journey | `87112` | `/private/tmp/citysim-play052-commercial.xCpZQv` | default |
| Commercial terminate/relaunch/load | `99563` | same root | default |
| Commercial backup-only recovery | `1584` | same root | default |
| Industrial played journey | `1803` | `/private/tmp/citysim-play052-industrial.5DJEKX` | explicit compact |

The final process scan found no running
`CitySim.app/Contents/MacOS/CitySimNative` process.

## Viewports

- default capture: `1278x768`;
- explicit compact capture: `900x652`, consisting of the exact `900x600`
  content area plus the 52-pixel macOS title/menu chrome.

The retained default and compact frames are uncropped Computer Use captures
from the exact staged bundle.
