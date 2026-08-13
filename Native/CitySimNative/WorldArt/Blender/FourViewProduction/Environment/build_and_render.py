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
    s.world.use_nodes=True; s.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.65
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
    d=bpy.data.lights.new("CitySimKey","AREA"); d.energy=1100; d.shape="DISK"; d.size=5
    l=bpy.data.objects.new("CitySimKey",d); bpy.context.collection.objects.link(l); l.location=(-6,-8,12); point(l)
    s.camera=cams[0]; return cams

def road(r):
    m={"road":mat("RoadCharcoal",(.18,.19,.18,1)),"walk":mat("WalkWarmConcrete",(.58,.52,.43,1)),"curb":mat("CurbLimestone",(.74,.68,.56,1)),"line":mat("CenterOchre",(.88,.62,.19,1)),"drain":mat("DrainIron",(.12,.13,.13,1))}
    base=box(r,"RoadSurface",(0,0,-.045),(2,2,.09),m["road"],.015); base["exactTileFootprint"]=[2.0,2.0]; base["roadAxis"]="world-X"
    for y in (-.78,.78):
        box(r,f"Sidewalk_{y:+.2f}",(0,y,.035),(2,.44,.12),m["walk"],.018)
        box(r,f"Curb_{y:+.2f}",(0,y-math.copysign(.25,y),.07),(2,.08,.18),m["curb"],.015)
    for x in (-.72,-.24,.24,.72): box(r,f"CenterDash_{x:+.2f}",(x,0,.012),(.28,.055,.025),m["line"],.006)
    for x in (-.72,.72):
        for y in (-.49,.49): box(r,f"Drain_{x:+.2f}_{y:+.2f}",(x,y,.058),(.22,.08,.025),m["drain"],.004)
    r["assetId"]="axis_civic_road"; r["assetKind"]="road-sidewalk-treatment"; r["sourcePixelsReused"]=False; r["liveAsset"]=False

def tree(r,stem,loc,trunk,leaf1,leaf2):
    x,y=loc; cyl(r,f"{stem}_Trunk",(x,y,.48),.10,.96,trunk,10)
    sphere(r,f"{stem}_CrownA",(x,y,1.18),(.48,.44,.55),leaf1)
    sphere(r,f"{stem}_CrownB",(x-.18,y+.08,1.31),(.31,.29,.35),leaf2)

def park(r):
    m={"grass":mat("GrassSage",(.27,.40,.23,1)),"soil":mat("PlantingSoil",(.32,.22,.14,1)),"path":mat("PathSand",(.70,.58,.40,1)),"stone":mat("SeatStone",(.55,.48,.38,1)),"trunk":mat("BarkWalnut",(.30,.18,.10,1)),"leaf":mat("LeafOlive",(.22,.39,.17,1)),"light":mat("LeafSunlit",(.38,.52,.22,1)),"flower":mat("FlowerTerracotta",(.68,.25,.18,1))}
    base=box(r,"ParkGround",(0,0,-.05),(2,2,.10),m["grass"],.02); base["exactTileFootprint"]=[2.0,2.0]
    box(r,"CrossPath",(0,0,.025),(2,.34,.055),m["path"],.018)
    for x,y in ((-.58,.48),(.58,.50)):
        cyl(r,f"Bed_{x:+.2f}",(x,y,.035),.31,.07,m["soil"],16)
    tree(r,"WestTree",(-.58,.48),m["trunk"],m["leaf"],m["light"]); tree(r,"EastTree",(.58,.50),m["trunk"],m["leaf"],m["light"])
    box(r,"BenchSeat",(0,-.48,.26),(.78,.20,.10),m["stone"],.02)
    for x in (-.31,.31): box(r,f"BenchLeg_{x:+.2f}",(x,-.48,.13),(.10,.14,.25),m["stone"],.012)
    for i,(x,y) in enumerate(((-.80,-.62),(-.60,-.70),(.66,-.66),(.82,-.58))): sphere(r,f"Plant_{i+1}",(x,y,.16),(.14,.14,.18),m["flower"],1)
    r["assetId"]="pocket_grove_park"; r["assetKind"]="park-vegetation-treatment"; r["sourcePixelsReused"]=False; r["liveAsset"]=False

def render_asset(asset,builder):
    s=reset(); configure(s); r=root(); builder(r); cams=rig(s); out=HERE/"assets"/asset; (out/"renders").mkdir(parents=True,exist_ok=True)
    blend=out/f"{asset}.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    for c in cams:
        s.camera=c; p=out/"renders"/f"{asset}_{c.name}.png"; s.render.filepath=str(p); bpy.ops.render.render(write_still=True); canonicalize_png(p)

def preview():
    s=reset(); configure(s); r=root(); road(r)
    # Rebuild park on the exact adjacent tile center; geometry moves as one source composition, never per-view.
    before=set(bpy.data.objects); park(r)
    park_names=[o for o in bpy.data.objects if o not in before and o.type=="MESH"]
    for o in park_names: o.location.y += 2.0
    r["assetId"]="environment_streetscape_preview"; r["assetKind"]="source-only-composed-grid-preview"
    cams=rig(s); out=HERE/"preview"; out.mkdir(exist_ok=True); blend=out/"environment_streetscape_preview.blend"; bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    s.camera=bpy.data.objects["camNE"]; p=out/"environment_streetscape_preview_camNE.png"; s.render.filepath=str(p); bpy.ops.render.render(write_still=True); canonicalize_png(p)

def main():
    actual=".".join(map(str,bpy.app.version)); assert actual==CFG["toolchain"]["blenderVersion"],actual
    render_asset("axis_civic_road",road); render_asset("pocket_grove_park",park); preview(); print("ENVIRONMENT_ASSETS_RENDERED")
if __name__=="__main__": main()
