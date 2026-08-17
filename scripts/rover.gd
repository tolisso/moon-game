class_name Rover
extends Node3D

## A delivery unit. Parked and invisible at the base until dispatched, then it
## drives to the drop point along the shortest great-circle arc and comes back.
## Stats (energy, cargo capacity, speed) are rolled once by the world.

signal delivered(order: DeliveryOrder)

enum State { DOCKED, OUTBOUND, RETURNING }


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

## Energy spent per degree of arc, so energy doubles as a range in degrees.
const ENERGY_PER_DEG: float = 1.0
const RECHARGE_PER_SEC: float = 12.0

const BODY_SIZE_RATIO: float = 0.07
const BAR_WIDTH_RATIO: float = 0.11
const BAR_HEIGHT_RATIO: float = 0.014
const ENERGY_BAR_Y_RATIO: float = 0.062
const CARGO_BAR_Y_RATIO: float = 0.084
## Lifts the flat quads off the surface so they never z-fight with the sphere.
const SURFACE_OFFSET: float = 1.004

var title: String = "Rover"
var color: Color = Color.WHITE
var max_energy: float = 120.0
var energy: float = 120.0
var max_cargo: float = 6.0
var speed_deg: float = 20.0

var geo: GeoCoord = GeoCoord.new()
var home: GeoCoord = GeoCoord.new()
var cargo: float = 0.0

var _planet_radius: float = 1.0
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


func initialize(planet_radius: float, home_geo: GeoCoord) -> void:
	_planet_radius = planet_radius
	home = home_geo.copy()
	geo = home.copy()
	energy = max_energy
	_build_meshes()
	_apply_transform()
	_update_bars()
	visible = false


func is_busy() -> bool:
	return _state != State.DOCKED


func energy_needed(arc_deg: float) -> float:
	return arc_deg * ENERGY_PER_DEG


func travel_time(arc_deg: float) -> float:
	return arc_deg / speed_deg


## Empty string means the rover can take the job; otherwise it is the reason.
func rejection_reason(required_cargo: float, round_trip_deg: float) -> String:
	if is_busy():
		return "занят"
	if max_cargo + 0.001 < required_cargo:
		return "мало грузоподъёмности"
	if energy + 0.001 < energy_needed(round_trip_deg):
		return "мало энергии"
	return ""


func dispatch(order: DeliveryOrder) -> void:
	_order = order
	cargo = order.cargo
	_state = State.OUTBOUND
	geo = home.copy()
	visible = true
	_begin_move(order.geo)
	_apply_transform()
	_update_bars()


## Points of the current leg still ahead, in planet-local unit vectors.
func remaining_path(samples: int) -> PackedVector3Array:
	if not _moving:
		return PackedVector3Array()
	return Geo.arc_points(_start_unit, _axis, _travelled_rad, _total_rad, samples)


func _process(delta: float) -> void:
	if _state == State.DOCKED:
		energy = minf(energy + RECHARGE_PER_SEC * delta, max_energy)
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
		var step_rad: float = deg_to_rad(speed_deg) * delta
		_travelled_rad += step_rad
		energy = maxf(energy - energy_needed(rad_to_deg(step_rad)), 0.0)
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
	_energy_bar.set_ratio(energy / max_energy)
	_cargo_bar.set_ratio(cargo / max_cargo)


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
