# PLAY-027 Commercial L4 source-v03 raw gate

Commercial L4 `source-v03` passes the authorized schema-2 v3 raw gate and may
proceed to deterministic normalization.

| Direction | Raw SHA-256 | Ordinary 7/9 repairs | Boundary 6+1 repairs |
|---|---|---:|---:|
| north | `9e996eb088bddc197468c5f881c111cf64ab16fa5220de7641d876d0601b4cff` | 1,311 | 92 |
| east | `a97d881325c22217e57807a2b63b9cdbd9218de37f155c1dd097cc67a52c617c` | 1,332 | 114 |
| south | `985d2df5c5c852b4614609eec120bfc67e6ac4d1efb8376791ec8a5020d77122` | 1,368 | 134 |
| west | `ac58ebd8c769fddd24d160f1ba4e4a5097d04f17ccab41bbb120672f5173433f` | 1,298 | 93 |

Binding results:

- three fresh renderer processes per direction;
- 12/12 raw file and decoded-pixel identities match within direction;
- four unique primary raw identities;
- 1536 x 1024 fully opaque flat-chroma source canvases;
- exact retained-byte alpha visibility ratio 1.0 in all directions;
- zero hidden non-magenta pixels;
- matching RGB and alpha-visible occupied bounds;
- complete tower, footprint, shadow, crown, and direction-specific frontage in
  all four exact occupied crops;
- renderer source commit
  `3cbf72504b447b1d663cf108a1fcadd542ef2bcf`;
- `productionSelected: false`.

The retained provenance records every schema-2 v3 boundary-assisted vote and
reason. No normalization, selection, renderer ingestion, shipping, runtime, or
shared surface is included in this raw checkpoint.
