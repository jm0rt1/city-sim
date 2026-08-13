#!/usr/bin/env python3
"""Independent source and output validation for employment asset production."""
from __future__ import annotations
import hashlib, json, math, sys
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE=Path(__file__).resolve().parent; CANON=HERE.parent.parent/"FourViewPipeline"; sys.path.insert(0,str(CANON))
from png_canonical import decode_rgba_png  # noqa: E402
CONFIG=json.loads((CANON/"pipeline.json").read_text()); ASSETS=("harbor_corner_storefront","ironleaf_service_workshop")

def close(a,b,t=.0001): return abs(a-b)<=t
def check(condition,msg):
    if not condition: raise RuntimeError(msg)
def validate_asset(asset):
    manifest=json.loads((HERE/asset/"manifest.json").read_text()); blend=HERE/asset/f"{asset}.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend)); scene=bpy.context.scene
    check(scene.render.resolution_x==384 and scene.render.resolution_y==384 and scene.render.film_transparent,"CANVAS_MISMATCH")
    root=bpy.data.objects.get("AssetRoot"); pivot=bpy.data.objects.get("FootprintPivot")
    check(root and pivot and pivot.parent==root,"ROOT_PIVOT_MISMATCH")
    check(tuple(root.location)==(0,0,0) and tuple(root.scale)==(1,1,1),"ROOT_TRANSFORM_MISMATCH")
    check(root.get("sourcePixelsReused") is False and root.get("liveAsset") is False,"PROVENANCE_MISMATCH")
    meshes=[o for o in bpy.data.objects if o.type=="MESH"]
    check(len(meshes)>=18,"GEOMETRY_TOO_SIMPLE")
    for obj in meshes:
        check(obj.parent==root,"MESH_OUTSIDE_ROOT:"+obj.name)
        check(all(close(v,1) for v in obj.scale),"UNAPPLIED_SCALE:"+obj.name)
        check(all(close(v,0) for v in obj.rotation_euler),"UNAPPLIED_ROTATION:"+obj.name)
    lights=[o for o in bpy.data.objects if o.type=="LIGHT"]
    check(len(lights)==1 and lights[0].name=="CitySimKey","LIGHT_MISMATCH")
    check(tuple(lights[0].location)==tuple(CONFIG["lighting"]["location"]),"LIGHT_LOCATION_MISMATCH")
    check(all(close(value,expected) for value,expected in zip(lights[0].data.color,CONFIG["lighting"]["color"])),"LIGHT_COLOR_MISMATCH")
    for view in CONFIG["cameraRig"]["views"]:
        cam=bpy.data.objects.get(view["name"]); check(cam is not None and cam.data.type=="ORTHO","CAMERA_MISSING")
        check(close(cam.data.ortho_scale,12.341995,1e-5) and close(cam.data.shift_y,.28125),"CAMERA_SCALE_SHIFT_MISMATCH")
        ndc=world_to_camera_view(scene,cam,Vector((0,0,0))); px=(ndc.x*384,(1-ndc.y)*384)
        check(close(px[0],192,.01) and close(px[1],300,.01),"PIVOT_PIXEL_MISMATCH")
        az=math.degrees(math.atan2(cam.location.x,cam.location.y))%360
        check(close(az,view["azimuthDegrees"],.001),"CAMERA_AZIMUTH_MISMATCH")
    check(manifest["assetId"]==asset and manifest["originalGeometry"] is True and manifest["postRenderCompensation"]=="none","MANIFEST_MISMATCH")
    for artifact in manifest["artifacts"]:
        path=HERE/artifact["path"]; check(path.is_file(),"MISSING_ARTIFACT:"+str(path))
        check(path.stat().st_size==artifact["bytes"] and hashlib.sha256(path.read_bytes()).hexdigest()==artifact["sha256"],"ARTIFACT_DRIFT:"+str(path))
        if path.suffix==".png":
            w,h,p=decode_rgba_png(path); check([w,h]==artifact["dimensions"],"PNG_SIZE_MISMATCH")
            check(hashlib.sha256(p).hexdigest()==artifact["decodedRgbaSha256"],"RGBA_HASH_MISMATCH")
            alpha=p[3::4]; check(any(alpha) and any(v==0 for v in alpha),"ALPHA_POLICY_MISMATCH")
    names={o.name for o in bpy.data.objects}
    required={"CustomerDoor","BladeSign","EntranceCanopy"} if "storefront" in asset else {"RollupDoor","LoadingBumper","PersonnelDoor"}
    check(required<=names,"SEMANTIC_GEOMETRY_MISSING:"+str(required-names))

for asset in ASSETS: validate_asset(asset)
preview=json.loads((HERE/"employment_block_preview_manifest.json").read_text())
check(preview["grid"]["projectedTilePixels"]==[88,44] and preview["assetScale"]==[1,1,1],"PREVIEW_GRID_MISMATCH")
for item in preview["artifacts"]:
    path=HERE/item["path"]; check(hashlib.sha256(path.read_bytes()).hexdigest()==item["sha256"],"PREVIEW_DRIFT")
print("COMMERCIAL_INDUSTRIAL_VALIDATION_PASS")
