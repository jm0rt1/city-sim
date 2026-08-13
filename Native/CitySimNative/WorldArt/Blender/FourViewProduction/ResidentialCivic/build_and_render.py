#!/usr/bin/env python3
"""Build original ResidentialCivic sources and canonical four-view renders."""

from __future__ import annotations

import hashlib
import json
import math
import sys
from array import array
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
CANONICAL = HERE.parents[1] / "FourViewPipeline"
sys.dont_write_bytecode = True
sys.path.insert(0, str(CANONICAL))
from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402

CONFIG = json.loads((HERE / "pipeline.json").read_text())
RENDERS = HERE / "renders"


def material(name, color, roughness=0.72, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    node = mat.node_tree.nodes["Principled BSDF"]
    node.inputs["Base Color"].default_value = color
    node.inputs["Roughness"].default_value = roughness
    node.inputs["Metallic"].default_value = metallic
    lowered = name.lower()
    if not any(token in lowered for token in ("glass", "clockface")):
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        coordinates = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        ramp = nodes.new("ShaderNodeValToRGB")
        bump_node = nodes.new("ShaderNodeBump")
        scale = 18.0 if any(token in lowered for token in ("roof", "tile", "slate")) else 10.0 if "brick" in lowered else 6.0
        noise.inputs["Scale"].default_value = scale
        noise.inputs["Detail"].default_value = 3.0
        noise.inputs["Roughness"].default_value = 0.62
        ramp.color_ramp.elements[0].position = 0.28
        ramp.color_ramp.elements[0].color = tuple(max(0.0, channel * 0.76) for channel in color[:3]) + (color[3],)
        ramp.color_ramp.elements[1].position = 0.74
        ramp.color_ramp.elements[1].color = tuple(min(1.0, channel * 1.12 + 0.018) for channel in color[:3]) + (color[3],)
        bump_node.inputs["Strength"].default_value = 0.20 if any(token in lowered for token in ("roof", "tile", "slate")) else 0.11
        bump_node.inputs["Distance"].default_value = 0.045
        links.new(coordinates.outputs["Generated"], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], node.inputs["Base Color"])
        links.new(noise.outputs["Fac"], bump_node.inputs["Height"])
        links.new(bump_node.outputs["Normal"], node.inputs["Normal"])
    return mat


def apply(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def soften(obj, width=0.035, segments=2):
    mod = obj.modifiers.new("EdgeSoftening", "BEVEL")
    mod.width, mod.segments, mod.limit_method = width, segments, "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def box(root, name, loc, dims, mat, rotation=(0, 0, 0), edge=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name, obj.dimensions = name, dims
    apply(obj)
    if edge:
        soften(obj, edge)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def cylinder(root, name, loc, radius, depth, mat, vertices=24, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    apply(obj)
    soften(obj, 0.018, 1)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def sphere(root, name, loc, scale, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=loc)
    obj = bpy.context.object
    obj.name, obj.scale = name, scale
    apply(obj)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def prism(root, name, loc, width, depth, eave, ridge, mat):
    x, y = width / 2, depth / 2
    verts = [(-x,-y,0),(x,-y,0),(-x,y,0),(x,y,0),(-x,-y,eave),(x,-y,eave),(-x,y,eave),(x,y,eave),(0,-y,ridge),(0,y,ridge)]
    faces = [(0,1,3,2),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3),(4,8,5),(6,7,9),(4,6,9,8),(8,9,7,5)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    soften(obj, 0.025, 1)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def roof_seams(root, prefix, loc, width, depth, eave, ridge, mat):
    slope = math.atan2(ridge - eave, width / 2)
    for index, fraction in enumerate((-.72, -.42, .42, .72), start=1):
        x = fraction * width / 2
        z = loc[2] + eave + (ridge - eave) * (1 - abs(fraction)) + .035
        box(root, f"{prefix}Seam{index}", (loc[0]+x,loc[1],z), (.045,depth+.08,.045), mat,
            rotation=(0,slope if x>0 else -slope,0), edge=.008)
    box(root, prefix+"RidgeCap", (loc[0],loc[1],loc[2]+ridge+.045), (.16,depth+.12,.13), mat, edge=.018)


def window(root, name, loc, dims, frame, glass):
    box(root, name + "Frame", loc, dims, frame, edge=0.016)
    inset = tuple(max(0.025, d - 0.10) for d in dims)
    box(root, name + "Glass", loc, inset, glass, edge=0.008)
    if dims[1] < dims[0]:
        box(root,name+"VerticalMuntin",loc,(.045,dims[1]+.025,max(.10,dims[2]-.08)),frame,edge=.006)
        box(root,name+"HorizontalMuntin",loc,(max(.10,dims[0]-.08),dims[1]+.025,.045),frame,edge=.006)
        box(root,name+"Sill",(loc[0],loc[1],loc[2]-dims[2]/2-.045),(dims[0]+.12,dims[1]+.08,.08),frame,edge=.01)
    else:
        box(root,name+"VerticalMuntin",loc,(dims[0]+.025,.045,max(.10,dims[2]-.08)),frame,edge=.006)
        box(root,name+"HorizontalMuntin",loc,(dims[0]+.025,max(.10,dims[1]-.08),.045),frame,edge=.006)
        box(root,name+"Sill",(loc[0],loc[1],loc[2]-dims[2]/2-.045),(dims[0]+.08,dims[1]+.12,.08),frame,edge=.01)


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(collection):
            collection.remove(block)
    scene = bpy.context.scene
    scene.name = "CitySimResidentialCivic"
    return scene


def configure(scene):
    c = CONFIG["canvas"]
    bpy.context.preferences.filepaths.save_version = 0
    scene.render.engine = CONFIG["toolchain"]["renderEngine"]
    scene.render.resolution_x = c["width"]
    scene.render.resolution_y = c["height"]
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.16,0.19,0.22,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = CONFIG["lighting"]["worldStrength"]
    scene["pipelineSchema"] = CONFIG["schema"]
    scene["postRenderCompensation"] = "none"
    scene["projectedTilePixels"] = CONFIG["grid"]["projectedTilePixels"]


def point_at(obj, target=Vector((0,0,0))):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def rig():
    cameras = []
    elevation = math.radians(CONFIG["grid"]["elevationDegrees"])
    distance = CONFIG["cameraRig"]["distance"]
    horizontal = distance * math.cos(elevation)
    for view in CONFIG["cameraRig"]["views"]:
        az = math.radians(view["azimuthDegrees"])
        data = bpy.data.cameras.new(view["name"])
        data.type, data.ortho_scale, data.shift_y = "ORTHO", CONFIG["cameraRig"]["orthoScale"], CONFIG["cameraRig"]["shiftY"]
        cam = bpy.data.objects.new(view["name"], data)
        bpy.context.collection.objects.link(cam)
        cam.location = (horizontal*math.sin(az), horizontal*math.cos(az), distance*math.sin(elevation))
        point_at(cam)
        cameras.append(cam)
    lc = CONFIG["lighting"]
    data = bpy.data.lights.new(lc["name"], lc["type"])
    data.energy, data.shape, data.size = lc["energy"], "DISK", lc["size"]
    light = bpy.data.objects.new(lc["name"], data)
    bpy.context.collection.objects.link(light)
    light.location = lc["location"]
    point_at(light)
    return cameras


def root_for(asset_id, description):
    root = bpy.data.objects.new("AssetRoot", None)
    bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.parent = root
    root["assetId"] = asset_id
    root["assetDescription"] = description
    root["sourcePixelsReused"] = False
    root["liveAsset"] = False
    root["fixedObjectScale"] = True
    return root


def house(root):
    m = {
        "lot": material("HouseLotSage", (0.30,0.39,0.25,1)), "stone": material("HouseStone", (0.48,0.39,0.29,1)),
        "wall": material("MarigoldStucco", (0.78,0.49,0.23,1)), "cream": material("HouseCream", (0.91,0.80,0.59,1)),
        "roof": material("TerracottaTile", (0.46,0.18,0.11,1), .62), "door": material("JuniperDoor", (0.10,0.27,0.25,1)),
        "glass": material("HouseGlass", (0.19,0.43,0.50,1), .28), "green": material("GardenGreen", (0.14,0.34,0.16,1)),
        "sand": material("CourtPavers", (0.70,0.57,0.39,1)), "metal": material("WarmIron", (0.15,0.12,0.10,1), .4, .35)
    }
    lot = box(root,"LotDiamond",(0,0,-.11),(4,4,.22),m["lot"],edge=.07); lot["worldFootprintTiles"]=[2,2]
    box(root,"StonePlinth",(0,.15,.15),(3.15,2.75,.30),m["stone"],edge=.05)
    box(root,"MainWing",(-.45,.35,1.10),(2.15,2.10,1.65),m["wall"],edge=.055)
    box(root,"CourtWing",(.83,.55,.92),(.95,1.72,1.30),m["wall"],edge=.05)
    prism(root,"MainRoof",(-.45,.35,1.90),2.48,2.43,.15,.73,m["roof"])
    prism(root,"CourtRoof",(.83,.55,1.60),1.18,2.02,.13,.49,m["roof"])
    roof_seams(root,"MainRoof",(-.45,.35,1.90),2.48,2.43,.15,.73,m["roof"])
    roof_seams(root,"CourtRoof",(.83,.55,1.60),1.18,2.02,.13,.49,m["roof"])
    # A projecting front gable and dormer break up the roof mass at gameplay scale.
    box(root,"FrontGableWall",(-.45,-.80,2.05),(1.04,.34,.62),m["cream"],edge=.035)
    prism(root,"FrontGableRoof",(-.45,-.92,2.30),1.34,.68,.10,.48,m["roof"])
    window(root,"DormerWindow",(-.45,-1.275,2.34),(.48,.05,.44),m["cream"],m["glass"])
    box(root,"CourtPaving",(.68,-.80,.27),(1.30,.83,.08),m["sand"],edge=.02)
    box(root,"EntryCanopy",(.28,-.72,1.55),(1.18,.58,.14),m["roof"],rotation=(math.radians(-7),0,0),edge=.02)
    for x in (-.18,.68): box(root,"CanopyPost"+str(x),(x,-.94,.90),(.08,.08,1.20),m["cream"],edge=.012)
    box(root,"RecessedDoor",(.24,-.715,.91),(.52,.06,1.16),m["door"],edge=.022)
    box(root,"DoorLintel",(.24,-.75,1.54),(.68,.12,.12),m["cream"],edge=.015)
    window(root,"FrontWindow",(-.78,-.715,1.13),(.64,.06,.68),m["cream"],m["glass"])
    window(root,"EastWindow",(1.315,.55,1.02),(.06,.64,.58),m["cream"],m["glass"])
    window(root,"WestWindow",(-1.535,.43,1.18),(.06,.70,.70),m["cream"],m["glass"])
    window(root,"RearWindow",(-.55,1.405,1.17),(.68,.06,.68),m["cream"],m["glass"])
    # Flower boxes give the facade depth, color, and a lived-in residential read.
    for index,(x,y,z,w,d) in enumerate(((-.78,-.78,.76,.72,.18),(1.39,.55,.70,.18,.72))):
        box(root,f"FlowerBox{index}",(x,y,z),(w,d,.15),m["stone"],edge=.025)
        for offset in (-.22,0,.22):
            px=x+offset if w>d else x
            py=y if w>d else y+offset
            sphere(root,f"FlowerPlant{index}_{offset}",(px,py,z+.16),(.10,.10,.13),m["green"])
    cylinder(root,"Chimney",(-.95,.80,2.72),.18,.70,m["stone"],vertices=16)
    cylinder(root,"ChimneyCap",(-.95,.80,3.09),.23,.08,m["metal"],vertices=16)
    for i,(x,y,s) in enumerate(((-1.45,-1.35,.31),(1.42,-1.32,.28),(1.48,1.34,.32),(.95,-1.32,.25))):
        cylinder(root,f"Planter{i}",(x,y,.28),s,.28,m["stone"],vertices=16)
        sphere(root,f"Plant{i}",(x,y,.58),(s*1.15,s*.92,s*1.30),m["green"])
    box(root,"BenchSeat",(-.67,-1.40,.46),(.78,.28,.10),m["metal"],edge=.02)
    for x in (-.96,-.38): box(root,"BenchLeg"+str(x),(x,-1.40,.30),(.07,.20,.28),m["metal"],edge=.01)
    # Low garden wall and gate establish a deliberate lot edge without obscuring the house.
    for x in (-1.46,1.46): box(root,"GardenPier"+str(x),(x,-1.53,.42),(.18,.18,.62),m["stone"],edge=.025)
    box(root,"GardenWall",(0,-1.55,.27),(2.55,.14,.30),m["stone"],edge=.025)
    box(root,"GardenGate",(.45,-1.59,.47),(.70,.06,.62),m["metal"],edge=.012)


def hall(root):
    m = {
        "lot": material("HallLotSage", (.29,.38,.25,1)), "stone": material("CivicStone", (.54,.47,.36,1)),
        "brick": material("CivicBrick", (.57,.27,.18,1)), "cream": material("CivicLimestone", (.88,.77,.57,1)),
        "roof": material("CivicSlate", (.12,.25,.29,1),.55), "door": material("CivicDoor", (.20,.10,.08,1)),
        "glass": material("CivicGlass", (.20,.45,.53,1),.28), "clock": material("ClockFace", (.94,.84,.59,1)),
        "dark": material("ClockHands", (.10,.09,.08,1),.38,.3), "flag": material("CivicFlag", (.65,.25,.16,1))
    }
    lot=box(root,"LotDiamond",(0,0,-.11),(4,4,.22),m["lot"],edge=.07); lot["worldFootprintTiles"]=[2,2]
    box(root,"CivicPlinth",(0,.12,.17),(3.30,2.70,.34),m["stone"],edge=.055)
    box(root,"HallBody",(0,.28,1.14),(2.95,2.22,1.75),m["brick"],edge=.05)
    box(root,"Cornice",(0,.28,2.04),(3.10,2.35,.18),m["cream"],edge=.025)
    # Limestone quoins and a modulated cornice keep the civic facade legible at a distance.
    for x in (-1.43,1.43):
        for z in (.48,.82,1.16,1.50,1.84):
            box(root,f"Quoin{x}_{z}",(x,-.865,z),(.22,.11,.20),m["cream"],edge=.016)
    for x in (-1.22,-.73,-.24,.24,.73,1.22):
        box(root,f"CorniceBlock{x}",(x,-.93,2.08),(.25,.18,.24),m["cream"],edge=.018)
    prism(root,"HallRoof",(0,.28,2.10),3.30,2.58,.14,.72,m["roof"])
    roof_seams(root,"HallRoof",(0,.28,2.10),3.30,2.58,.14,.72,m["roof"])
    box(root,"PublicStair",(0,-1.26,.28),(1.55,.78,.18),m["stone"],edge=.025)
    box(root,"PublicStairLower",(0,-1.50,.15),(1.90,.34,.14),m["stone"],edge=.02)
    box(root,"PorticoDeck",(0,-.98,.42),(1.52,.50,.12),m["cream"],edge=.025)
    for x in (-.58,.58): cylinder(root,"PorticoColumn"+str(x),(x,-1.15,1.18),.11,1.48,m["cream"],vertices=20)
    box(root,"PorticoBeam",(0,-1.15,1.94),(1.58,.28,.18),m["cream"],edge=.025)
    prism(root,"PorticoPediment",(0,-1.16,2.02),1.78,.46,.08,.46,m["cream"])
    box(root,"DoubleDoor",(0,-.845,1.08),(.82,.07,1.30),m["door"],edge=.02)
    box(root,"DoorSplit",(0,-.89,1.08),(.035,.035,1.20),m["cream"],edge=.005)
    window(root,"SouthWestWindow",(-1.02,-.845,1.27),(.56,.06,.68),m["cream"],m["glass"])
    window(root,"SouthEastWindow",(1.02,-.845,1.27),(.56,.06,.68),m["cream"],m["glass"])
    window(root,"EastHallWindow",(1.495,.38,1.25),(.06,.62,.68),m["cream"],m["glass"])
    window(root,"WestHallWindow",(-1.495,.38,1.25),(.06,.62,.68),m["cream"],m["glass"])
    box(root,"TowerBase",(0,.30,2.62),(1.00,.92,1.36),m["brick"],edge=.04)
    box(root,"TowerTrim",(0,.30,3.22),(1.12,1.04,.14),m["cream"],edge=.02)
    # Clock discs on all four tower faces ensure civic readability in every view.
    for name,loc,rot in (("South",(0,-.17,2.78),(math.radians(90),0,0)),("North",(0,.77,2.78),(math.radians(90),0,0)),("East",(.51,.30,2.78),(0,math.radians(90),0)),("West",(-.51,.30,2.78),(0,math.radians(90),0))):
        cylinder(root,"Clock"+name,loc,.28,.045,m["clock"],vertices=32,rotation=rot)
    # Open belfry: four piers, dark opening, visible bronze bell, and pyramidal cap.
    box(root,"BelfryDark",(0,.30,3.67),(.75,.68,.72),m["dark"],edge=.02)
    for x in (-.43,.43):
        for y in (-.09,.69): box(root,f"BelfryPier{x}{y}",(x,y,3.65),(.16,.16,.84),m["cream"],edge=.018)
    box(root,"BelfryLintel",(0,.30,4.03),(1.02,.92,.15),m["cream"],edge=.02)
    cylinder(root,"CouncilBell",(0,.30,3.60),.22,.34,m["clock"],vertices=20)
    prism(root,"TowerCap",(0,.30,4.10),1.22,1.12,.10,.62,m["roof"])
    cylinder(root,"FlagPole",(0,.30,5.12),.035,1.18,m["dark"],vertices=12)
    box(root,"CivicFlag",(.25,.30,5.35),(.50,.035,.28),m["flag"],edge=.008)
    # Symmetrical foundation planters soften the plinth while preserving civic formality.
    for i,x in enumerate((-1.38,1.38)):
        box(root,f"CivicPlanter{i}",(x,-1.35,.34),(.40,.40,.34),m["stone"],edge=.035)
        sphere(root,f"CivicShrub{i}",(x,-1.35,.67),(.30,.30,.38),m["dark"])


def build(asset):
    scene = reset(); configure(scene)
    root = root_for(asset["assetId"], asset["description"])
    (house if asset["assetId"] == "marigold_court_house" else hall)(root)
    cameras = rig(); scene.camera = cameras[0]
    return scene, root, cameras


def render(scene, cameras, asset_id, out_dir=RENDERS):
    out_dir.mkdir(parents=True, exist_ok=True)
    paths=[]
    for cam in cameras:
        path=out_dir/f"{asset_id}_{cam.name}.png"
        scene.camera=cam; scene.render.filepath=str(path)
        bpy.ops.render.render(write_still=True); canonicalize_png(path); paths.append(path)
    return paths


FONT = {c: rows for c,rows in {
    "A":["01110","10001","11111","10001","10001"],"C":["01111","10000","10000","10000","01111"],
    "E":["11111","10000","11110","10000","11111"],"H":["10001","10001","11111","10001","10001"],
    "I":["11111","00100","00100","00100","11111"],"L":["10000","10000","10000","10000","11111"],
    "M":["10001","11011","10101","10001","10001"],"N":["10001","11001","10101","10011","10001"],
    "O":["01110","10001","10001","10001","01110"],"R":["11110","10001","11110","10100","10010"],
    "S":["01111","10000","01110","00001","11110"],"T":["11111","00100","00100","00100","00100"],
    "U":["10001","10001","10001","10001","01110"],"V":["10001","10001","10001","01010","00100"],
    "W":["10001","10001","10101","11011","10001"],"D":["11110","10001","10001","10001","11110"],
    "G":["01111","10000","10111","10001","01110"],"P":["11110","10001","11110","10000","10000"],
    "F":["11111","10000","11110","10000","10000"],"B":["11110","10001","11110","10001","11110"],
    "Y":["10001","01010","00100","00100","00100"],"K":["10001","10010","11100","10010","10001"],
    " ":["00000"]*5
}.items()}


def contact_sheet(paths, asset_id):
    w=h=384; gap=16; label_h=28; sw=w*2+gap; sh=(h+label_h)*2+gap
    pix=bytearray(sw*sh*4)
    views=["CAMNE","CAMSE","CAMSW","CAMNW"]
    for idx,path in enumerate(paths):
        _,_,src=decode_rgba_png(path); col=idx%2; row=idx//2; ox=col*(w+gap); oy=row*(h+label_h+gap)
        for y in range(h):
            dst=((oy+y)*sw+ox)*4; start=y*w*4; pix[dst:dst+w*4]=src[start:start+w*4]
        bar_y=oy+h
        for y in range(bar_y,bar_y+label_h):
            for x in range(ox,ox+w):
                q=(y*sw+x)*4; pix[q:q+4]=bytes((37,43,43,255))
        text=views[idx]; scale=3; tx=ox+12; ty=bar_y+6
        for ci,ch in enumerate(text):
            for ry,bits in enumerate(FONT[ch]):
                for rx,on in enumerate(bits):
                    if on=="1":
                        for yy in range(scale):
                            for xx in range(scale):
                                q=((ty+ry*scale+yy)*sw+tx+ci*18+rx*scale+xx)*4; pix[q:q+4]=bytes((238,213,164,255))
    # decode_rgba_png and our drawing coordinates are top-origin; Blender image
    # buffers are bottom-origin. Flip once at the API boundary so both the
    # rendered panels and bitmap labels remain upright and left-to-right.
    blender_pixels=bytearray(len(pix)); stride=sw*4
    for y in range(sh):
        blender_pixels[y*stride:(y+1)*stride]=pix[(sh-1-y)*stride:(sh-y)*stride]
    img=bpy.data.images.new("LabeledContactSheet",sw,sh,alpha=True)
    img.pixels=[v/255 for v in blender_pixels]
    out=HERE/f"{asset_id}_contact-sheet.png"; img.file_format="PNG"; img.filepath_raw=str(out); img.save(); bpy.data.images.remove(img); canonicalize_png(out)
    return out


def hash_info(path):
    info={"path":path.relative_to(HERE).as_posix(),"bytes":path.stat().st_size,"sha256":hashlib.sha256(path.read_bytes()).hexdigest()}
    if path.suffix==".png":
        w,h,rgba=decode_rgba_png(path); info.update(dimensions=[w,h],decodedRgbaSha256=hashlib.sha256(rgba).hexdigest())
    return info


def write_manifest(asset, artifacts):
    data={"schema":"citysim.world-art.residential-civic-asset.v1","pipelineSchema":CONFIG["schema"],"assetId":asset["assetId"],"description":asset["description"],"status":"source-only-not-live","liveAsset":False,"originalGeometry":True,"sourcePixelsReused":False,"cameraOrder":[v["name"] for v in CONFIG["cameraRig"]["views"]],"grid":CONFIG["grid"],"canvas":CONFIG["canvas"],"cameraRig":CONFIG["cameraRig"],"lightingConvention":CONFIG["lighting"],"root":CONFIG["root"],"postRenderCompensation":"none","contactSheetLayout":[["camNE","camSE"],["camSW","camNW"]],"artifacts":[hash_info(p) for p in artifacts]}
    path=HERE/f"{asset['assetId']}_manifest.json"; path.write_text(json.dumps(data,indent=2,sort_keys=True)+"\n"); return path


def preview():
    scene=reset(); configure(scene)
    root=root_for("residential_civic_neighborhood_edge","Source-only exact-grid composed review preview")
    house_parent=bpy.data.objects.new("HouseGridPlacement",None); bpy.context.collection.objects.link(house_parent); house_parent.parent=root; house_parent.location=(-2,0,0)
    house(house_parent)
    hall_parent=bpy.data.objects.new("HallGridPlacement",None); bpy.context.collection.objects.link(hall_parent); hall_parent.parent=root; hall_parent.location=(2,0,0)
    hall(hall_parent)
    cameras=rig(); scene.camera=cameras[0]
    blend=HERE/"residential_civic_neighborhood_edge.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    path=HERE/"residential_civic_neighborhood_edge_camNE.png"; scene.render.filepath=str(path); bpy.ops.render.render(write_still=True); canonicalize_png(path)
    return blend,path


def main():
    actual=".".join(map(str,bpy.app.version))
    if actual != CONFIG["toolchain"]["blenderVersion"]: raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    manifests=[]
    for asset in CONFIG["assets"]:
        scene,root,cameras=build(asset)
        blend=HERE/f"{asset['assetId']}.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
        paths=render(scene,cameras,asset["assetId"]); sheet=contact_sheet(paths,asset["assetId"])
        manifests.append(write_manifest(asset,[blend,*paths,sheet]))
    pblend,png=preview()
    preview_manifest={"schema":"citysim.world-art.composed-preview.v1","status":"source-only-review-evidence","liveAsset":False,"grid":CONFIG["grid"],"placements":[{"assetId":a["assetId"],"originWorld":CONFIG["preview"]["gridPlacements"][i]} for i,a in enumerate(CONFIG["assets"])],"artifacts":[hash_info(pblend),hash_info(png)]}
    (HERE/"residential_civic_neighborhood_edge_manifest.json").write_text(json.dumps(preview_manifest,indent=2,sort_keys=True)+"\n")
    print("RESIDENTIAL_CIVIC_RENDER_PASS", len(manifests), "assets")


if __name__ == "__main__": main()
