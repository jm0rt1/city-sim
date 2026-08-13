#!/usr/bin/env python3
"""Independent structural, raster, manifest, and deterministic-render checks."""

from __future__ import annotations

import hashlib
import json
import math
import shutil
import sys
import tempfile
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = Path(__file__).resolve().parent
CANONICAL = HERE.parents[1] / "FourViewPipeline"
sys.path.insert(0, str(CANONICAL))
sys.path.insert(0, str(HERE))
from png_canonical import decode_rgba_png  # noqa: E402
import build_and_render as builder  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text())


def require(condition, code, detail):
    if not condition:
        raise RuntimeError(f"{code}: {detail}")


def close(actual, expected, tolerance, label):
    require(abs(float(actual)-float(expected)) <= tolerance, "VALUE_MISMATCH", f"{label}: {actual} != {expected}")


def vector(actual, expected, tolerance, label):
    require(len(actual)==len(expected), "VECTOR_LENGTH_MISMATCH", label)
    for i,(a,e) in enumerate(zip(actual,expected)): close(a,e,tolerance,f"{label}[{i}]")


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_scene(asset):
    path=HERE/f"{asset['assetId']}.blend"; require(path.is_file(),"MISSING_BLEND",path)
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene=bpy.context.scene
    require(scene.render.engine==CONFIG["toolchain"]["renderEngine"],"ENGINE_MISMATCH",scene.render.engine)
    require((scene.render.resolution_x,scene.render.resolution_y)==(384,384),"CANVAS_MISMATCH","not 384x384")
    require(scene.render.film_transparent,"CANVAS_NOT_TRANSPARENT",asset["assetId"])
    require(scene.get("postRenderCompensation")=="none","POST_RENDER_COMPENSATION_FORBIDDEN",asset["assetId"])
    root=bpy.data.objects.get("AssetRoot"); pivot=bpy.data.objects.get("FootprintPivot")
    require(root is not None and pivot is not None,"MISSING_ROOT_OR_PIVOT",asset["assetId"])
    vector(root.location,(0,0,0),1e-5,"root.location"); vector(root.rotation_euler,(0,0,0),1e-5,"root.rotation"); vector(root.scale,(1,1,1),1e-5,"root.scale")
    require(pivot.parent==root,"PIVOT_PARENT_MISMATCH",asset["assetId"])
    require(root.get("sourcePixelsReused") is False and root.get("liveAsset") is False,"PROVENANCE_MISMATCH",asset["assetId"])
    meshes=[o for o in bpy.data.objects if o.type=="MESH"]
    require(len(meshes)>=24,"GEOMETRY_TOO_SIMPLE",f"{asset['assetId']}: {len(meshes)} mesh objects")
    for obj in meshes:
        require(obj.parent==root,"MESH_OUTSIDE_ROOT",obj.name)
        vector(obj.scale,(1,1,1),1e-5,obj.name+".scale"); vector(obj.rotation_euler,(0,0,0),1e-5,obj.name+".rotation")
    lights=[o for o in bpy.data.objects if o.type=="LIGHT"]
    require(len(lights)==1 and lights[0].name=="CitySimKey","LIGHT_CONVENTION_MISMATCH",str([o.name for o in lights]))
    light=lights[0]; vector(light.location,CONFIG["lighting"]["location"],1e-5,"light.location"); close(light.data.energy,1100,1e-5,"light.energy"); close(light.data.size,5,1e-5,"light.size"); vector(light.data.color,CONFIG["lighting"]["color"],1e-5,"light.color")
    views=CONFIG["cameraRig"]["views"]
    cams=[o for o in bpy.data.objects if o.type=="CAMERA"]
    require(sorted(o.name for o in cams)==sorted(v["name"] for v in views),"CAMERA_SET_MISMATCH",str([o.name for o in cams]))
    for view in views:
        cam=bpy.data.objects[view["name"]]; require(cam.data.type=="ORTHO","CAMERA_NOT_ORTHO",cam.name)
        close(cam.data.ortho_scale,12.341995,1e-5,cam.name+".orthoScale"); close(cam.data.shift_y,.28125,1e-5,cam.name+".shiftY")
        p=world_to_camera_view(scene,cam,Vector((0,0,0))); pixel=(p.x*384,(1-p.y)*384); vector(pixel,(192,300),.01,cam.name+".pivotPixel")
        horizontal=math.hypot(cam.location.x,cam.location.y); elevation=math.degrees(math.atan2(cam.location.z,horizontal)); azimuth=math.degrees(math.atan2(cam.location.x,cam.location.y))%360
        close(elevation,30,.0001,cam.name+".elevation"); close(azimuth,view["azimuthDegrees"],.0001,cam.name+".azimuth")
    cam=bpy.data.objects["camNE"]; tile=2.0
    points=[]
    for x,y in ((-1,-1),(1,-1),(1,1),(-1,1)):
        p=world_to_camera_view(scene,cam,Vector((x,y,0))); points.append((p.x*384,(1-p.y)*384))
    width=max(p[0] for p in points)-min(p[0] for p in points); height=max(p[1] for p in points)-min(p[1] for p in points)
    vector((width,height),(88,44),.01,"projectedTilePixels")


def validate_manifest(asset):
    path=HERE/f"{asset['assetId']}_manifest.json"; data=json.loads(path.read_text())
    require(data["assetId"]==asset["assetId"],"MANIFEST_IDENTITY_MISMATCH",path.name)
    require(data["status"]=="source-only-not-live" and data["liveAsset"] is False,"MANIFEST_STATUS_MISMATCH",path.name)
    require(data["postRenderCompensation"]=="none","MANIFEST_COMPENSATION_FORBIDDEN",path.name)
    require(data["cameraOrder"]==[v["name"] for v in CONFIG["cameraRig"]["views"]],"CAMERA_ORDER_MISMATCH",path.name)
    for artifact in data["artifacts"]:
        p=HERE/artifact["path"]; require(p.is_file(),"MISSING_ARTIFACT",str(p)); require(p.stat().st_size==artifact["bytes"] and sha(p)==artifact["sha256"],"ARTIFACT_DRIFT",artifact["path"])
        if p.suffix==".png":
            w,h,rgba=decode_rgba_png(p); require([w,h]==artifact["dimensions"],"PNG_SIZE_DRIFT",p.name); require(hashlib.sha256(rgba).hexdigest()==artifact["decodedRgbaSha256"],"RGBA_HASH_DRIFT",p.name)
            require((w,h)==(384,384) or "contact-sheet" in p.name,"UNEXPECTED_PNG_SIZE",f"{p.name}: {(w,h)}")
            alpha=rgba[3::4]; require(any(a for a in alpha) and any(a==0 for a in alpha),"ALPHA_POLICY_MISMATCH",p.name)


def deterministic_rerender(asset,tmp):
    scene,root,cameras=builder.build(asset)
    paths=builder.render(scene,cameras,asset["assetId"],tmp)
    for rerender in paths:
        original=HERE/"renders"/rerender.name
        require(sha(rerender)==sha(original),"DETERMINISTIC_RERENDER_MISMATCH",rerender.name)
    return {p.name:sha(p) for p in paths}


def main():
    require(".".join(map(str,bpy.app.version))==CONFIG["toolchain"]["blenderVersion"],"BLENDER_VERSION_MISMATCH",str(bpy.app.version))
    results={}
    with tempfile.TemporaryDirectory(prefix="citysim-residential-civic-") as td:
        tmp=Path(td)
        for asset in CONFIG["assets"]:
            validate_scene(asset); validate_manifest(asset); results[asset["assetId"]]=deterministic_rerender(asset,tmp)
    preview=json.loads((HERE/"residential_civic_neighborhood_edge_manifest.json").read_text())
    require(preview["status"]=="source-only-review-evidence" and preview["liveAsset"] is False,"PREVIEW_STATUS_MISMATCH","preview")
    for artifact in preview["artifacts"]:
        p=HERE/artifact["path"]; require(p.is_file() and sha(p)==artifact["sha256"],"PREVIEW_ARTIFACT_DRIFT",artifact["path"])
    print("RESIDENTIAL_CIVIC_VALIDATION_PASS")
    print(json.dumps({"deterministicCanonicalPngSha256":results,"projectedTilePixels":[88,44],"pivotPixels":[192,300]},sort_keys=True))


if __name__=="__main__": main()
