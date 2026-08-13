#!/usr/bin/env python3
"""Focused structural, raster, manifest, and axis-contract validation."""
from pathlib import Path
import hashlib,json,sys
from PIL import Image
HERE=Path(__file__).resolve().parent; VIEWS=["camNE","camSE","camSW","camNW"]
def fail(x): raise SystemExit("ENVIRONMENT_VALIDATION_FAIL: "+x)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    cfg=json.loads((HERE/"pipeline.json").read_text())
    if cfg["grid"]["projectedTilePixels"]!=[88,44] or cfg["canvas"]["footprintPivotPixel"]!=[192,300]: fail("canonical grid drift")
    for a in cfg["assets"]:
        root=HERE/"assets"/a; m=json.loads((root/"manifest.json").read_text())
        if m["postRenderCompensation"]!="none" or m["status"]!="source-only-not-live": fail(a+" policy")
        if m["cameraOrder"]!=VIEWS: fail(a+" camera order")
        for v in VIEWS:
            p=root/"renders"/f"{a}_{v}.png"; im=Image.open(p)
            if im.size!=(384,384) or im.mode!="RGBA": fail(a+" raster contract")
            alpha=im.getchannel("A"); box=alpha.getbbox()
            if box is None or box==(0,0,384,384): fail(a+" transparency/trim")
        for item in m["artifacts"]:
            p=HERE/item["path"]
            if not p.is_file() or p.stat().st_size!=item["bytes"] or sha(p)!=item["sha256"]: fail("manifest drift "+item["path"])
    pm=json.loads((HERE/"preview"/"manifest.json").read_text())
    if pm["layout"]!={"axes":"shared-world-XY","parkTileCenter":[0,2,0],"roadTileCenter":[0,0,0],"tileSize":2.0}: fail("preview grid layout")
    print("ENVIRONMENT_VALIDATION_PASS")
if __name__=="__main__": main()
