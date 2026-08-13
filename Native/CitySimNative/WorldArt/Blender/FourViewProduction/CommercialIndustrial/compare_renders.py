#!/usr/bin/env python3
"""Require deterministic byte equality for rerendered raster evidence."""
import hashlib, sys
from pathlib import Path

left,right=map(Path,sys.argv[1:3])
names=["harbor_corner_storefront/renders/harbor_corner_storefront_"+v+".png" for v in ("camNE","camSE","camSW","camNW")]
names += ["ironleaf_service_workshop/renders/ironleaf_service_workshop_"+v+".png" for v in ("camNE","camSE","camSW","camNW")]
names += ["harbor_corner_storefront/harbor_corner_storefront_contact-sheet.png","ironleaf_service_workshop/ironleaf_service_workshop_contact-sheet.png","employment_block_preview.png"]
for name in names:
    a=hashlib.sha256((left/name).read_bytes()).hexdigest(); b=hashlib.sha256((right/name).read_bytes()).hexdigest()
    if a!=b: raise SystemExit("DETERMINISM_MISMATCH: "+name+" "+a+" != "+b)
print("DETERMINISTIC_RERENDER_PASS",len(names))
