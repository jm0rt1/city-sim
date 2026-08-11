#!/usr/bin/env python3
"""Focused mechanical validator for the PLAY-104 industrial L1 East candidate."""
from __future__ import annotations

import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[8]
EAST = ROOT / "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-104/east"
EVIDENCE = ROOT / "docs/production/evidence/PLAY-104/industrial-l01-v0"
IDENTITY = "industrial_l01_v0"
RAW = EAST / "raw" / IDENTITY / "east-source-v01.png"
LODS = {"block": (1024, 683), "neighborhood": (512, 342), "city": (256, 171)}
SOUTH_SHA = "7ca3e26234e7e15df9a46775a83f7132f89e1ea1f22d97c42ca6d3502099bbd2"
RAW_SHA = "994101a17bcdede965ae14093dad796faf8b174384b9fe73acf01dabc0a23264"
ROUTE_ID = "east-v2:play-104-currentd3be-industrial-l01-v0-recent-image-v1"
ROUTE_CANONICAL = "933cd4e01111c651887605e5421eb757f3b96c1dfc517786d3611033a0ce2574"
ROUTE_FILE_SHA = "0e14c1c36b828edf603de4818c411ad44380301bfd9ef5e25c4440af5bb6783c"
BRANCH = "codex/citysim-world-art-play104-industrial-l01-v0-east"
HEAD = "d3bed770eb3bf79194df7b15737a19bddafdcd42"
CANVAS = (1536, 1024)
SIG = b"\x89PNG\r\n\x1a\n"

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p-a), abs(p-b), abs(p-c)
    return a if pa <= pb and pa <= pc else (b if pb <= pc else c)

def decode(path: Path) -> tuple[int, int, str, bytes]:
    raw = path.read_bytes()
    if not raw.startswith(SIG): raise ValueError(f"not PNG: {path}")
    off, idat, width, height, typ = len(SIG), bytearray(), None, None, None
    while off < len(raw):
        n = struct.unpack(">I", raw[off:off+4])[0]
        kind, data = raw[off+4:off+8], raw[off+8:off+8+n]
        crc = struct.unpack(">I", raw[off+8+n:off+12+n])[0]
        if zlib.crc32(kind + data) & 0xffffffff != crc: raise ValueError(f"CRC: {path}")
        if kind == b"IHDR":
            width, height, depth, typ, comp, filt, inter = struct.unpack(">IIBBBBB", data)
            if (depth, comp, filt, inter) != (8, 0, 0, 0) or typ not in (2, 6): raise ValueError(f"PNG format: {path}")
        elif kind == b"IDAT": idat.extend(data)
        elif kind == b"IEND": break
        off += 12 + n
    channels = 3 if typ == 2 else 4
    scan = zlib.decompress(idat); stride = width * channels
    out = bytearray(height * stride); pos = 0
    for y in range(height):
        ft = scan[pos]; pos += 1; row = bytearray(scan[pos:pos+stride]); pos += stride
        prev = out[(y-1)*stride:y*stride] if y else bytes(stride)
        for x in range(stride):
            left = row[x-channels] if x >= channels else 0
            up = prev[x]; ul = prev[x-channels] if x >= channels else 0
            if ft == 1: row[x] = (row[x] + left) & 255
            elif ft == 2: row[x] = (row[x] + up) & 255
            elif ft == 3: row[x] = (row[x] + ((left + up)//2)) & 255
            elif ft == 4: row[x] = (row[x] + paeth(left, up, ul)) & 255
            elif ft != 0: raise ValueError(f"filter {ft}: {path}")
        out[y*stride:(y+1)*stride] = row
    return width, height, "RGB" if typ == 2 else "RGBA", bytes(out)

def keyed(r: int, g: int, b: int) -> bool:
    return r >= 150 and b >= 120 and g <= 125 and r + b >= 2*g + 150

def check() -> dict[str, object]:
    if not RAW.is_file(): raise ValueError("missing East raw")
    w, h, mode, data = decode(RAW)
    if (w, h, mode) != (*CANVAS, "RGB"): raise ValueError(f"raw format {(w,h,mode)}")
    if sha(RAW) != RAW_SHA: raise ValueError("raw hash mismatch")
    if keyed(data[0], data[1], data[2]) is False and not keyed(*data[:3]):
        raise ValueError("raw does not carry expected chroma field")
    lods: dict[str, object] = {}
    for name, size in LODS.items():
        path = EAST / "lod" / IDENTITY / f"{name}.png"
        lw, lh, lm, ld = decode(path)
        if (lw, lh, lm) != (*size, "RGBA"): raise ValueError(f"LOD format {name}")
        bad_key = hidden = edge = 0
        for i in range(0, len(ld), 4):
            r, g, b, a = ld[i:i+4]
            bad_key += int(a > 0 and keyed(r, g, b))
            hidden += int(a == 0 and (r or g or b))
        for x in range(lw):
            edge += int(ld[(x*4)+3] != 0) + int(ld[((lh-1)*lw+x)*4+3] != 0)
        for y in range(lh):
            edge += int(ld[(y*lw)*4+3] != 0) + int(ld[(y*lw+lw-1)*4+3] != 0)
        if bad_key or hidden or edge: raise ValueError(f"LOD alpha/chroma {name}: {bad_key}/{hidden}/{edge}")
        lods[name] = {"path": str(path.relative_to(ROOT)), "sha256": sha(path), "dimensions": list(size), "mode": lm, "badKey": bad_key, "hiddenRGB": hidden, "edgeAlpha": edge}
    sheets = {}
    sheet_names = (
        "industrial_l01_v0-source-size-contact-sheet.png",
        "industrial_l01_v0-literal-game-scale-color-contact-sheet.png",
        "industrial_l01_v0-literal-game-scale-grayscale-contact-sheet.png",
    )
    for name in sheet_names:
        path = EAST / "contact-sheets" / name
        sw, sh, sm, sd = decode(path)
        if sm != "RGB": raise ValueError(f"sheet mode {path}")
        if any(keyed(*sd[i:i+3]) for i in range(0, len(sd), 3)): raise ValueError(f"sheet chroma {path}")
        sheets[str(path.relative_to(ROOT))] = {"sha256": sha(path), "dimensions": [sw, sh], "mode": sm}
    if len(sheets) != 3: raise ValueError(f"contact sheets {len(sheets)}")
    handoff = EVIDENCE / "handoffs" / IDENTITY / "east-handoff.json"
    value = json.loads(handoff.read_text())
    if value.get("transport") != "central_view_image_recent_image_bridge": raise ValueError("handoff transport")
    for k, expected in {"task":"PLAY-104", "identity":IDENTITY, "direction":"east", "routeId":ROUTE_ID, "canonicalModelRouteSha256":ROUTE_CANONICAL, "routeFileSha256":ROUTE_FILE_SHA, "candidateReadyForIndependentReview":True, "sourceReady":False, "integrationAdmitted":False, "rendererQuarantined":False, "productionSelected":False}.items():
        if value.get(k) != expected: raise ValueError(f"handoff {k}")
    return {"status":"PASS", "identity":IDENTITY, "direction":"east", "rawSha256":RAW_SHA, "lods":lods, "contactSheets":sheets, "routeId":ROUTE_ID, "routeCanonicalSha256":ROUTE_CANONICAL, "transport":"central_view_image_recent_image_bridge", "siblingInputsConsumed":[]}

if __name__ == "__main__":
    print(json.dumps(check(), sort_keys=True, indent=2))
