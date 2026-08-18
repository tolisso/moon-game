class_name Craters
extends Node3D

## Ten spherical-cap craters. Paths through them take twice as long and spend
## twice the energy per degree, because speed halves while burn rate does not.

const FILL_OFFSET: float = 1.0012
const RING_OFFSET: float = 1.002
const RING_WIDTH_RATIO: float = 0.008
const FILL_COLOR: Color = Color(0.08, 0.1, 0.12, 0.92)
const RING_COLOR: Color = Color(0.22, 0.2, 0.18, 0.95)
const PLACE_ATTEMPTS: int = 4000


class LegCost:
	extends RefCounted

	var energy: float = 0.0
	var seconds: float = 0.0


var _centres: Array[Vector3] = []
var _cos_radius: float = 1.0
var _planet_radius: float = 1.0


func setup(planet_radius: float, base_geo: GeoCoord) -> void:
	_planet_radius = planet_radius
	_cos_radius = cos(deg_to_rad(Balance.CRATER_RADIUS_DEG))
	_place(base_geo.to_unit())
	_build_meshes()


func contains_geo(geo: GeoCoord) -> bool:
	return contains_unit(geo.to_unit())


func contains_unit(unit: Vector3) -> bool:
	var point: Vector3 = unit.normalized()
	for centre in _centres:
		if point.dot(centre) >= _cos_radius:
			return true
	return false


func energy_needed(from: GeoCoord, to: GeoCoord) -> float:
	return _leg_cost(from, to).energy


func travel_time(from: GeoCoord, to: GeoCoord) -> float:
	return _leg_cost(from, to).seconds


func _leg_cost(from: GeoCoord, to: GeoCoord) -> LegCost:
	var cost: LegCost = LegCost.new()
	var start: Vector3 = from.to_unit()
	var end: Vector3 = to.to_unit()
	var total_rad: float = Geo.arc_angle(start, end)
	if total_rad < Geo.EPS:
		return cost
	var axis: Vector3 = Geo.arc_axis(start, end)
	var segment_deg: float = rad_to_deg(total_rad) / float(Balance.PATH_SEGMENTS)
	var clear_energy: float = Balance.energy_needed(segment_deg)
	var clear_time: float = segment_deg / Balance.ROVER_SPEED_DEG
	var crater_mult: float = 1.0 / Balance.CRATER_SPEED_FACTOR
	for i in Balance.PATH_SEGMENTS:
		var mid_t: float = (float(i) + 0.5) / float(Balance.PATH_SEGMENTS)
		var sample: Vector3 = start.rotated(axis, total_rad * mid_t)
		var mult: float = crater_mult if contains_unit(sample) else 1.0
		cost.energy += clear_energy * mult
		cost.seconds += clear_time * mult
	return cost


func _place(base: Vector3) -> void:
	var min_base_deg: float = Balance.CRATER_RADIUS_DEG + BaseStation.YARD_RADIUS_DEG
	var min_peer_deg: float = Balance.CRATER_RADIUS_DEG * 2.0
	var attempts: int = 0
	while _centres.size() < Balance.CRATER_COUNT and attempts < PLACE_ATTEMPTS:
		attempts += 1
		var candidate: Vector3 = _random_unit()
		if rad_to_deg(Geo.arc_angle(candidate, base)) < min_base_deg:
			continue
		var overlaps: bool = false
		for centre in _centres:
			if rad_to_deg(Geo.arc_angle(candidate, centre)) < min_peer_deg:
				overlaps = true
				break
		if overlaps:
			continue
		_centres.append(candidate)


func _random_unit() -> Vector3:
	var y: float = randf() * 2.0 - 1.0
	var lon: float = randf() * TAU
	var ring: float = sqrt(maxf(1.0 - y * y, 0.0))
	return Vector3(ring * cos(lon), y, ring * sin(lon))


func _build_meshes() -> void:
	var ring_width: float = _planet_radius * RING_WIDTH_RATIO
	for centre in _centres:
		add_child(
			SphereShapes.cap(
				centre, Balance.CRATER_RADIUS_DEG, _planet_radius, FILL_OFFSET, FILL_COLOR
			)
		)
		add_child(
			SphereShapes.ring(
				centre,
				Balance.CRATER_RADIUS_DEG,
				_planet_radius,
				RING_OFFSET,
				ring_width,
				RING_COLOR
			)
		)
