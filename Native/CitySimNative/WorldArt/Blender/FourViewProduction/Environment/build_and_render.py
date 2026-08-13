#!/usr/bin/env python3
"""Build original CitySim road and park source assets with the locked four-view rig."""
from __future__ import annotations
import hashlib, json, math, sys
from array import array
from pathlib import Path
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
CFG = json.loads((HERE / "pipeline.json").read_text())
CANON = HERE.parents[1] / "FourViewPipeline"
sys.path.insert(0, str(CANON))
from png_canonical import canonicalize_png, decode_rgba_png

def mat(name, color, rough=.74):
    m=bpy.data.materials.new(name); m.diffuse_color=color; m.use_nodes=True
    p=m.node_tree.nodes["Principled BSDF"]; p.inputs["Base Color"].default_value=color; p.inputs["Roughness"].default_value=rough
    lowered=name.lower()
    nodes,links=m.node_tree.nodes,m.node_tree.links
    coordinates=nodes.new("ShaderNodeTexCoord"); noise=nodes.new("ShaderNodeTexNoise"); ramp=nodes.new("ShaderNodeValToRGB"); bump_node=nodes.new("ShaderNodeBump")
    noise.inputs["Scale"].default_value=9.0 if any(token in lowered for token in ("road","walk","curb","stone")) else 5.0
    noise.inputs["Detail"].default_value=3.0; noise.inputs["Roughness"].default_value=.62
    ramp.color_ramp.elements[0].position=.28; ramp.color_ramp.elements[0].color=tuple(max(0.0,channel*.76) for channel in color[:3])+(color[3],)
    ramp.color_ramp.elements[1].position=.74; ramp.color_ramp.elements[1].color=tuple(min(1.0,channel*1.12+.018) for channel in color[:3])+(color[3],)
    bump_node.inputs["Strength"].default_value=.14; bump_node.inputs["Distance"].default_value=.04
    links.new(coordinates.outputs["Generated"],noise.inputs["Vector"]); links.new(noise.outputs["Fac"],ramp.inputs["Fac"]); links.new(ramp.outputs["Color"],p.inputs["Base Color"]); links.new(noise.outputs["Fac"],bump_node.inputs["Height"]); links.new(bump_node.outputs["Normal"],p.inputs["Normal"])
    return m

def apply(o):
    bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.transform_apply(location=False,rotation=True,scale=True); o.select_set(False)

def parent(o, root): o.parent=root; return o

def box(root,name,loc,dims,material,edge=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=dims; apply(o)
    if edge:
        mod=o.modifiers.new("EdgeSoftening","BEVEL"); mod.width=edge; mod.segments=2; mod.limit_method="ANGLE"
        bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.modifier_apply(modifier=mod.name); o.select_set(False)
    o.data.materials.append(material); return parent(o,root)

def cyl(root,name,loc,radius,depth,material,vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc); o=bpy.context.object; o.name=name; apply(o); o.data.materials.append(material); return parent(o,root)

def sphere(root,name,loc,scale,material,sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=bpy.context.object; o.name=name; o.scale=scale; apply(o); o.data.materials.append(material); return parent(o,root)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True); s=bpy.context.scene; s.name="CitySimEnvironmentFourView"; return s

def configure(s):
    s.render.engine=CFG["toolchain"]["renderEngine"]; s.render.resolution_x=384; s.render.resolution_y=384; s.render.resolution_percentage=100
    s.render.film_transparent=True; s.render.image_settings.file_format="PNG"; s.render.image_settings.color_mode="RGBA"; s.render.image_settings.color_depth="8"; s.render.image_settings.compression=15
    s.view_settings.view_transform="Standard"; s.view_settings.look="Medium High Contrast"
    if s.world is None: s.world=bpy.data.worlds.new("CitySimWorld")
    s.world.use_nodes=True; s.world.node_tree.nodes["Background"].inputs["Color"].default_value=CFG["lighting"]["worldColor"]; s.world.node_tree.nodes["Background"].inputs["Strength"].default_value=CFG["lighting"]["worldStrength"]
    s["pipelineSchema"]=CFG["schema"]; s["postRenderCompensation"]="none"; s["projectedTilePixels"]=[88,44]

def root():
    r=bpy.data.objects.new("AssetRoot",None); bpy.context.collection.objects.link(r)
    p=bpy.data.objects.new("FootprintPivot",None); p.empty_display_type="CIRCLE"; p.empty_display_size=.2; p.parent=r; bpy.context.collection.objects.link(p)
    return r

def point(o,target=Vector((0,0,0))): o.rotation_euler=(target-o.location).to_track_quat("-Z","Y").to_euler()

def rig(s):
    cams=[]; elev=math.radians(30); dist=32; horizontal=dist*math.cos(elev)
    for v in CFG["cameraRig"]["views"]:
        az=math.radians(v["azimuthDegrees"]); d=bpy.data.cameras.new(v["name"]); d.type="ORTHO"; d.ortho_scale=12.341995; d.shift_y=.28125
        o=bpy.data.objects.new(v["name"],d); bpy.context.collection.objects.link(o); o.location=(horizontal*math.sin(az),horizontal*math.cos(az),dist*math.sin(elev)); point(o); cams.append(o)
    lighting=CFG["lighting"]; d=bpy.data.lights.new(lighting["name"],lighting["type"]); d.energy=lighting["energy"]; d.shape="DISK"; d.size=lighting["size"]; d.color=lighting["color"]
    l=bpy.data.objects.new(lighting["name"],d); bpy.context.collection.objects.link(l); l.location=lighting["location"]; point(l)
    s.camera=cams[0]; return cams

def road_geometry(r,dressed=False):
    m={"road":mat("RoadCharcoal",(.18,.19,.18,1)),"walk":mat("WalkWarmConcrete",(.58,.52,.43,1)),"curb":mat("CurbLimestone",(.74,.68,.56,1)),"line":mat("CenterOchre",(.88,.62,.19,1)),"drain":mat("DrainIron",(.12,.13,.13,1)),"soil":mat("StreetTreeSoil",(.31,.21,.13,1)),"trunk":mat("StreetTreeBark",(.31,.19,.11,1)),"leaf":mat("StreetTreeOlive",(.23,.40,.17,1)),"light":mat("StreetTreeSunlit",(.39,.53,.22,1)),"flower":mat("StreetPlanterFlower",(.69,.27,.18,1))}
    base=box(r,"RoadSurface",(0,0,-.045),(2,2,.09),m["road"],.015); base["exactTileFootprint"]=[2.0,2.0]; base["roadAxis"]="world-X"
    for y in (-.78,.78):
        box(r,f"Sidewalk_{y:+.2f}",(0,y,.035),(2,.44,.12),m["walk"],.018)
        box(r,f"Curb_{y:+.2f}",(0,y-math.copysign(.25,y),.07),(2,.08,.18),m["curb"],.015)
    for x in (-.72,-.24,.24,.72): box(r,f"CenterDash_{x:+.2f}",(x,0,.012),(.28,.055,.025),m["line"],.006)
    for x in (-.72,.72):
        for y in (-.49,.49): box(r,f"Drain_{x:+.2f}_{y:+.2f}",(x,y,.058),(.22,.08,.025),m["drain"],.004)
    if dressed:
        # Dressed tiles are authored variants on the same exact road footprint.
        # Sparse cadence is decided by world placement, never per-view transforms.
        cyl(r,"StreetlampPole",(.72,.76,.66),.035,1.28,m["drain"],12)
        box(r,"StreetlampArm",(.60,.76,1.28),(.28,.045,.045),m["drain"],.008)
        box(r,"StreetlampLantern",(.45,.76,1.23),(.16,.13,.18),m["line"],.025)
        cyl(r,"Hydrant",(-.70,-.76,.26),.08,.42,m["line"],12)
        cyl(r,"HydrantCap",(-.70,-.76,.49),.11,.08,m["drain"],12)
        box(r,"TreeGrate",(-.56,.78,.125),(.46,.40,.05),m["drain"],.012)
        cyl(r,"StreetTreeTrunk",(-.56,.78,.68),.085,1.12,m["trunk"],12)
        sphere(r,"StreetTreeCrown",(-.56,.78,1.48),(.43,.39,.52),m["leaf"])
        sphere(r,"StreetTreeHighlight",(-.68,.70,1.65),(.23,.21,.27),m["light"])
        box(r,"SouthPlanter",(.48,-.78,.28),(.52,.38,.32),m["curb"],.035)
        for index,x in enumerate((.31,.48,.65)):
            sphere(r,f"SouthPlanterFlower{index}",(x,-.78,.53),(.10,.10,.13),m["flower"],1)
    r["assetId"]="axis_civic_road_dressed" if dressed else "axis_civic_road"; r["assetKind"]="dressed-road-sidewalk-treatment" if dressed else "road-sidewalk-treatment"; r["sourcePixelsReused"]=False; r["liveAsset"]=False

def road(r): road_geometry(r,False)
def dressed_road(r): road_geometry(r,True)

def tree(r,stem,loc,trunk,leaf1,leaf2):
    x,y=loc; cyl(r,f"{stem}_Trunk",(x,y,.48),.10,.96,trunk,10)
    sphere(r,f"{stem}_CrownA",(x,y,1.18),(.48,.44,.55),leaf1)
    sphere(r,f"{stem}_CrownB",(x-.18,y+.08,1.31),(.31,.29,.35),leaf2)

def park(r):
    m={"grass":mat("GrassSage",(.27,.40,.23,1)),"soil":mat("PlantingSoil",(.32,.22,.14,1)),"path":mat("PathSand",(.70,.58,.40,1)),"stone":mat("SeatStone",(.55,.48,.38,1)),"stone_light":mat("FountainLimestone",(.76,.68,.54,1)),"water":mat("FountainWater",(.20,.49,.55,1),.26),"trunk":mat("BarkWalnut",(.30,.18,.10,1)),"leaf":mat("LeafOlive",(.22,.39,.17,1)),"light":mat("LeafSunlit",(.38,.52,.22,1)),"flower":mat("FlowerTerracotta",(.68,.25,.18,1)),"iron":mat("ParkIron",(.13,.13,.12,1))}
    base=box(r,"ParkGround",(0,0,-.05),(4,4,.10),m["grass"],.04); base["exactTileFootprint"]=[4.0,4.0]; base["worldFootprintTiles"]=[2,2]
    box(r,"EastWestPath",(0,0,.025),(4,.42,.055),m["path"],.018)
    box(r,"NorthSouthPath",(0,0,.028),(.42,4,.06),m["path"],.018)
    # Central two-tier fountain creates a readable park landmark from every view.
    cyl(r,"FountainPlaza",(0,0,.045),.74,.09,m["path"],32)
    cyl(r,"FountainBasin",(0,0,.19),.57,.28,m["stone_light"],32)
    cyl(r,"FountainWater",(0,0,.35),.47,.05,m["water"],32)
    cyl(r,"FountainPedestal",(0,0,.63),.18,.56,m["stone"],24)
    cyl(r,"FountainUpperBowl",(0,0,.91),.31,.10,m["stone_light"],28)
    cyl(r,"FountainFinial",(0,0,1.12),.08,.34,m["stone_light"],20)
    for index,(x,y) in enumerate(((-1.25,1.20),(1.25,1.20),(-1.25,-1.20),(1.25,-1.20))):
        cyl(r,f"TreeBed{index}",(x,y,.035),.43,.07,m["soil"],20)
        tree(r,f"ParkTree{index}",(x,y),m["trunk"],m["leaf"],m["light"])
        for flower_index,offset in enumerate((-.25,0,.25)):
            sphere(r,f"TreeBedFlower{index}_{flower_index}",(x+offset,y-.34,.16),(.13,.12,.17),m["flower"],1)
    for index,(x,y,wide) in enumerate(((0,-1.33,True),(0,1.33,True),(-1.33,0,False),(1.33,0,False))):
        dims=(.82,.22,.10) if wide else (.22,.82,.10)
        box(r,f"BenchSeat{index}",(x,y,.31),dims,m["stone"],.02)
        for offset in (-.30,.30):
            leg=(x+offset,y,.16) if wide else (x,y+offset,.16)
            box(r,f"BenchLeg{index}_{offset}",leg,(.10,.14,.28) if wide else (.14,.10,.28),m["stone"],.012)
    for index,(x,y) in enumerate(((-.62,-1.68),(.62,1.68))):
        cyl(r,f"ParkLampPole{index}",(x,y,.67),.032,1.28,m["iron"],12)
        box(r,f"ParkLantern{index}",(x,y,1.34),(.16,.16,.20),m["light"],.025)
    box(r,"LitterBin",(1.68,-.62,.28),(.26,.26,.54),m["iron"],.035)
    r["assetId"]="pocket_grove_park"; r["assetKind"]="park-vegetation-treatment"; r["sourcePixelsReused"]=False; r["liveAsset"]=False

def render_asset(asset,builder):
    s=reset(); configure(s); r=root(); builder(r); cams=rig(s); out=HERE/"assets"/asset; (out/"renders").mkdir(parents=True,exist_ok=True)
    blend=out/f"{asset}.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    for c in cams:
        s.camera=c; p=out/"renders"/f"{asset}_{c.name}.png"; s.render.filepath=str(p); bpy.ops.render.render(write_still=True); canonicalize_png(p)

def preview():
    s=reset(); configure(s); r=root(); dressed_road(r)
    # Rebuild park on the exact adjacent tile center; geometry moves as one source composition, never per-view.
    before=set(bpy.data.objects); park(r)
    park_names=[o for o in bpy.data.objects if o not in before and o.type=="MESH"]
    for o in park_names: o.location.y += 3.0
    r["assetId"]="environment_streetscape_preview"; r["assetKind"]="source-only-composed-grid-preview"
    cams=rig(s); out=HERE/"preview"; out.mkdir(exist_ok=True); blend=out/"environment_streetscape_preview.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    s.camera=bpy.data.objects["camNE"]; p=out/"environment_streetscape_preview_camNE.png"; s.render.filepath=str(p); bpy.ops.render.render(write_still=True); canonicalize_png(p)

def main():
    actual=".".join(map(str,bpy.app.version)); assert actual==CFG["toolchain"]["blenderVersion"],actual
    render_asset("axis_civic_road",road); render_asset("axis_civic_road_dressed",dressed_road); render_asset("pocket_grove_park",park); preview(); print("ENVIRONMENT_ASSETS_RENDERED")
if __name__=="__main__": main()
