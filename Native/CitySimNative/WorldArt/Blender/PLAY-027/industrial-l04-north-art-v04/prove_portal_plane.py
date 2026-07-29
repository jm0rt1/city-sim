import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


def fail(message):
    raise RuntimeError(message)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, value):
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def repository_path(root, relative):
    candidate = (root / relative).resolve()
    candidate.relative_to(root)
    return candidate


def blender_point(world):
    return (float(world[0]), float(world[2]), float(world[1]))


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_camera(scene_record):
    camera_record = scene_record["camera"]
    scene = bpy.context.scene
    width, height = camera_record["renderViewportPixels"]
    scene.render.resolution_x = int(width)
    scene.render.resolution_y = int(height)
    scene.render.resolution_percentage = 100
    data = bpy.data.cameras.new("v04-plane-proof-camera")
    data.type = "ORTHO"
    aspect = float(width) / float(height)
    data.ortho_scale = (
        2.0 * float(camera_record["orthographicScale"]) * aspect
    )
    data.shift_x = (
        float(camera_record["postProjectionOffsetPixels"][0]) / float(width)
    )
    data.shift_y = (
        float(camera_record["postProjectionOffsetPixels"][1]) / float(width)
    )
    camera = bpy.data.objects.new("v04-plane-proof-camera", data)
    scene.collection.objects.link(camera)
    camera.location = blender_point(camera_record["positionWorld"])
    look_at(camera, blender_point(camera_record["targetWorld"]))
    scene.camera = camera
    bpy.context.view_layer.update()
    return scene, camera


def source_pixel(scene, camera, citysim_world):
    projected = world_to_camera_view(
        scene,
        camera,
        Vector(blender_point(citysim_world)),
    )
    return [
        projected.x * float(scene.render.resolution_x),
        (1.0 - projected.y) * float(scene.render.resolution_y),
    ]


def compact(source):
    return [float(source[0]) / 8.0, float(source[1]) / 8.0]


def component_bounds(component):
    position = [float(value) for value in component["position"]]
    dimensions = [float(value) for value in component["dimensions"]]
    return [
        [
            position[index] - dimensions[index] / 2.0
            for index in range(3)
        ],
        [
            position[index] + dimensions[index] / 2.0
            for index in range(3)
        ],
    ]


def chebyshev(left, right):
    return max(abs(left[0] - right[0]), abs(left[1] - right[1]))


def clip_polygon(points, a, b, c, limit):
    if not points:
        return []

    def value(point):
        return a * point[0] + b * point[1] + c - limit

    output = []
    previous = points[-1]
    previous_value = value(previous)
    for current in points:
        current_value = value(current)
        previous_inside = previous_value <= 0.0
        current_inside = current_value <= 0.0
        if previous_inside != current_inside:
            denominator = previous_value - current_value
            ratio = previous_value / denominator
            output.append(
                (
                    previous[0] + (current[0] - previous[0]) * ratio,
                    previous[1] + (current[1] - previous[1]) * ratio,
                )
            )
        if current_inside:
            output.append(current)
        previous = current
        previous_value = current_value
    return output


def minimum_chebyshev_over_rectangle(
    project,
    socket,
    minimum_x,
    maximum_x,
    minimum_z,
    maximum_z,
):
    origin = project(0.0, 0.0)
    x_basis = project(1.0, 0.0)
    z_basis = project(0.0, 1.0)
    u_x = x_basis[0] - origin[0]
    u_z = z_basis[0] - origin[0]
    v_x = x_basis[1] - origin[1]
    v_z = z_basis[1] - origin[1]
    u_constant = origin[0] - socket[0]
    v_constant = origin[1] - socket[1]
    inequalities = [
        (u_x, u_z, u_constant),
        (-u_x, -u_z, -u_constant),
        (v_x, v_z, v_constant),
        (-v_x, -v_z, -v_constant),
    ]

    def feasible(limit):
        polygon_points = [
            (minimum_x, minimum_z),
            (minimum_x, maximum_z),
            (maximum_x, maximum_z),
            (maximum_x, minimum_z),
        ]
        for a, b, c in inequalities:
            polygon_points = clip_polygon(
                polygon_points,
                a,
                b,
                c,
                limit,
            )
        return polygon_points

    lower = 0.0
    upper = 128.0
    for _ in range(96):
        midpoint = (lower + upper) / 2.0
        if feasible(midpoint):
            upper = midpoint
        else:
            lower = midpoint
    points = feasible(upper + 1.0e-10)
    if not points:
        fail("continuous exterior-court minimization produced no point")
    world_x, world_z = points[0]
    compact_point = project(world_x, world_z)
    return (
        chebyshev(compact_point, socket),
        [world_x, world_z],
        compact_point,
    )


def line(start, end, color, width):
    return (
        f'<line x1="{start[0]:.3f}" y1="{start[1]:.3f}" '
        f'x2="{end[0]:.3f}" y2="{end[1]:.3f}" '
        f'stroke="{color}" stroke-width="{width}" />'
    )


def polygon(points, fill, stroke):
    payload = " ".join(f"{point[0]:.3f},{point[1]:.3f}" for point in points)
    return (
        f'<polygon points="{payload}" fill="{fill}" stroke="{stroke}" '
        'stroke-width="1" />'
    )


def write_svg(path, proof):
    footprint = proof["footprintCompact"]
    exterior = proof["exteriorCourtCompactPolygon"]
    threshold = proof["portalThresholdCompactBounds"]
    socket = proof["socketCompactActual"]
    closest = proof["closestExteriorCourtCompact"]
    items = [
        '<rect width="192" height="128" fill="#303432" />',
        polygon(exterior, "#b47a3566", "#e6a34f"),
        polygon(footprint, "none", "#56e096"),
        (
            f'<rect x="{threshold[0]}" y="{threshold[1]}" '
            f'width="{threshold[2] - threshold[0]}" '
            f'height="{threshold[3] - threshold[1]}" fill="none" '
            'stroke="#f2d070" stroke-width="1" />'
        ),
        line(closest, socket, "#ff6b6b", 1),
        (
            f'<circle cx="{socket[0]:.3f}" cy="{socket[1]:.3f}" r="2.5" '
            'fill="#46dcff" />'
        ),
        (
            f'<circle cx="{closest[0]:.3f}" cy="{closest[1]:.3f}" r="2" '
            'fill="#ff9e55" />'
        ),
        (
            '<text x="4" y="10" fill="#ffffff" font-size="6">'
            "V04 actual-camera portal-plane proof</text>"
        ),
        (
            '<text x="4" y="119" fill="#ffffff" font-size="5">'
            "orange: legal +X exterior court; cyan: governed North socket"
            "</text>"
        ),
    ]
    path.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="192" height="128" viewBox="0 0 192 128">'
        + "".join(items)
        + "</svg>\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", required=True)
    parser.add_argument("--contract", required=True)
    parser.add_argument("--output-root", required=True)
    arguments = sys.argv[sys.argv.index("--") + 1 :]
    options = parser.parse_args(arguments)

    root = Path(options.repository_root).resolve()
    contract_path = repository_path(root, options.contract)
    output = Path(options.output_root).resolve()
    evidence_root = (
        root
        / "docs/production/evidence/PLAY-027/industrial-l04/l04/"
        / "blender-north-art-v04/prepixel"
    ).resolve()
    output.relative_to(evidence_root)
    if output.exists():
        fail(f"output must be absent: {output}")
    output.mkdir(parents=True)

    contract = load_json(contract_path)
    authority = repository_path(root, contract["baseAuthority"]["file"])
    scene_path = repository_path(root, contract["returnedV03"]["scene"]["file"])
    materials_path = repository_path(
        root,
        contract["returnedV03"]["materials"]["file"],
    )
    visibility_path = repository_path(
        root,
        contract["returnedV03"]["portalVisibility"]["file"],
    )
    bindings = [
        (authority, contract["baseAuthority"]["sha256"]),
        (scene_path, contract["returnedV03"]["scene"]["sha256"]),
        (materials_path, contract["returnedV03"]["materials"]["sha256"]),
        (
            visibility_path,
            contract["returnedV03"]["portalVisibility"]["sha256"],
        ),
    ]
    for path, expected in bindings:
        actual = sha256(path)
        if actual != expected:
            fail(f"hash mismatch {path}: {actual} != {expected}")

    scene_record = load_json(scene_path)
    visibility = load_json(visibility_path)
    if scene_record["registration"]["frontageWorld"]["portalFacing"] != (
        contract["proof"]["requiredPortalFacing"]
    ):
        fail("portal facing drift")
    if scene_record["registration"]["frontageSocketSource"] != (
        contract["proof"]["requiredSocketSource"]
    ):
        fail("socket drift")

    components = {
        component["id"]: component
        for component in scene_record["components"]
    }
    portal_ids = (
        scene_record["portal"]["jambComponentIDs"]
        + [scene_record["portal"]["headerComponentID"]]
    )
    portal_outer_faces = {
        component_id: component_bounds(components[component_id])[1][0]
        for component_id in portal_ids
    }
    minimum_exterior_x = min(portal_outer_faces.values())
    footprint = scene_record["registration"]["contactPolygonWorld"]
    minimum_x = min(float(point[0]) for point in footprint)
    maximum_x = max(float(point[0]) for point in footprint)
    minimum_z = min(float(point[1]) for point in footprint)
    maximum_z = max(float(point[1]) for point in footprint)
    if minimum_exterior_x >= maximum_x:
        fail("portal exterior plane leaves no legal court")

    scene, camera = configure_camera(scene_record)
    socket_source = source_pixel(scene, camera, [-28.0, 0.0, 0.0])
    socket_compact = compact(socket_source)
    top_y = float(contract["proof"]["exteriorCourtTopCitySimY"])
    exterior_corners_world = [
        [minimum_exterior_x, top_y, minimum_z],
        [minimum_exterior_x, top_y, maximum_z],
        [maximum_x, top_y, maximum_z],
        [maximum_x, top_y, minimum_z],
    ]
    exterior_compact = [
        compact(source_pixel(scene, camera, point))
        for point in exterior_corners_world
    ]

    def project_ground(world_x, world_z):
        return compact(
            source_pixel(scene, camera, [world_x, top_y, world_z])
        )

    (
        closest_distance,
        closest_world_xz,
        closest_point,
    ) = minimum_chebyshev_over_rectangle(
        project_ground,
        socket_compact,
        minimum_exterior_x,
        maximum_x,
        minimum_z,
        maximum_z,
    )
    closest_world = [
        closest_world_xz[0],
        top_y,
        closest_world_xz[1],
    ]

    threshold = visibility["portalInset"]["largestContiguousBounds"]
    footprint_compact = [
        compact(point)
        for point in scene_record["registration"]["footprintPolygonSource"]
    ]
    maximum_allowed = float(
        contract["proof"]["maximumSocketDistancePixels"]
    )
    socket_opposes_plane = -28.0 < minimum_exterior_x
    portal_plane_contradicts_socket = (
        socket_opposes_plane and closest_distance > maximum_allowed
    )
    proof = {
        "schema": 1,
        "task": "PLAY-027",
        "contract": "CONTRACT-020",
        "sourceRevision": contract["sourceRevision"],
        "actualConfiguredCamera": {
            "positionWorld": scene_record["camera"]["positionWorld"],
            "targetWorld": scene_record["camera"]["targetWorld"],
            "orthographicScale": scene_record["camera"]["orthographicScale"],
            "blenderOrthoScale": float(camera.data.ortho_scale),
            "shiftX": float(camera.data.shift_x),
            "shiftY": float(camera.data.shift_y),
            "viewportPixels": scene_record["camera"]["renderViewportPixels"],
        },
        "portalFacing": "positive-x",
        "portalOuterFaceXByComponent": portal_outer_faces,
        "mostPermissiveExteriorCourtMinimumX": minimum_exterior_x,
        "exteriorCourtWorldBounds": [
            [minimum_exterior_x, top_y, minimum_z],
            [maximum_x, top_y, maximum_z],
        ],
        "exteriorCourtCompactPolygon": exterior_compact,
        "portalThresholdCompactBounds": threshold,
        "socketWorld": [-28.0, 0.0, 0.0],
        "socketSourceActual": socket_source,
        "socketCompactActual": socket_compact,
        "closestExteriorCourtWorld": closest_world,
        "closestExteriorCourtCompact": closest_point,
        "minimumExteriorCourtToSocketChebyshevPixels": closest_distance,
        "minimumMethod": "continuous-convex-half-plane-clipping-v1",
        "maximumAllowedSocketDistancePixels": maximum_allowed,
        "socketOpposesPortalExteriorHalfPlane": socket_opposes_plane,
        "portalPlaneContradictsSocket": portal_plane_contradicts_socket,
        "invalidCureAnalysis": {
            "hiddenConnector": {
                "valid": False,
                "reason": (
                    "A hidden connector is not final rendered apron material "
                    "and cannot establish the required player-visible "
                    "threshold-to-socket path."
                ),
            },
            "underBuildingConnector": {
                "valid": False,
                "reason": (
                    "Any connector carried behind the +X portal plane or under "
                    "the building is outside the legal visible exterior-court "
                    "support X>=16 used by the exact camera proof."
                ),
            },
            "portalPlaneRelocationRequired": portal_plane_contradicts_socket,
        },
        "footprintCompact": footprint_compact,
        "v03VisibleApronBounds": visibility["frontageConnectivity"][
            "largestContiguousVisibleApronBounds"
        ],
        "v03VisibleApronMinimumSocketDistancePixels": 22,
        "rawProcessCount": 0,
        "sourceAuthority": False,
        "productionSelected": False,
        "disposition": (
            "STOP_PORTAL_PLANE_CONTRADICTION"
            if portal_plane_contradicts_socket
            else "PORTAL_PLANE_PERMITS_VISIBLE_COURT"
        ),
    }
    write_json(output / "PORTAL-PLANE-PROOF.json", proof)
    write_svg(output / "PORTAL-PLANE-SOCKET.svg", proof)
    (output / "DISPOSITION.md").write_text(
        "# PLAY-027 North v04 zero-pixel disposition\n\n"
        f"**Disposition:** `{proof['disposition']}`\n\n"
        "The exact configured Blender camera places the governed North socket "
        "on the X = -28 footprint edge. The preserved portal faces +X and its "
        f"most permissive exterior court begins at X = {minimum_exterior_x:g}. "
        "Within the fixed footprint, the closest legal exterior court point "
        f"remains {closest_distance:.6f} compact pixels from the socket, "
        f"exceeding the authorized maximum of {maximum_allowed:g}.\n\n"
        "A hidden connector cannot cure the contradiction because it is not "
        "the final rendered, player-visible apron material. An under-building "
        "connector is likewise outside the legal visible exterior-court "
        "support X >= 16 used by this actual-camera proof. Satisfying the "
        "socket gate therefore requires separate authority to relocate the "
        "portal plane; it cannot be achieved by concealed geometry.\n\n"
        "The v04 authority requires a stop before pixels when the portal plane "
        "contradicts the socket-facing plane. No v04 raw process was run.\n",
        encoding="utf-8",
    )
    if not portal_plane_contradicts_socket:
        fail("expected portal-plane contradiction was not proven")


main()
