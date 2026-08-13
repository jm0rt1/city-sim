#!/usr/bin/env python3
"""Procedurally model and render two original CitySim employment buildings."""

from __future__ import annotations

import hashlib
import json
import math
import os
import sys
from array import array
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
CANON = HERE.parent.parent / "FourViewPipeline"
OUT = Path(os.environ.get("CITYSIM_OUTPUT_DIR", HERE))
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANON))
from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402

CONFIG = json.loads((CANON / "pipeline.json").read_text())
VIEWS = CONFIG["cameraRig"]["views"]


def material(name, color, roughness=0.72, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = mat.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    lowered = name.lower()
    if not any(token in lowered for token in ("glass", "clockface")):
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        coordinates = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        ramp = nodes.new("ShaderNodeValToRGB")
        bump_node = nodes.new("ShaderNodeBump")
        scale = 18.0 if "roof" in lowered else 10.0 if "terracotta" in lowered else 6.0
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 3.0
        noise.inputs["Roughness"].default_value = 0.62
        ramp.color_ramp.elements[0].position = 0.28
        ramp.color_ramp.elements[0].color = tuple(max(0.0, channel * 0.76) for channel in color[:3]) + (color[3],)
        ramp.color_ramp.elements[1].position = 0.74
        ramp.color_ramp.elements[1].color = tuple(min(1.0, channel * 1.12 + 0.018) for channel in color[:3]) + (color[3],)
        bump_node.inputs["Strength"].default_value = 0.20 if "roof" in lowered else 0.11
        bump_node.inputs["Distance"].default_value = 0.045
        links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], shader.inputs["Base Color"])
        links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], shader.inputs["Normal"])
    return mat


def apply(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def box(root, name, loc, dims, mat, rotation=(0, 0, 0), bevel=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    apply(obj)
    if bevel:
        mod = obj.modifiers.new("EdgeSoftening", "BEVEL")
        mod.width, mod.segments, mod.limit_method = bevel, 2, "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def cylinder(root, name, loc, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    apply(obj)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def wedge_roof(root, name, loc, width, depth, low, high, mat):
    x, y = width / 2, depth / 2
    verts = [(-x,-y,0),(x,-y,0),(-x,y,0),(x,y,0),(-x,-y,low),(x,-y,low),(-x,y,high),(x,y,high)]
    faces = [(0,1,3,2),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3),(4,6,7,5)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces); mesh.update()
    obj = bpy.data.objects.new(name, mesh); bpy.context.collection.objects.link(obj)
    obj.location = loc; obj.data.materials.append(mat); obj.parent = root
    return obj


def reset(asset_id):
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for blocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(blocks): blocks.remove(block)
    scene = bpy.context.scene
    scene.name = "CitySimFourView"
    scene.render.engine = CONFIG["toolchain"]["renderEngine"]
    scene.render.resolution_x = scene.render.resolution_y = 384
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"; scene.render.image_settings.color_mode = "RGBA"; scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"; scene.view_settings.look = "Medium High Contrast"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = CONFIG["lighting"]["worldColor"]
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = CONFIG["lighting"]["worldStrength"]
    scene["pipelineSchema"] = CONFIG["schema"]; scene["postRenderCompensation"] = "none"; scene["assetId"] = asset_id
    root = bpy.data.objects.new("AssetRoot", None); bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None); bpy.context.collection.objects.link(pivot); pivot.parent = root
    return scene, root


def point_at(obj, target=Vector((0,0,0))):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def rig(scene):
    cams = []
    elevation = math.radians(30); distance = 32; horizontal = distance * math.cos(elevation)
    for view in VIEWS:
        az = math.radians(view["azimuthDegrees"])
        data = bpy.data.cameras.new(view["name"]); data.type = "ORTHO"; data.ortho_scale = 12.341995; data.shift_y = 0.28125
        cam = bpy.data.objects.new(view["name"], data); bpy.context.collection.objects.link(cam)
        cam.location = (horizontal*math.sin(az), horizontal*math.cos(az), distance*math.sin(elevation)); point_at(cam); cams.append(cam)
    lighting = CONFIG["lighting"]
    data = bpy.data.lights.new(lighting["name"], lighting["type"]); data.energy = lighting["energy"]; data.shape = "DISK"; data.size = lighting["size"]; data.color = lighting["color"]
    light = bpy.data.objects.new(lighting["name"], data); bpy.context.collection.objects.link(light); light.location = lighting["location"]; point_at(light)
    scene.camera = cams[0]
    return cams


def storefront(root):
    m = {
        "lot": material("StorefrontLot", (0.31,0.36,0.25,1)), "walk": material("StorefrontWalk", (0.68,0.58,0.43,1)),
        "brick": material("StorefrontTerracotta", (0.58,0.25,0.14,1)), "cream": material("StorefrontCream", (0.90,0.75,0.50,1)),
        "roof": material("StorefrontRoof", (0.13,0.28,0.28,1)), "glass": material("StorefrontGlass", (0.18,0.43,0.50,1), .3),
        "door": material("StorefrontDoor", (0.25,0.09,0.08,1)), "sign": material("StorefrontSign", (0.82,0.47,0.17,1)),
        "dark": material("StorefrontDark", (0.16,0.17,0.15,1)), "green": material("StorefrontPlanter", (0.18,0.37,0.16,1)),
    }
    box(root,"LotDiamond",(0,0,-.10),(4,4,.2),m["lot"],bevel=.06)
    box(root,"FrontWalk",(0,-1.48,.035),(3.35,.82,.07),m["walk"],bevel=.02)
    box(root,"StoreBody",(0,.22,1.42),(3.15,2.35,2.68),m["brick"],bevel=.055)
    box(root,"ParapetBand",(0,.22,2.79),(3.28,2.46,.24),m["cream"],bevel=.035)
    wedge_roof(root,"ShallowRoof",(0,.22,2.91),3.05,2.25,.08,.34,m["roof"])
    box(root,"RoofMechanicalCurb",(.72,.54,3.23),(.78,.62,.15),m["cream"],bevel=.025)
    box(root,"RoofMechanicalUnit",(.72,.54,3.36),(.60,.46,.22),m["dark"],bevel=.035)
    for x in (-1.42,1.42): box(root,"BrickPilaster",(x,-.08,1.47),(.18,2.18,2.55),m["cream"],bevel=.025)
    box(root,"RecessShadow",(0,-.985,1.02),(2.60,.09,1.50),m["dark"],bevel=.015)
    box(root,"CustomerDoor",(-.74,-1.05,.91),(.62,.12,1.46),m["door"],bevel=.025)
    box(root,"DoorGlass",(-.74,-1.12,1.18),(.38,.035,.72),m["glass"],bevel=.01)
    for i,x in enumerate((.08,.72,1.20)):
        box(root,f"DisplayWindow_{i+1}",(x,-1.05,1.08),(.50,.12,1.02),m["glass"],bevel=.018)
        box(root,f"WindowAwning_{i+1}",(x,-1.22,1.66),(.54,.38,.08),m["sign"],rotation=(math.radians(-8),0,0),bevel=.015)
    for x in (-.41,.40,.96): box(root,"Mullion",(x,-1.13,1.08),(.055,.04,1.08),m["cream"],bevel=.01)
    # Three recessed upper bays turn the storefront into a convincing mixed-use building.
    for i,x in enumerate((-.88,0,.88)):
        box(root,f"UpperWindowRecess_{i}",(x,-.985,2.14),(.63,.08,.67),m["dark"],bevel=.018)
        box(root,f"UpperWindow_{i}",(x,-1.035,2.14),(.49,.04,.53),m["glass"],bevel=.014)
        box(root,f"UpperMullion_{i}",(x,-1.065,2.14),(.045,.025,.49),m["cream"],bevel=.006)
        box(root,f"UpperSill_{i}",(x,-1.07,1.82),(.66,.14,.11),m["cream"],bevel=.014)
    for x in (-1.17,-.59,-.01,.57,1.15):
        box(root,f"ParapetDentil{x}",(x,-1.05,2.77),(.30,.18,.23),m["cream"],bevel=.018)
    # Secondary facades are authored geometry, not renderer compensation. Every
    # locked camera view must retain mixed-use identity when the street frontage
    # faces away from the viewer.
    for i,x in enumerate((-.88,0,.88)):
        box(root,f"RearWindowRecess_{i}",(x,1.405,1.82),(.63,.08,.78),m["dark"],bevel=.018)
        box(root,f"RearWindow_{i}",(x,1.455,1.82),(.49,.04,.64),m["glass"],bevel=.014)
        box(root,f"RearWindowSill_{i}",(x,1.47,1.39),(.67,.13,.11),m["cream"],bevel=.014)
    box(root,"RearServiceDoor",(-1.05,1.41,.83),(.56,.09,1.40),m["door"],bevel=.025)
    box(root,"RearDoorCanopy",(-1.05,1.61,1.65),(.88,.52,.12),m["roof"],rotation=(math.radians(6),0,0),bevel=.018)
    for side in (-1,1):
        side_x=side*1.585
        for i,y in enumerate((-.38,.48)):
            box(root,f"SideWindowRecess_{side}_{i}",(side_x,y,1.90),(.08,.58,.72),m["dark"],bevel=.016)
            box(root,f"SideWindow_{side}_{i}",(side_x+side*.05,y,1.90),(.035,.45,.58),m["glass"],bevel=.012)
    box(root,"EntranceCanopy",(-.72,-1.30,1.72),(1.05,.58,.13),m["roof"],rotation=(math.radians(-5),0,0),bevel=.02)
    box(root,"BladeSign",(-1.48,-1.18,1.73),(.13,.48,.72),m["sign"],bevel=.04)
    box(root,"SignBracket",(-1.48,-.91,2.00),(.10,.32,.10),m["dark"],bevel=.015)
    # Raised geometric storefront mark; readable as signage without text labels.
    for i,h in enumerate((.26,.42,.31)):
        box(root,f"SignGlyph_{i+1}",(-.23+i*.29,-1.19,2.08),(.18,.07,h),m["sign"],bevel=.025)
    for i,x in enumerate((-1.25,1.40)):
        box(root,f"Planter_{i+1}",(x,-1.35,.27),(.42,.38,.32),m["cream"],bevel=.04)
        cylinder(root,f"Plant_{i+1}",(x,-1.35,.58),.23,.48,m["green"],12)
    box(root,"CafeTable",(.62,-1.48,.43),(.38,.38,.08),m["dark"],bevel=.03)
    cylinder(root,"CafeTablePost",(.62,-1.48,.24),.045,.38,m["dark"],12)
    for i,x in enumerate((.28,.96)):
        box(root,f"CafeChair{i}",(x,-1.48,.30),(.24,.26,.48),m["sign"],bevel=.025)
    root["assetId"]="harbor_corner_storefront"; root["assetFamily"]="small-commercial"; root["sourcePixelsReused"]=False; root["liveAsset"]=False


def workshop(root):
    m = {
        "lot": material("WorkshopLot",(.29,.33,.27,1)), "slab": material("WorkshopSlab",(.48,.46,.40,1)),
        "wall": material("WorkshopWall",(.49,.45,.34,1)), "steel": material("WorkshopSteel",(.15,.25,.27,1),.48,.12),
        "roof": material("WorkshopRoof",(.22,.31,.31,1),.52,.08), "door": material("WorkshopDoor",(.65,.47,.25,1)),
        "glass": material("WorkshopGlass",(.20,.42,.47,1),.3), "accent": material("WorkshopAccent",(.68,.25,.13,1)),
        "crate": material("WorkshopCrate",(.43,.27,.13,1)), "dark": material("WorkshopDark",(.12,.14,.13,1)),
    }
    box(root,"LotDiamond",(0,0,-.10),(4,4,.2),m["lot"],bevel=.06)
    box(root,"ServiceApron",(.30,-1.25,.035),(3.35,1.18,.07),m["slab"],bevel=.025)
    box(root,"WorkshopBody",(-.18,.30,1.18),(3.30,2.20,2.18),m["wall"],bevel=.045)
    wedge_roof(root,"SawtoothRoof",(-.18,.30,2.30),3.42,2.30,.10,.68,m["roof"])
    for x in (-1.42,-.72,-.02,.68,1.38): box(root,"RoofRib",(x,.30,2.58),(.07,2.40,.16),m["steel"],bevel=.01)
    box(root,"LoadingRecess",(.56,-.84,1.08),(1.66,.10,1.72),m["dark"],bevel=.015)
    box(root,"RollupDoor",(.56,-.91,1.10),(1.48,.10,1.56),m["door"],bevel=.02)
    for z in (.55,.82,1.09,1.36,1.63): box(root,"DoorSlat",(.56,-.98,z),(1.38,.04,.035),m["steel"],bevel=.006)
    box(root,"LoadingBumper",(.56,-1.04,.25),(1.68,.22,.22),m["steel"],bevel=.025)
    box(root,"PersonnelDoor",(-1.10,-.91,.86),(.54,.10,1.42),m["accent"],bevel=.025)
    box(root,"DoorWindow",(-1.10,-.98,1.17),(.30,.035,.38),m["glass"],bevel=.01)
    box(root,"ServiceCanopy",(-1.10,-1.18,1.68),(.86,.52,.12),m["steel"],rotation=(math.radians(-6),0,0),bevel=.018)
    for x in (-1.05,-.28,.48,1.22): box(root,"Clerestory",(x,1.42,1.72),(.55,.05,.42),m["glass"],bevel=.015)
    for side in (-1,1):
        side_x=-.18+side*1.66
        for i,y in enumerate((-.18,.52,.98)):
            box(root,f"WorkshopSideWindow_{side}_{i}",(side_x,y,1.56),(.05,.48,.38),m["glass"],bevel=.012)
        box(root,f"WorkshopSideStripe_{side}",(side_x+side*.02,.28,.63),(.07,2.02,.16),m["accent"],bevel=.014)
    cylinder(root,"VentStack",(-1.05,.78,3.05),.19,.88,m["steel"],16)
    cylinder(root,"VentCap",(-1.05,.78,3.52),.28,.12,m["dark"],16)
    box(root,"RoofDuct",(.35,.65,3.03),(.88,.38,.32),m["steel"],bevel=.055)
    # Raised clerestory monitor creates an industrial silhouette instead of another flat box.
    box(root,"RoofMonitor",(.28,.38,3.00),(1.55,1.10,.56),m["wall"],bevel=.035)
    wedge_roof(root,"MonitorRoof",(.28,.38,3.29),1.72,1.26,.08,.34,m["roof"])
    for x in (-.20,.28,.76): box(root,"MonitorGlass",(x,-.185,3.04),(.32,.05,.29),m["glass"],bevel=.012)
    for x in (-1.42,-.78): cylinder(root,"SafetyBollard",(x,-1.18,.42),.055,.84,m["accent"],12)
    for i,(x,y,z) in enumerate(((1.40,-1.42,.30),(1.10,-1.52,.30))):
        box(root,f"ShippingCrate_{i+1}",(x,y,z),(.48,.48,.58),m["crate"],bevel=.025)
    for i,x in enumerate((-.18,.12)):
        cylinder(root,f"ServiceDrum{i}",(x,-1.48,.37),.18,.62,m["accent"],20)
        box(root,f"DrumBand{i}",(x,-1.48,.38),(.39,.39,.06),m["dark"],bevel=.01)
    root["assetId"]="ironleaf_service_workshop"; root["assetFamily"]="light-industrial"; root["sourcePixelsReused"]=False; root["liveAsset"]=False


def rgba_hash(path):
    w,h,p = decode_rgba_png(path); return w,h,hashlib.sha256(p).hexdigest()


def render_asset(asset_id, builder):
    asset_dir = OUT / asset_id; render_dir = asset_dir / "renders"; render_dir.mkdir(parents=True, exist_ok=True)
    scene, root = reset(asset_id); builder(root); cams = rig(scene)
    blend = asset_dir / f"{asset_id}.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend), check_existing=False)
    renders=[]
    for cam in cams:
        path=render_dir/f"{asset_id}_{cam.name}.png"; scene.camera=cam; scene.render.filepath=str(path); bpy.ops.render.render(write_still=True); canonicalize_png(path); renders.append(path)
    sheet = contact_sheet(asset_id, renders)
    artifacts=[]
    for path in [blend,*renders,sheet]:
        item={"path":path.relative_to(OUT).as_posix(),"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
        if path.suffix==".png": w,h,rh=rgba_hash(path); item.update(dimensions=[w,h],decodedRgbaSha256=rh)
        artifacts.append(item)
    manifest={"schema":"citysim.four-view-production.v1","assetId":asset_id,"assetFamily":root["assetFamily"],"status":"source-only-not-live","originalGeometry":True,"sourcePixelsReused":False,"liveAsset":False,"pipelineSchema":CONFIG["schema"],"projectedTilePixels":[88,44],"canvas":{"width":384,"height":384,"transparent":True,"trim":False,"footprintPivotPixel":[192,300]},"cameraOrder":[v["name"] for v in VIEWS],"cameraAzimuthDegrees":{v["name"]:v["azimuthDegrees"] for v in VIEWS},"elevationDegrees":30,"lightingConvention":CONFIG["lighting"],"postRenderCompensation":"none","artifacts":artifacts}
    (asset_dir/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")
    return renders


FONT={"A":["01110","10001","11111","10001","10001"],"C":["01111","10000","10000","10000","01111"],"E":["11111","10000","11110","10000","11111"],"F":["11111","10000","11110","10000","10000"],"H":["10001","10001","11111","10001","10001"],"I":["11111","00100","00100","00100","11111"],"K":["10001","10010","11100","10010","10001"],"L":["10000","10000","10000","10000","11111"],"M":["10001","11011","10101","10001","10001"],"N":["10001","11001","10101","10011","10001"],"O":["01110","10001","10001","10001","01110"],"P":["11110","10001","11110","10000","10000"],"R":["11110","10001","11110","10010","10001"],"S":["01111","10000","01110","00001","11110"],"T":["11111","00100","00100","00100","00100"],"W":["10001","10001","10101","10101","01010"]," ":["00000"]*5}


def draw_label(buf,w,h,text,x,y,scale=2):
    for ch in text:
        glyph=FONT.get(ch,FONT[" "])
        for gy,row in enumerate(glyph):
            for gx,on in enumerate(row):
                if on=="1":
                    for sy in range(scale):
                        for sx in range(scale):
                            px,py=x+gx*scale+sx,y+(4-gy)*scale+sy
                            idx=(py*w+px)*4; buf[idx:idx+4]=array("f",(0.96,0.90,0.72,1.0))
        x += 6*scale


def contact_sheet(asset_id, paths):
    w,h,g,label=384,384,16,24; sw,sh=w*2+g,h*2+g+label*2
    pix=array("f",[0])* (sw*sh*4)
    positions=((0,h+g+label),(w+g,h+g+label),(0,label),(w+g,label))
    for path,(ox,oy),view in zip(paths,positions,VIEWS):
        img=bpy.data.images.load(str(path),check_existing=False); src=array("f",img.pixels[:])
        for row in range(h): pix[((row+oy)*sw+ox)*4:((row+oy)*sw+ox+w)*4]=src[row*w*4:(row+1)*w*4]
        bpy.data.images.remove(img); draw_label(pix,sw,sh,view["name"].upper(),ox+8,oy-18,2)
    image=bpy.data.images.new("LabeledContactSheet",width=sw,height=sh,alpha=True); image.pixels[:]=pix; image.file_format="PNG"
    path=OUT/asset_id/f"{asset_id}_contact-sheet.png"; image.filepath_raw=str(path); image.save(); bpy.data.images.remove(image); canonicalize_png(path); return path


def preview():
    scene,root=reset("employment_block_preview")
    # Exact tile centers: two 2x2-tile lots separated by one world unit; no asset scaling.
    left=bpy.data.objects.new("StorefrontPlacement",None); bpy.context.collection.objects.link(left); left.location=(-2.5,0,0); left.parent=root; storefront(left)
    right=bpy.data.objects.new("WorkshopPlacement",None); bpy.context.collection.objects.link(right); right.location=(2.5,0,0); right.parent=root; workshop(right)
    cams=rig(scene); scene.camera=cams[1]
    path=OUT/"employment_block_preview.png"; scene.render.filepath=str(path); bpy.ops.render.render(write_still=True); canonicalize_png(path)
    blend=OUT/"employment_block_preview.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    w,h,rh=rgba_hash(path)
    manifest={"schema":"citysim.composed-preview.v1","status":"source-only-review-evidence-not-live","camera":"camSE","assetScale":[1,1,1],"grid":{"worldTileSize":2,"projectedTilePixels":[88,44],"placementCentersWorld":[[-2.5,0],[2.5,0]]},"assets":["harbor_corner_storefront","ironleaf_service_workshop"],"artifacts":[{"path":blend.relative_to(OUT).as_posix(),"sha256":hashlib.sha256(blend.read_bytes()).hexdigest(),"bytes":blend.stat().st_size},{"path":path.relative_to(OUT).as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"decodedRgbaSha256":rh,"dimensions":[w,h],"bytes":path.stat().st_size}]}
    (OUT/"employment_block_preview_manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n")


def main():
    if ".".join(map(str,bpy.app.version)) != "4.5.12": raise RuntimeError("BLENDER_VERSION_MISMATCH")
    render_asset("harbor_corner_storefront",storefront)
    render_asset("ironleaf_service_workshop",workshop)
    preview()
    print("COMMERCIAL_INDUSTRIAL_RENDERED")


if __name__ == "__main__": main()
