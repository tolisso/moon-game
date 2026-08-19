class_name Rover
extends Node3D

## A delivery unit. Parked and invisible at the base until dispatched, then it
## drives to the drop point along the shortest great-circle arc and comes back.
## Energy is the one-way cost of that arc, sampled through craters. Weight
## (1..6) is the heaviest order it can carry. Craters halve speed.

signal delivered(order: DeliveryOrder)

enum State { DOCKED, OUTBOUND, RETURNING }
enum Stat { ENERGY, WEIGHT }

const BODY_SIZE_RATIO: float = 0.07
const BAR_WIDTH_RATIO: float = 0.11
const BAR_HEIGHT_RATIO: float = 0.014
const ENERGY_BAR_Y_RATIO: float = 0.062
const CARGO_BAR_Y_RATIO: float = 0.084
## Lifts the flat quads off the surface so they never z-fight with the sphere.
const SURFACE_OFFSET: float = 1.004


## Left-anchored bar drawn flat on the surface above the rover body.
class Bar:
	extends RefCounted

	var root: Node3D = null
	var fill: MeshInstance3D = null
	var width: float = 0.1
	var hide_when_empty: bool = false

	func set_ratio(ratio: float) -> void:
		var clamped: float = clampf(ratio, 0.0, 1.0)
		root.visible = clamped > 0.0 or not hide_when_empty
		fill.visible = clamped > 0.0
		fill.scale = Vector3(maxf(clamped, 0.0001), 1.0, 1.0)
		fill.position = Vector3(-width * 0.5 * (1.0 - clamped), 0.0, 0.0004)


var title: String = "Rover"
var color: Color = Color.WHITE
var max_energy: int = Balance.START_ENERGY
var max_weight: int = Balance.START_WEIGHT
var energy: float = float(Balance.START_ENERGY)

var geo: GeoCoord = GeoCoord.new()
var home: GeoCoord = GeoCoord.new()
var cargo: float = 0.0

var _planet_radius: float = 1.0
var _craters: Craters = null
var _state: State = State.DOCKED
var _order: DeliveryOrder = null
var _moving: bool = false
var _start_unit: Vector3 = Vector3.RIGHT
var _axis: Vector3 = Vector3.UP
var _total_rad: float = 0.0
var _travelled_rad: float = 0.0
var _destination: GeoCoord = null

var _body: MeshInstance3D = null
var _energy_bar: Bar = null
var _cargo_bar: Bar = null


func initialize(planet_radius: float, home_geo: GeoCoord, craters: Craters) -> void:
	_planet_radius = planet_radius
	_craters = craters
	home = home_geo.copy()
	geo = home.copy()
	energy = float(max_energy)
	_build_meshes()
	_apply_transform()
	_update_bars()
	visible = false


func is_busy() -> bool:
	return _state != State.DOCKED


## True when a full battery can cover the one-way trip to this order.
func can_reach(dest: GeoCoord) -> bool:
	return float(max_energy) + 0.001 >= _craters.energy_needed(home, dest)


func can_carry(weight: float) -> bool:
	return float(max_weight) + 0.001 >= weight


func can_start_now(dest: GeoCoord, weight: float) -> bool:
	if is_busy() or not can_reach(dest) or not can_carry(weight):
		return false
	return energy + 0.001 >= _craters.energy_needed(home, dest)


## Seconds until this rover is docked, charged enough, and free to take a job
## at `dest`. Ignores weight.
func wait_until_start(dest: GeoCoord) -> float:
	var wait: float = remaining_trip_time()
	var needed: float = _craters.energy_needed(home, dest)
	if energy + 0.001 < needed:
		wait += Balance.recharge_time(needed - energy)
	return wait


func remaining_trip_time() -> float:
	if not is_busy() or _destination == null:
		return 0.0
	var remaining_leg: float = _craters.travel_time(geo, _destination)
	if _state == State.OUTBOUND:
		return remaining_leg + _craters.travel_time(_destination, home)
	return remaining_leg


func remaining_arc_deg() -> float:
	if not _moving:
		return 0.0
	return rad_to_deg(_total_rad - _travelled_rad)


func dispatch(order: DeliveryOrder) -> void:
	energy = maxf(energy - _craters.energy_needed(home, order.geo), 0.0)
	_order = order
	cargo = order.cargo
	_state = State.OUTBOUND
	geo = home.copy()
	visible = true
	_begin_move(order.geo)
	_apply_transform()
	_update_bars()


func stat_value(stat: Stat) -> float:
	match stat:
		Stat.ENERGY:
			return float(max_energy)
		Stat.WEIGHT:
			return float(max_weight)
	return 0.0


func is_stat_maxed(stat: Stat) -> bool:
	return int(stat_value(stat)) >= Balance.STAT_MAX


func upgrade_cost(stat: Stat) -> int:
	return Balance.upgrade_cost(int(stat_value(stat)))


func apply_upgrade(stat: Stat) -> void:
	if is_stat_maxed(stat):
		return
	match stat:
		Stat.ENERGY:
			max_energy += 1
		Stat.WEIGHT:
			max_weight += 1


## Points of the current leg still ahead, in planet-local unit vectors.
func remaining_path(samples: int) -> PackedVector3Array:
	if not _moving:
		return PackedVector3Array()
	return Geo.arc_points(_start_unit, _axis, _travelled_rad, _total_rad, samples)


func _process(delta: float) -> void:
	if _state == State.DOCKED:
		energy = minf(energy + Balance.RECHARGE_PER_SEC * delta, float(max_energy))
		_update_bars()
		return
	_advance(delta)


func _begin_move(destination: GeoCoord) -> void:
	var from: Vector3 = geo.to_unit()
	var to: Vector3 = destination.to_unit()
	_total_rad = Geo.arc_angle(from, to)
	if _total_rad < Geo.EPS:
		_moving = false
		return
	_start_unit = from
	_axis = Geo.arc_axis(from, to)
	_travelled_rad = 0.0
	_destination = destination.copy()
	_moving = true


func _advance(delta: float) -> void:
	var arrived: bool = not _moving
	if _moving:
		var speed_deg: float = Balance.ROVER_SPEED_DEG
		if _craters.contains_geo(geo):
			speed_deg *= Balance.CRATER_SPEED_FACTOR
		var step_rad: float = deg_to_rad(speed_deg) * delta
		_travelled_rad += step_rad
		if _travelled_rad >= _total_rad:
			geo = _destination.copy()
			_moving = false
			arrived = true
		else:
			geo = Geo.geo_from_unit(_start_unit.rotated(_axis, _travelled_rad))
	_apply_transform()
	_update_bars()
	if arrived:
		_on_leg_finished()


func _on_leg_finished() -> void:
	if _state == State.OUTBOUND:
		cargo = 0.0
		var completed: DeliveryOrder = _order
		_order = null
		_state = State.RETURNING
		_begin_move(home)
		_update_bars()
		delivered.emit(completed)
	else:
		_state = State.DOCKED
		visible = false


func _apply_transform() -> void:
	# The node frame stays north-up so the bars never tilt; only the body quad
	# turns towards the direction of travel.
	var unit: Vector3 = geo.to_unit()
	var frame: Basis = Geo.surface_basis(unit, Geo.north_tangent(unit))
	transform = Transform3D(frame, unit * _planet_radius * SURFACE_OFFSET)
	_body.rotation = Vector3(0.0, 0.0, _heading_angle(frame, unit))


func _heading_angle(frame: Basis, unit: Vector3) -> float:
	if not _moving:
		return 0.0
	var local_dir: Vector3 = frame.inverse() * _axis.cross(unit)
	return atan2(-local_dir.x, local_dir.y)


func _update_bars() -> void:
	_energy_bar.set_ratio(energy / float(max_energy))
	_cargo_bar.set_ratio(cargo / float(Balance.STAT_MAX))


func _build_meshes() -> void:
	_body = MeshInstance3D.new()
	var body_size: float = _planet_radius * BODY_SIZE_RATIO
	_body.mesh = _make_quad(body_size, body_size)
	_body.material_override = SphereShapes.unshaded_material(color)
	add_child(_body)

	_energy_bar = _add_bar(ENERGY_BAR_Y_RATIO, Color(0.25, 0.65, 1.0, 0.95), false)
	_cargo_bar = _add_bar(CARGO_BAR_Y_RATIO, Color(1.0, 0.72, 0.28, 0.95), true)


func _add_bar(offset_ratio: float, fill_color: Color, hide_when_empty: bool) -> Bar:
	var bar: Bar = Bar.new()
	bar.width = _planet_radius * BAR_WIDTH_RATIO
	bar.hide_when_empty = hide_when_empty

	bar.root = Node3D.new()
	bar.root.position = Vector3(0.0, _planet_radius * offset_ratio, 0.0)
	add_child(bar.root)

	var height: float = _planet_radius * BAR_HEIGHT_RATIO
	var back: MeshInstance3D = MeshInstance3D.new()
	back.mesh = _make_quad(bar.width, height)
	back.material_override = SphereShapes.unshaded_material(Color(0.02, 0.04, 0.08, 0.75))
	back.position = Vector3(0.0, 0.0, 0.0002)
	bar.root.add_child(back)

	bar.fill = MeshInstance3D.new()
	bar.fill.mesh = _make_quad(bar.width, height)
	bar.fill.material_override = SphereShapes.unshaded_material(fill_color)
	bar.root.add_child(bar.fill)
	return bar


func _make_quad(width: float, height: float) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(width, height)
	return quad
