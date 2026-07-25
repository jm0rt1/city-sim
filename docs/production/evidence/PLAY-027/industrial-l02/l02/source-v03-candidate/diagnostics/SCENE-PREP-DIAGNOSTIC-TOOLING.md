# PLAY-027 Industrial L2 scene-preparation diagnostic tooling

Status: tooling boundary frozen before the prepare matrix.

`DiagnoseScenePreparation.swift` is a separate task-owned executable compiled
only with `-DPLAY027_SCENE_PREP_DIAGNOSTIC`. That compilation flag excludes
the normal renderer entry point; compiling without the flag retains the
existing production renderer entry point.

The diagnostic executable:

- accepts only exact Industrial L2 variant-zero source-v03 descriptor hashes;
- accepts only the frozen governed industrial material-library hash;
- resolves and requires schema-2 v3 `source-authority` sampling;
- requires the literal acknowledgement
  `PLAY-027-SCENE-PREP-V1`;
- writes only a new JSON file beneath the exact task-owned Industrial L2
  diagnostics evidence path;
- refuses overwrite;
- clones selected root nodes into a diagnostic scene and never changes the
  candidate descriptor, material library, or source scene;
- emits no PNG, normalized output, candidate provenance, or production
  selection;
- records the complete hierarchy, deterministic group assignment, transforms,
  bounds, geometry sources/elements/vertex and primitive counts, materials,
  texture-resource paths, duplicate names, invalid identities, selection, and
  `SCNRenderer.prepare` result.

Validation:

- diagnostic executable compiled successfully;
- default renderer executable compiled successfully after the conditional
  entry-point guard;
- forbidden `/private/tmp/forbidden-scene-prep.json` report path exited 133
  and emitted no file;
- diagnostic executable SHA-256:
  `8d915a3001d5e43f910b67902be85aeb89902c0f9d9da5b9befde05a2163e0f0`;
- default renderer test binary SHA-256:
  `119a82be4d501822e691eb166ae50779612b19681cc5fb53d2b83803ef67e10a`.

No matrix process has been run from this tooling checkpoint.
