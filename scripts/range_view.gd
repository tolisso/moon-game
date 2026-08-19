class_name RangeView
extends Node3D

## One precomputed max-energy contour per battery level. Craters dent the
## old circular range, so the meshes are built once at startup and then only
## toggled visible.

const RING_OFFSET: float = 1.012
const RING_WIDTH_RATIO: float = 0.01
const MAX_VISIBLE_DEG: float = 179.0
const RAYS: int = 96
const SEARCH_STEPS: int = 16
const RING_COLOR: Color = Color(0.35, 0.7, 1.0, 0.55)

var _planet_radius: float = 1.0
var _rings: Array[MeshInstance3D] = []


func setup(planet_radius: float) -> void:
	_planet_radius = planet_radius
	visible = false


func rebuild_contours(centre: GeoCoord, craters: Craters) -> void:
	for ring in _rings:
		remove_child(ring)
		ring.free()
	_rings.clear()
	build_contours(centre, craters)


func build_contours(centre: GeoCoord, craters: Craters) -> void:
	var origin: Vector3 = centre.to_unit()
	var u: Vector3 = Geo.any_tangent(origin)
	var v: Vector3 = origin.cross(u)
	var width: float = _planet_radius * RING_WIDTH_RATIO
	for energy in range(Balance.STAT_MIN, Balance.STAT_MAX + 1):
		var points: PackedVector3Array = PackedVector3Array()
		points.resize(RAYS)
		for ray in RAYS:
			var azimuth: float = TAU * float(ray) / float(RAYS)
			var radial: Vector3 = u * cos(azimuth) + v * sin(azimuth)
			points[ray] = _farthest_on_ray(centre, origin, radial, craters, float(energy))
		var ring: MeshInstance3D = SphereShapes.closed_ribbon(
			points, _planet_radius, RING_OFFSET, width, RING_COLOR
		)
		var material: StandardMaterial3D = ring.material_override as StandardMaterial3D
		if material != null:
			material.render_priority = 1
		ring.visible = false
		add_child(ring)
		_rings.append(ring)


func hide_ranges() -> void:
	visible = false


func show_max_energy(level: int) -> void:
	visible = true
	for i in _rings.size():
		_rings[i].visible = i + Balance.STAT_MIN == level


func _farthest_on_ray(
	centre: GeoCoord, origin: Vector3, radial: Vector3, craters: Craters, energy: float
) -> Vector3:
	var lo: float = 0.0
	var hi: float = MAX_VISIBLE_DEG
	for _step in SEARCH_STEPS:
		var mid: float = (lo + hi) * 0.5
		var dest: GeoCoord = Geo.geo_from_unit(Geo.offset(origin, radial, deg_to_rad(mid)))
		if craters.energy_needed(centre, dest) <= energy + 0.001:
			lo = mid
		else:
			hi = mid
	return Geo.offset(origin, radial, deg_to_rad(lo))
