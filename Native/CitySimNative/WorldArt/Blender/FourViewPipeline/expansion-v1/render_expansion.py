#!/usr/bin/env python3
"""Render the original CitySim expansion-v1 four-view candidate catalog.

Every entry is modeled as its own Blender scene with a shared locked camera,
lighting, root, and canvas contract. This remains generation-only source art.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from array import array
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
CONFIG = json.loads((ROOT / "pipeline.json").read_text(encoding="utf-8"))
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT))
from png_canonical import canonicalize_png, decode_rgba_png  # noqa: E402


# 40 distinct typologies, proportioned to the admitted 20-variant baseline.
ASSETS = [
    ("res_cedar_cottage", "residential", "cottage"), ("res_brick_rowhouse", "residential", "rowhouse"),
    ("res_duplex_gable", "residential", "duplex"), ("res_courtyard_walkup", "residential", "courtyard"),
    ("res_tower_setback", "residential", "tower"), ("res_terrace_home", "residential", "terrace"),
    ("res_bay_bungalow", "residential", "bungalow"), ("res_lodge_apartments", "residential", "lodge"),
    ("res_corner_townhomes", "residential", "townhomes"), ("res_roof_garden_flats", "residential", "roofgarden"),
    ("res_stacked_duplex", "residential", "stacked"), ("res_villa_wing", "residential", "villa"),
    ("res_arcade_residence", "residential", "arcade"), ("res_stepped_apartments", "residential", "stepped"),
    ("com_corner_grocer", "commercial", "grocer"), ("com_market_hall", "commercial", "market"),
    ("com_glass_offices", "commercial", "glassoffice"), ("com_theater", "commercial", "theater"),
    ("com_arcade_shops", "commercial", "arcadeshops"), ("com_brick_hotel", "commercial", "hotel"),
    ("com_rooftop_cafe", "commercial", "cafe"), ("com_department_store", "commercial", "department"),
    ("com_transit_mart", "commercial", "transitmart"), ("com_midrise_offices", "commercial", "midrise"),
    ("ind_sawtooth_works", "industrial", "sawtooth"), ("ind_cylinder_depot", "industrial", "cylinder"),
    ("ind_warehouse_bay", "industrial", "warehouse"), ("ind_foundry_hall", "industrial", "foundry"),
    ("ind_brewery_tanks", "industrial", "brewery"), ("ind_freight_terminal", "industrial", "freight"),
    ("ind_silo_yard", "industrial", "silos"), ("ind_repair_shed", "industrial", "repair"),
    ("civ_firehouse", "civic-service", "firehouse"), ("civ_schoolhouse", "civic-service", "school"),
    ("civ_police_station", "civic-service", "police"), ("civ_community_clinic", "civic-service", "clinic"),
    ("util_waterworks", "utility", "waterworks"), ("util_electric_substation", "utility", "substation"),
    ("park_garden_pavilion", "park-landmark", "pavilion"), ("landmark_clock_tower", "park-landmark", "clocktower"),
]

PALETTES = {
    "residential": ((0.57, 0.25, 0.17, 1), (0.16, 0.31, 0.34, 1), (0.83, 0.69, 0.48, 1)),
    "commercial": ((0.38, 0.34, 0.29, 1), (0.10, 0.22, 0.29, 1), (0.78, 0.65, 0.38, 1)),
    "industrial": ((0.33, 0.29, 0.24, 1), (0.22, 0.29, 0.29, 1), (0.64, 0.42, 0.22, 1)),
    "civic-service": ((0.47, 0.39, 0.31, 1), (0.18, 0.28, 0.34, 1), (0.82, 0.73, 0.56, 1)),
    "utility": ((0.32, 0.35, 0.34, 1), (0.16, 0.24, 0.27, 1), (0.63, 0.55, 0.35, 1)),
    "park-landmark": ((0.43, 0.37, 0.27, 1), (0.13, 0.31, 0.20, 1), (0.72, 0.63, 0.40, 1)),
}


def material(name, color, roughness=0.72):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = color
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = color
    p.inputs["Roughness"].default_value = roughness
    return m


def apply(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def soft(obj, width=0.04):
    mod = obj.modifiers.new("EdgeSoftening", "BEVEL")
    mod.width, mod.segments, mod.limit_method = width, 2, "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def box(root, name, loc, dims, mat, rot=(0, 0, 0), edge=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name, obj.dimensions = name, dims
    apply(obj)
    if edge: soft(obj, edge)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def cylinder(root, name, loc, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    obj.name = name
    apply(obj)
    soft(obj, 0.025)
    obj.data.materials.append(mat)
    obj.parent = root
    return obj


def gable(root, name, loc, width, depth, eave, ridge, mat):
    x, y = width / 2, depth / 2
    verts = [(-x,-y,0),(x,-y,0),(-x,y,0),(x,y,0),(-x,-y,eave),(x,-y,eave),(-x,y,eave),(x,y,eave),(0,-y,ridge),(0,y,ridge)]
    faces = [(0,1,3,2),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3),(4,8,5),(6,7,9),(4,6,9,8),(8,9,7,5)]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces); mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj); obj.location = loc
    soft(obj, 0.025); obj.data.materials.append(mat); obj.parent = root
    return obj


def window(root, name, loc, dims, glass):
    return box(root, name, loc, dims, glass, edge=0.012)


def reset_scene():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(collection): collection.remove(block)
    return bpy.context.scene


def point_at(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def configure(scene):
    c = CONFIG["canvas"]
    scene.name = "CitySimExpansionV1"
    scene.render.engine = CONFIG["toolchain"]["renderEngine"]
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = c["width"], c["height"], 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format, scene.render.image_settings.color_mode, scene.render.image_settings.color_depth = "PNG", "RGBA", "8"
    scene.render.image_settings.compression = 15
    scene.view_settings.view_transform, scene.view_settings.look = "Standard", "Medium High Contrast"
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.16, 0.19, 0.22, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = CONFIG["lighting"]["worldStrength"]
    scene["pipelineSchema"], scene["postRenderCompensation"] = CONFIG["schema"], "none"


def rig(scene):
    root = bpy.data.objects.new("AssetRoot", None); root.empty_display_type = "PLAIN_AXES"; bpy.context.collection.objects.link(root)
    pivot = bpy.data.objects.new("FootprintPivot", None); pivot.parent = root; pivot.empty_display_type = "CIRCLE"; bpy.context.collection.objects.link(pivot)
    elevation, distance = math.radians(30), CONFIG["cameraRig"]["distance"]
    horizontal = distance * math.cos(elevation); cameras = []
    for view in CONFIG["cameraRig"]["views"]:
        a = math.radians(view["azimuthDegrees"])
        data = bpy.data.cameras.new(view["name"]); data.type = "ORTHO"; data.ortho_scale = CONFIG["cameraRig"]["orthoScale"]; data.shift_y = CONFIG["cameraRig"]["shiftY"]
        cam = bpy.data.objects.new(view["name"], data); bpy.context.collection.objects.link(cam)
        cam.location = (horizontal * math.sin(a), horizontal * math.cos(a), distance * math.sin(elevation)); point_at(cam, Vector((0,0,0))); cameras.append(cam)
    lc = CONFIG["lighting"]; light_data = bpy.data.lights.new("CitySimKey", "AREA"); light_data.energy, light_data.shape, light_data.size = lc["energy"], "DISK", lc["size"]
    light = bpy.data.objects.new("CitySimKey", light_data); bpy.context.collection.objects.link(light); light.location = lc["location"]; point_at(light, Vector((0,0,0)))
    scene.camera = cameras[0]
    return root, cameras


def build(root, family, typology):
    wall_color, roof_color, accent_color = PALETTES[family]
    wall, roof, accent = material("Wall", wall_color), material("Roof", roof_color, 0.58), material("Accent", accent_color)
    stone, glass, green = material("Stone", (0.42,0.37,0.31,1)), material("Glass", (0.15,0.39,0.48,1), 0.30), material("Green", (0.13,0.31,0.17,1))
    # The family massing remains cohesive; each named typology changes roof, height, or footprint.
    if family == "residential":
        styles = {
            "cottage": (2.5,2.2,1.65,"gable"), "rowhouse": (3.6,1.8,2.25,"flat"), "duplex": (3.7,2.3,1.8,"double"), "courtyard": (3.8,3.5,2.5,"court"),
            "tower": (2.35,2.35,4.7,"setback"), "terrace": (3.7,2.6,2.2,"terrace"), "bungalow": (3.3,2.8,1.45,"hip"), "lodge": (3.4,2.6,3.2,"gable"),
            "townhomes": (4.0,2.1,2.6,"steps"), "roofgarden": (3.2,2.8,3.0,"flat"), "stacked": (2.7,2.7,3.4,"flat"), "villa": (3.9,3.0,2.0,"wing"),
            "arcade": (3.6,2.4,3.0,"arcade"), "stepped": (3.4,2.8,3.8,"setback")}
        w,d,h,form = styles[typology]; box(root,"Foundation",(0,0,0.16),(w+.28,d+.28,.32),stone)
        if form == "court":
            for x,y in ((-1.2,0),(1.2,0),(0,1.15)): box(root,"CourtWing",(x,y,h/2+.32),(1.25,1.2,h),wall)
        elif form == "wing":
            box(root,"MainWing",(-.62,.15,h/2+.32),(w*.65,d,h),wall); box(root,"GardenWing",(1.08,-.42,h*.42+.32),(w*.35,d*.62,h*.84),wall)
        else:
            box(root,"Residence",(0,0,h/2+.32),(w,d,h),wall)
        if form in ("gable","double"):
            gable(root,"Roof",(0,0,h+.32),w+.34,d+.34,.12,.72,roof)
            if form == "double": gable(root,"CrossRoof",(0,0,h+.32),d+.34,w+.34,.12,.58,roof)
        elif form == "hip":
            cylinder(root,"HipRoof",(0,0,h+.45),min(w,d)*.76,.28,roof,4)
        elif form == "terrace":
            box(root,"UpperTerrace",(-.65,.2,h+1.02),(w*.62,d*.72,1.55),wall); box(root,"Parapet",(0,0,h+.71),(w+.16,d+.16,.16),roof)
        elif form == "setback":
            box(root,"UpperSetback",(0,.2,h+1.05),(w*.68,d*.68,h*.44),wall); box(root,"Crown",(0,.2,h*1.5+.92),(w*.74,d*.74,.18),roof)
        elif form == "steps":
            for i in range(3): box(root,"Townhome",(-1.25+i*1.25,0,h/2+.32+i*.15),(1.12,d,h+i*.3),wall)
        elif form == "arcade":
            for x in (-1.05,0,1.05): box(root,"ArcadePier",(x,-d/2-.05,.72),(.23,.22,1.25),accent)
            box(root,"ArcadeLintel",(0,-d/2-.05,1.35),(w+.15,.22,.22),accent)
        elif form == "flat": box(root,"Parapet",(0,0,h+.40),(w+.16,d+.16,.16),roof)
        for x in (-w*.28,w*.28): window(root,"FrontWindow",(x,-d/2-.025,h*.56+.38),(.52,.055,.65),glass)
        box(root,"Door",(0,-d/2-.04,.87),(.48,.07,1.15),accent)
    elif family == "commercial":
        styles = {"grocer":(3.6,2.8,1.8,"awning"),"market":(4.3,3.2,2.35,"gable"),"glassoffice":(2.9,2.7,4.3,"glass"),"theater":(4.2,2.7,2.8,"marquee"),"arcadeshops":(4.0,2.3,2.4,"arcade"),"hotel":(3.3,3.0,4.5,"hotel"),"cafe":(3.0,2.5,2.2,"terrace"),"department":(4.4,3.1,3.1,"flat"),"transitmart":(4.2,2.6,1.7,"canopy"),"midrise":(3.0,2.8,5.0,"setback")}
        w,d,h,form=styles[typology]; box(root,"CommercialPlinth",(0,0,.16),(w+.25,d+.25,.32),stone); box(root,"CommercialMass",(0,0,h/2+.32),(w,d,h),wall)
        if form == "gable": gable(root,"MarketRoof",(0,0,h+.32),w+.3,d+.3,.12,.75,roof)
        elif form == "glass":
            for z in (1.3,2.35,3.4): window(root,"GlassBand",(0,-d/2-.035,z),(w*.82,.07,.48),glass)
        elif form == "marquee": box(root,"Marquee",(0,-d/2-.38,1.5),(w+.45,.72,.25),accent)
        elif form == "arcade":
            for x in (-1.2,0,1.2): box(root,"ShopPier",(x,-d/2-.05,.75),(.22,.2,1.3),accent)
        elif form == "hotel": box(root,"HotelCrown",(0,0,h+.38),(w+.22,d+.22,.22),roof); box(root,"Lobby",(0,-d*.36,1.05),(w*.78,d*.32,1.45),accent)
        elif form == "terrace": box(root,"RoofCafe",(0,.15,h+.9),(w*.75,d*.65,1.15),wall); box(root,"Canopy",(0,-d*.30,h+.28),(w*.72,d*.32,.12),accent)
        elif form == "canopy": box(root,"TransitCanopy",(0,-d*.6,1.55),(w+.45,.75,.18),accent)
        elif form == "setback": box(root,"OfficeSetback",(0,.1,h+1.1),(w*.68,d*.68,h*.35),wall); box(root,"OfficeCrown",(0,.1,h*1.47+.95),(w*.76,d*.76,.18),roof)
        else: box(root,"RoofBand",(0,0,h+.39),(w+.18,d+.18,.16),roof)
        for x in (-w*.27,w*.27): window(root,"Storefront",(x,-d/2-.04,1.13),(.72,.06,.85),glass)
    elif family == "industrial":
        styles={"sawtooth":(4.3,3.0,1.8,"teeth"),"cylinder":(3.5,3.2,1.6,"tanks"),"warehouse":(4.5,3.0,2.25,"warehouse"),"foundry":(3.8,3.4,2.8,"stack"),"brewery":(3.8,3.2,1.7,"brewery"),"freight":(4.6,2.8,1.5,"terminal"),"silos":(3.8,3.5,1.25,"silos"),"repair":(4.0,2.8,1.8,"shed")}
        w,d,h,form=styles[typology]; box(root,"IndustrialBase",(0,0,.15),(w+.25,d+.25,.3),stone); box(root,"IndustrialHall",(0,0,h/2+.3),(w,d,h),wall)
        if form == "teeth":
            for x in (-1.35,-.45,.45,1.35): gable(root,"SawRoof",(x,0,h+.3),.8,d+.18,.08,.56,roof)
        elif form in ("tanks","brewery"):
            for x in (-.9,0,.9): cylinder(root,"ProcessTank",(x,.35,h+1.0),.42,2.0,accent)
        elif form == "warehouse": gable(root,"WarehouseRoof",(0,0,h+.3),w+.3,d+.3,.12,.7,roof)
        elif form == "stack": cylinder(root,"FoundryStack",(1.12,.5,h+1.7),.28,3.3,roof)
        elif form == "terminal": box(root,"LoadingCanopy",(0,-d*.62,1.45),(w+.35,.65,.18),accent)
        elif form == "silos":
            for x,y in ((-.8,-.45),(.8,-.45),(0,.72)): cylinder(root,"Silo",(x,y,1.75),.52,3.15,accent)
        elif form == "shed": gable(root,"RepairRoof",(0,0,h+.3),w+.3,d+.3,.12,.56,roof)
        if form not in ("teeth","warehouse","shed"): box(root,"IndustrialRoof",(0,0,h+.4),(w+.16,d+.16,.16),roof)
        for x in (-w*.25,w*.25): box(root,"LoadingDoor",(x,-d/2-.04,.85),(.75,.07,1.1),accent)
    elif family == "civic-service":
        styles={"firehouse":(4.0,2.7,2.0,"bays"),"school":(4.2,3.1,2.4,"school"),"police":(3.4,2.8,2.5,"tower"),"clinic":(3.6,3.0,2.7,"clinic")}
        w,d,h,form=styles[typology]; box(root,"CivicPlinth",(0,0,.17),(w+.28,d+.28,.34),stone); box(root,"CivicMass",(0,0,h/2+.34),(w,d,h),wall)
        if form == "bays":
            for x in (-1.05,0,1.05): box(root,"FireBay",(x,-d/2-.045,.85),(.72,.07,1.15),accent)
            cylinder(root,"HoseTower",(1.3,.45,h+1.15),.48,2.2,wall)
        elif form == "school": gable(root,"SchoolRoof",(0,0,h+.34),w+.32,d+.32,.12,.7,roof); box(root,"Entry",(0,-d*.42,1.05),(1.15,.36,1.5),accent)
        elif form == "tower": cylinder(root,"PoliceTower",(0,.35,h+1.2),.56,2.25,wall); box(root,"RoofBand",(0,0,h+.42),(w+.18,d+.18,.16),roof)
        else: box(root,"ClinicWing",(0,.4,h+1.0),(w*.68,d*.55,1.35),wall); box(root,"Canopy",(0,-d*.55,1.35),(w*.55,.55,.14),accent)
        window(root,"CivicWindow",(-w*.26,-d/2-.04,h*.58+.36),(.65,.06,.7),glass); window(root,"CivicWindow",(w*.26,-d/2-.04,h*.58+.36),(.65,.06,.7),glass)
    elif family == "utility":
        if typology == "waterworks":
            box(root,"WaterworksHall",(0,0,1.25),(3.7,3.0,2.3),wall); cylinder(root,"WaterTank",(-.9,.45,3.25),.72,2.0,accent); cylinder(root,"WaterTank",(.9,.45,3.25),.72,2.0,accent); box(root,"PumpHouse",(0,-1.25,.85),(2.1,.7,1.35),roof)
        else:
            box(root,"SubstationBase",(0,0,.16),(4.0,3.1,.32),stone)
            for x in (-1.25,0,1.25): cylinder(root,"Transformer",(x,.2,.95),.36,1.55,wall); box(root,"TransmissionFrame",(x,.42,2.05),(.18,.18,1.75),accent)
            box(root,"ControlShed",(0,-.88,1.0),(2.1,1.05,1.55),roof)
    else:
        if typology == "pavilion":
            for x,y in ((-1.25,-.8),(1.25,-.8),(-1.25,.8),(1.25,.8)): box(root,"PavilionPost",(x,y,1.25),(.16,.16,2.45),accent)
            gable(root,"PavilionRoof",(0,0,2.45),3.35,2.55,.14,1.05,roof); cylinder(root,"Fountain",(0,0,.42),.58,.5,stone)
        else:
            box(root,"TowerBase",(0,0,.25),(2.05,2.05,.5),stone); box(root,"ClockTower",(0,0,3.0),(1.35,1.35,5.0),wall); cylinder(root,"ClockCrown",(0,0,6.15),.92,1.1,roof,4); box(root,"ClockFace",(0,-.69,4.05),(.66,.05,.66),accent)
        for x,y in ((-1.65,-1.3),(1.65,-1.3),(1.65,1.3),(-1.65,1.3)):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=.42,location=(x,y,.58)); shrub=bpy.context.object; shrub.name="ParkShrub"; shrub.scale=(1,1,.95); apply(shrub); shrub.data.materials.append(green); shrub.parent=root


def contact(paths, output):
    w=h=CONFIG["canvas"]["width"]; gutter=16; sw=2*w+gutter; sh=2*h+gutter
    pixels=array("f", [0.0])*(sw*sh*4); placements=((0,h+gutter),(w+gutter,h+gutter),(0,0),(w+gutter,0))
    for path,(ox,oy) in zip(paths,placements):
        image=bpy.data.images.load(str(path),check_existing=False); source=array("f",image.pixels[:])
        for row in range(h): pixels[((row+oy)*sw+ox)*4:((row+oy)*sw+ox+w)*4]=source[row*w*4:(row+1)*w*4]
        bpy.data.images.remove(image)
    sheet=bpy.data.images.new("ContactSheet",width=sw,height=sh,alpha=True); sheet.pixels[:]=pixels; sheet.file_format="PNG"; sheet.filepath_raw=str(output); sheet.save(); bpy.data.images.remove(sheet); canonicalize_png(output)


def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def render_asset(asset_id, family, typology):
    scene=reset_scene(); configure(scene); root,cameras=rig(scene); build(root,family,typology)
    root["assetId"],root["assetFamily"],root["typology"],root["sourcePixelsReused"],root["liveAsset"] = asset_id,family,typology,False,False
    directory=ROOT/"assets"/asset_id; renders=directory/"renders"; renders.mkdir(parents=True,exist_ok=True)
    blend=directory/(asset_id+".blend"); bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    paths=[]
    for camera in cameras:
        path=renders/f"{asset_id}_{camera.name}.png"; scene.camera=camera; scene.render.filepath=str(path); bpy.ops.render.render(write_still=True); canonicalize_png(path); paths.append(path)
    sheet=directory/(asset_id+"_contact-sheet.png"); contact(paths,sheet)
    artifacts=[]
    for p in [blend,*paths,sheet]:
        entry={"path":p.relative_to(ROOT).as_posix(),"bytes":p.stat().st_size,"sha256":digest(p)}
        if p.suffix==".png":
            width,height,rgba=decode_rgba_png(p); entry.update({"dimensions":[width,height],"decodedRgbaSha256":hashlib.sha256(rgba).hexdigest()})
        artifacts.append(entry)
    manifest={"schema":"citysim.world-art.expansion-v1.asset.v1","pipelineSchema":CONFIG["schema"],"assetId":asset_id,"family":family,"typology":typology,"originalGeometry":True,"sourcePixelsReused":False,"liveAsset":False,"status":"generation-candidate-not-admitted","toolchain":{"blenderVersion":".".join(map(str,bpy.app.version)),"renderEngine":CONFIG["toolchain"]["renderEngine"]},"cameraOrder":[v["name"] for v in CONFIG["cameraRig"]["views"]],"canvas":CONFIG["canvas"],"rootPivotWorld":[0,0,0],"lightingConvention":CONFIG["lighting"],"postRenderCompensation":"none","artifacts":artifacts}
    (directory/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")


def aggregate():
    # 40 panels, each containing all four 96px views in camera order.
    cell=192; thumb=96; cols=8; rows=5; width,height=cols*cell,rows*cell; rgba=bytearray(width*height*4)
    for index,(asset_id,family,typology) in enumerate(ASSETS):
        cx,cy=(index%cols)*cell,(rows-1-index//cols)*cell
        for view_index,view in enumerate(CONFIG["cameraRig"]["views"]):
            iw,ih,data=decode_rgba_png(ROOT/"assets"/asset_id/"renders"/f"{asset_id}_{view['name']}.png")
            ox,oy=cx+(view_index%2)*thumb,cy+(1-view_index//2)*thumb
            for y in range(thumb):
                for x in range(thumb):
                    si=((y*4)*iw+(x*4))*4; di=((oy+y)*width+ox+x)*4; rgba[di:di+4]=data[si:si+4]
    from png_canonical import encode_rgba_png
    output=ROOT/"expansion-v1-aggregate-contact-sheet.png"; encode_rgba_png(output,width,height,bytes(rgba))
    candidates=[]
    for asset_id,family,typology in ASSETS:
        candidates.append({"assetId":asset_id,"family":family,"typology":typology,"manifest":f"assets/{asset_id}/manifest.json"})
    manifest={"schema":"citysim.world-art.expansion-v1.candidate-manifest.v1","status":"generation-candidate-not-admitted","baselineDistinctBuildingVariants":20,"newDistinctBuildingVariants":len(ASSETS),"candidateDistinctBuildingVariants":20+len(ASSETS),"fourViewFrameCount":len(ASSETS)*4,"contract":{"pipelineSchema":CONFIG["schema"],"canvas":CONFIG["canvas"],"cameraOrder":[v["name"] for v in CONFIG["cameraRig"]["views"]],"postRenderCompensation":"none"},"aggregateContactSheet":{"path":output.name,"sha256":digest(output)},"assets":candidates}
    (ROOT/"candidate-manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True)+"\n",encoding="utf-8")


def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--asset",action="append"); parser.add_argument("--aggregate",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    actual=".".join(map(str,bpy.app.version))
    if actual!=CONFIG["toolchain"]["blenderVersion"]: raise RuntimeError(f"BLENDER_VERSION_MISMATCH: {actual}")
    selected=[a for a in ASSETS if not args.asset or a[0] in set(args.asset)]
    if args.asset and len(selected)!=len(set(args.asset)): raise RuntimeError("UNKNOWN_ASSET_ID")
    for item in selected: render_asset(*item); print("EXPANSION_ASSET_RENDERED",item[0])
    if args.aggregate: aggregate(); print("EXPANSION_AGGREGATE_RENDERED",len(ASSETS))

if __name__=="__main__": main()
