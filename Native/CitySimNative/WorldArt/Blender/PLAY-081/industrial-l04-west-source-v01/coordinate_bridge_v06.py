#!/usr/bin/env python3
"""Accepted PLAY-081 West adapter for the global v06 coordinate basis.

This module applies the single Integration-accepted mapping
``B(CitySim[x,y,z]) = Blender[z,x,y]``. It contains no per-direction
rotation, reflection, footprint reorder, or projection correction.
"""

from __future__ import annotations

from typing import Any, Sequence

import bpy
from mathutils import Vector


BASIS_FORMULA = "B(CitySim[x,y,z])=Blender[z,x,y]"
SOURCE_ORDER = (0, 1, 2, 3)
WEST_SOCKET_CITYSIM = (-28.0, 0.0, 0.0)
WEST_SOCKET_BLENDER = (0.0, -28.0, 0.0)
WEST_SOCKET_SOURCE = (640.0, 704.0)


def _triple(values: Sequence[float]) -> tuple[float, float, float]:
    if len(values) != 3:
        raise ValueError("v06 bridge requires exactly three coordinates")
    return (float(values[0]), float(values[1]), float(values[2]))


def citysim_to_blender(values: Sequence[float]) -> Vector:
    """Map one CitySim position/vector into Blender with the v06 basis."""
    x, y, z = _triple(values)
    return Vector((z, x, y))


def citysim_dimensions_to_blender(values: Sequence[float]) -> Vector:
    """Map axis-aligned CitySim dimensions with the same global basis."""
    x, y, z = _triple(values)
    return Vector((z, x, y))


def create_component(component: dict[str, Any]) -> bpy.types.Object:
    """Create one accepted West descriptor component without directional transforms."""
    shape = component["shape"]
    center = citysim_to_blender(component["centerWorldXYZ"])
    dimensions = citysim_dimensions_to_blender(component["sizeWorldXYZ"])
    name = f"PLAY-081-{component['id']}"

    if shape == "box":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    elif shape == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=32,
            radius=0.5,
            depth=1.0,
            end_fill_type="NGON",
            location=center,
        )
    else:
        raise ValueError(f"unsupported PLAY-081 component shape: {shape}")

    obj = bpy.context.active_object
    if obj is None:
        raise RuntimeError(f"Blender did not create component: {component['id']}")
    obj.name = name
    obj.dimensions = dimensions
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj
