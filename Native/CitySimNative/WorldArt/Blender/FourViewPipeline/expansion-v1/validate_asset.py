#!/usr/bin/env python3
"""Validate one expansion-v1 source model and its untrimmed four-view renders."""
from __future__ import annotations
import hashlib, json, math, sys
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
CONFIG=json.loads((ROOT/"pipeline.json").read_text())
sys.path.insert(0,str(ROOT))
from png_canonical import decode_rgba_png

def fail(code, detail): raise RuntimeError(f"{code}: {detail}")
def close(a,b,label,t=1e-4):
    if abs(float(a)-float(b))>t: fail("VALUE_MISMATCH",f"{label}: {a} != {b}")
def vec(a,b,label,t=1e-4):
    if len(a)!=len(b): fail("VECTOR_LENGTH_MISMATCH",label)
    for i,(x,y) in enumerate(zip(a,b)): close(x,y,f"{label}[{i}]",t)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
    if len(args)!=1: fail("USAGE","validate_asset.py -- assets/<id>")
    directory=(ROOT/args[0]).resolve(); manifest=json.loads((directory/"manifest.json").read_text()); scene=bpy.context.scene
    if ".".join(map(str,bpy.app.version))!=CONFIG["toolchain"]["blenderVersion"]: fail("BLENDER_VERSION_MISMATCH",bpy.app.version_string)
    if scene.render.engine!=CONFIG["toolchain"]["renderEngine"]: fail("RENDER_ENGINE_MISMATCH",scene.render.engine)
    if (scene.render.resolution_x,scene.render.resolution_y,scene.render.resolution_percentage)!=(384,384,100) or not scene.render.film_transparent: fail("CANVAS_MISMATCH","384 transparent untrimmed")
    root,pivot=bpy.data.objects.get("AssetRoot"),bpy.data.objects.get("FootprintPivot")
    if not root or not pivot or pivot.parent!=root: fail("ROOT_PIVOT_MISMATCH",str((root,pivot)))
    vec(root.location,(0,0,0),"root.location"); vec(root.rotation_euler,(0,0,0),"root.rotation"); vec(root.scale,(1,1,1),"root.scale")
    if root.get("sourcePixelsReused") is not False or root.get("liveAsset") is not False: fail("PROVENANCE_MISMATCH",root.name)
    meshes=[o for o in bpy.data.objects if o.type=="MESH"]
    if len(meshes)<4: fail("TOO_SIMPLE",len(meshes))
    for obj in meshes:
        if obj.parent!=root: fail("MESH_OUTSIDE_ROOT",obj.name)
        vec(obj.scale,(1,1,1),obj.name+".scale"); vec(obj.rotation_euler,(0,0,0),obj.name+".rotation")
    lights=[o for o in bpy.data.objects if o.type=="LIGHT"]
    if [o.name for o in lights]!=["CitySimKey"]: fail("LIGHT_CONVENTION_MISMATCH",str([o.name for o in lights]))
    vec(lights[0].location,CONFIG["lighting"]["location"],"light.location"); close(lights[0].data.energy,CONFIG["lighting"]["energy"],"light.energy")
    seen=[]
    for view in CONFIG["cameraRig"]["views"]:
        cam=bpy.data.objects.get(view["name"])
        if not cam or cam.data.type!="ORTHO": fail("CAMERA_MISMATCH",view["name"])
        close(cam.data.ortho_scale,CONFIG["cameraRig"]["orthoScale"],cam.name+".ortho",1e-5); close(cam.data.shift_y,CONFIG["cameraRig"]["shiftY"],cam.name+".shift")
        ndc=world_to_camera_view(scene,cam,Vector((0,0,0))); vec((ndc.x*384,(1-ndc.y)*384),(192,300),cam.name+".pivot",.01)
        path=directory/"renders"/f"{manifest['assetId']}_{view['name']}.png"; width,height,rgba=decode_rgba_png(path)
        if (width,height)!=(384,384): fail("RENDER_SIZE_MISMATCH",path.name)
        alpha=rgba[3::4]
        if not any(alpha) or all(alpha): fail("ALPHA_POLICY_MISMATCH",path.name)
        seen.append(path)
    if manifest["pipelineSchema"]!=CONFIG["schema"] or manifest["postRenderCompensation"]!="none" or manifest["liveAsset"]: fail("MANIFEST_CONTRACT_MISMATCH",directory.name)
    for artifact in manifest["artifacts"]:
        path=ROOT/artifact["path"]
        if not path.is_file() or sha(path)!=artifact["sha256"]: fail("ARTIFACT_DRIFT",artifact["path"])
    print("FOUR_VIEW_PIPELINE_PASS",manifest["assetId"])
if __name__=="__main__": main()
