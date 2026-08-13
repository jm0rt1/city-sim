#!/usr/bin/env python3
"""Create labeled evidence sheets and machine-readable hash manifests."""
from pathlib import Path
import hashlib, json, os, sys
from PIL import Image, ImageDraw
HERE=Path(__file__).resolve().parent
VIEWS=["camNE","camSE","camSW","camNW"]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def sheet(asset):
    paths=[HERE/"assets"/asset/"renders"/f"{asset}_{v}.png" for v in VIEWS]
    canvas=Image.new("RGBA",(784,824),(31,35,34,255)); d=ImageDraw.Draw(canvas)
    for i,(v,p) in enumerate(zip(VIEWS,paths)):
        x=(i%2)*400; y=(i//2)*412; canvas.alpha_composite(Image.open(p).convert("RGBA"),(x,y+28)); d.text((x+8,y+7),v,fill=(238,225,195,255))
    out=HERE/"assets"/asset/f"{asset}_contact-sheet.png"; canvas.save(out,optimize=False,compress_level=9)
    return out
def manifest(asset,contact):
    root=HERE/"assets"/asset; files=[root/f"{asset}.blend",contact,*[root/"renders"/f"{asset}_{v}.png" for v in VIEWS]]
    data={"schema":"citysim.world-art.environment-asset.v1","assetId":asset,"status":"source-only-not-live","originalGeometry":True,"cameraOrder":VIEWS,"cameraAzimuthDegrees":{"camNE":45,"camSE":135,"camSW":225,"camNW":315},"elevationDegrees":30,"projectedTilePixels":[88,44],"canvas":{"width":384,"height":384,"transparent":True,"trim":False,"footprintPivotPixel":[192,300]},"rootPivotWorld":[0,0,0],"postRenderCompensation":"none","artifacts":[]}
    for p in files:
        a={"path":p.relative_to(HERE).as_posix(),"bytes":p.stat().st_size,"sha256":sha(p)}
        if p.suffix==".png": a["dimensions"]=list(Image.open(p).size)
        data["artifacts"].append(a)
    out=root/"manifest.json"; out.write_text(json.dumps(data,indent=2,sort_keys=True)+"\n")
def main():
    for a in ("axis_civic_road","axis_civic_road_dressed","pocket_grove_park"): manifest(a,sheet(a))
    preview=HERE/"preview"/"environment_streetscape_preview_camNE.png"
    data={"schema":"citysim.world-art.environment-preview.v1","status":"source-only-review-evidence-not-live","layout":{"roadTileCenter":[0,0,0],"parkTileCenter":[0,3,0],"parkFootprintTiles":[2,2],"tileSize":2.0,"axes":"shared-world-XY"},"artifacts":[]}
    for p in (HERE/"preview"/"environment_streetscape_preview.blend",preview): data["artifacts"].append({"path":p.relative_to(HERE).as_posix(),"bytes":p.stat().st_size,"sha256":sha(p)})
    (HERE/"preview"/"manifest.json").write_text(json.dumps(data,indent=2,sort_keys=True)+"\n")
if __name__=="__main__": main()
