#!/usr/bin/env python3
"""Run in Blender after opening a produced source file."""
import bpy, math, sys
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
def close(a,b,t=.001): return abs(a-b)<=t
root=bpy.data.objects.get("AssetRoot"); pivot=bpy.data.objects.get("FootprintPivot")
assert root and pivot and tuple(root.location)==(0,0,0) and tuple(root.scale)==(1,1,1)
assert bpy.context.scene.get("postRenderCompensation")=="none"
assert [o.name for o in bpy.data.objects if o.type=="LIGHT"]==["CitySimKey"]
for name,az in (("camNE",45),("camSE",135),("camSW",225),("camNW",315)):
    c=bpy.data.objects[name]; assert c.data.type=="ORTHO" and close(c.data.ortho_scale,12.341995,.00001) and close(c.data.shift_y,.28125,.00001)
    got=math.degrees(math.atan2(c.location.x,c.location.y))%360; assert close(got,az)
    ndc=world_to_camera_view(bpy.context.scene,c,Vector((0,0,0))); px=(ndc.x*384,(1-ndc.y)*384); assert close(px[0],192,.01) and close(px[1],300,.01)
for o in [o for o in bpy.data.objects if o.type=="MESH"]:
    assert o.parent==root and all(close(x,1,.0001) for x in o.scale) and all(close(x,0,.0001) for x in o.rotation_euler)
print("ENVIRONMENT_BLEND_VALIDATION_PASS",bpy.data.filepath)
