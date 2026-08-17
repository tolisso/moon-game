class_name BaseStation
extends Node3D

## Home base drawn as a filled disc plus the circular area where rovers
## recharge. Everything is built from spherical caps, so the shapes hug the
## planet instead of cutting through it.

const CORE_RADIUS_DEG: float = 4.0
const CIRCLE_SEGMENTS: int = 96
## Caps are split into radial bands this wide, keeping every triangle close
## enough to the sphere to stay above the surface.
const BAND_DEG: float = 2.0
const RING_WIDTH_RATIO: float = 0.012
const AREA_OFFSET: float = 1.0015
const RING_OFFSET: float = 1.0025
const CORE_OFFSET: float = 1.004

var geo: GeoCoord = GeoCoord.new()
var charge_radius_deg: float = 18.0

var _planet_radius: float = 1.0


func setup(planet_radius: float, place: GeoCoord, radius_deg: float) -> void:
	_planet_radius = planet_radius
	geo = place.copy()
	charge_radius_deg = radius_deg
	_add_cap(charge_radius_deg, Color(0.35, 0.85, 1.0, 0.1), AREA_OFFSET)
	_add_ring(charge_radius_deg, Color(0.45, 0.9, 1.0, 0.65))
	_add_cap(CORE_RADIUS_DEG, Color(1.0, 0.82, 0.35, 1.0), CORE_OFFSET)


## True when a rover standing at `point` is inside the recharge area.
func covers(point: GeoCoord) -> bool:
	return geo.arc_to_deg(point) <= charge_radius_deg


func _circle_points(radius_deg: float) -> PackedVector3Array:
	var centre: Vector3 = geo.to_unit()
	var u: Vector3 = Geo.any_tangent(centre)
	var v: Vector3 = centre.cross(u)
	var radius: float = deg_to_rad(radius_deg)
	var along_axis: float = cos(radius)
	var along_plane: float = sin(radius)
	var points: PackedVector3Array = PackedVector3Array()
	points.resize(CIRCLE_SEGMENTS)
	for i in CIRCLE_SEGMENTS:
		var angle: float = TAU * float(i) / float(CIRCLE_SEGMENTS)
		points[i] = centre * along_axis + (u * cos(angle) + v * sin(angle)) * along_plane
	return points


func _add_cap(radius_deg: float, color: Color, offset: float) -> void:
	var bands: int = maxi(int(ceil(radius_deg / BAND_DEG)), 1)
	var material: StandardMaterial3D = _make_material(color)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	for band in bands:
		var inner: PackedVector3Array = _circle_points(
			radius_deg * float(band) / float(bands)
		)
		var outer: PackedVector3Array = _circle_points(
			radius_deg * float(band + 1) / float(bands)
		)
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
		for i in CIRCLE_SEGMENTS + 1:
			var index: int = i % CIRCLE_SEGMENTS
			mesh.surface_add_vertex(inner[index] * _planet_radius * offset)
			mesh.surface_add_vertex(outer[index] * _planet_radius * offset)
		mesh.surface_end()
	_attach(mesh)


func _add_ring(radius_deg: float, color: Color) -> void:
	var centre: Vector3 = geo.to_unit()
	var u: Vector3 = Geo.any_tangent(centre)
	var v: Vector3 = centre.cross(u)
	var radius: float = deg_to_rad(radius_deg)
	var half_width: float = _planet_radius * RING_WIDTH_RATIO * 0.5
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _make_material(color))
	for i in CIRCLE_SEGMENTS + 1:
		var angle: float = TAU * float(i % CIRCLE_SEGMENTS) / float(CIRCLE_SEGMENTS)
		var radial: Vector3 = u * cos(angle) + v * sin(angle)
		var point: Vector3 = centre * cos(radius) + radial * sin(radius)
		var outward: Vector3 = radial * cos(radius) - centre * sin(radius)
		var centre_pos: Vector3 = point * _planet_radius * RING_OFFSET
		mesh.surface_add_vertex(centre_pos + outward * half_width)
		mesh.surface_add_vertex(centre_pos - outward * half_width)
	mesh.surface_end()
	_attach(mesh)


func _attach(mesh: ImmediateMesh) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
