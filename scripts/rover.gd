class_name Rover
extends Node3D

## A unit living on the planet surface. Its authoritative position is the
## geographic coordinate; the 3D transform is derived from it every frame.

const ANGULAR_SPEED_DEG: float = 22.0
## Crawl speed used when the battery is empty and the rover limps home.
const RETURN_SPEED_DEG: float = 6.0
const MAX_CHARGE: float = 100.0
## Charge spent per degree of arc travelled, so a full battery covers 100°.
const CHARGE_PER_DEG: float = 1.0
const RECHARGE_PER_SEC: float = 15.0
## How much of the battery must be restored before the player regains control.
const RECOVER_RATIO: float = 0.25

const BODY_SIZE_RATIO: float = 0.07
const HALO_SIZE_RATIO: float = 0.12
const BAR_WIDTH_RATIO: float = 0.11
const BAR_HEIGHT_RATIO: float = 0.016
const BAR_HEIGHT_OFFSET_RATIO: float = 0.062
## Lifts the flat quads off the surface so they never z-fight with the sphere.
const SURFACE_OFFSET: float = 1.004

var geo: GeoCoord = GeoCoord.new()
var charge: float = MAX_CHARGE
var color: Color = Color.WHITE
var title: String = "Rover"

var _planet_radius: float = 1.0
var _moving: bool = false
var _out_of_charge: bool = false
var _start_unit: Vector3 = Vector3.RIGHT
var _axis: Vector3 = Vector3.UP
var _total_rad: float = 0.0
var _travelled_rad: float = 0.0
var _target: GeoCoord = null

var _body: MeshInstance3D = null
var _halo: MeshInstance3D = null
var _bar_back: MeshInstance3D = null
var _bar_fill: MeshInstance3D = null
var _bar_width: float = 0.1


func setup(planet_radius: float, start: GeoCoord, body_color: Color, rover_title: String) -> void:
	_planet_radius = planet_radius
	geo = start.copy()
	color = body_color
	title = rover_title
	_build_meshes()
	_apply_transform()
	_update_charge_bar()


func is_moving() -> bool:
	return _moving


func is_out_of_charge() -> bool:
	return _out_of_charge


func is_controllable() -> bool:
	return not _out_of_charge


func charge_ratio() -> float:
	return clampf(charge / MAX_CHARGE, 0.0, 1.0)


func current_speed_deg() -> float:
	return RETURN_SPEED_DEG if _out_of_charge else ANGULAR_SPEED_DEG


func set_selected(selected: bool) -> void:
	_halo.visible = selected


## Player order. Ignored while the rover is out of charge.
func order_move_to(destination: GeoCoord) -> bool:
	if not is_controllable():
		return false
	_begin_move(destination)
	return true


## Automatic return trip, issued by the world when the battery runs dry.
func send_home(base_geo: GeoCoord) -> void:
	_begin_move(base_geo)


func stop() -> void:
	_moving = false
	_target = null
	_total_rad = 0.0
	_travelled_rad = 0.0


func recharge(delta: float) -> void:
	if charge >= MAX_CHARGE:
		return
	charge = minf(charge + RECHARGE_PER_SEC * delta, MAX_CHARGE)
	if _out_of_charge and charge >= MAX_CHARGE * RECOVER_RATIO:
		_out_of_charge = false


## Points of the arc still ahead of the rover, in planet-local unit vectors.
func remaining_path(samples: int) -> PackedVector3Array:
	if not _moving:
		return PackedVector3Array()
	return Geo.arc_points(_start_unit, _axis, _travelled_rad, _total_rad, samples)


func _process(delta: float) -> void:
	if _moving:
		_advance(delta)
	_update_charge_bar()


func _begin_move(destination: GeoCoord) -> void:
	var from: Vector3 = geo.to_unit()
	var to: Vector3 = destination.to_unit()
	_total_rad = Geo.arc_angle(from, to)
	if _total_rad < Geo.EPS:
		stop()
		return
	_start_unit = from
	_axis = Geo.arc_axis(from, to)
	_travelled_rad = 0.0
	_target = destination.copy()
	_moving = true


func _advance(delta: float) -> void:
	var step_rad: float = deg_to_rad(current_speed_deg()) * delta
	_travelled_rad += step_rad
	if _travelled_rad >= _total_rad:
		geo = _target.copy()
		stop()
	else:
		geo = Geo.geo_from_unit(_start_unit.rotated(_axis, _travelled_rad))
	if not _out_of_charge:
		charge = maxf(charge - CHARGE_PER_DEG * rad_to_deg(step_rad), 0.0)
		if charge <= 0.0:
			_out_of_charge = true
			stop()
	_apply_transform()


func _apply_transform() -> void:
	# The node frame stays north-up so the charge bar never tilts; only the body
	# quad turns towards the direction of travel.
	var unit: Vector3 = geo.to_unit()
	var frame: Basis = Geo.surface_basis(unit, Geo.north_tangent(unit))
	transform = Transform3D(frame, unit * _planet_radius * SURFACE_OFFSET)
	_body.rotation = Vector3(0.0, 0.0, _heading_angle(frame, unit))


func _heading_angle(frame: Basis, unit: Vector3) -> float:
	if not _moving:
		return 0.0
	var local_dir: Vector3 = frame.inverse() * _axis.cross(unit)
	return atan2(-local_dir.x, local_dir.y)


func _update_charge_bar() -> void:
	var ratio: float = charge_ratio()
	_bar_fill.visible = ratio > 0.0
	_bar_fill.scale = Vector3(maxf(ratio, 0.0001), 1.0, 1.0)
	_bar_fill.position = Vector3(
		-_bar_width * 0.5 * (1.0 - ratio), _planet_radius * BAR_HEIGHT_OFFSET_RATIO, 0.0008
	)


func _build_meshes() -> void:
	_halo = MeshInstance3D.new()
	_halo.mesh = _make_quad(_planet_radius * HALO_SIZE_RATIO, _planet_radius * HALO_SIZE_RATIO)
	_halo.material_override = _make_material(Color(1.0, 1.0, 1.0, 0.45))
	_halo.position = Vector3(0.0, 0.0, -0.0005)
	_halo.visible = false
	add_child(_halo)

	_body = MeshInstance3D.new()
	_body.mesh = _make_quad(_planet_radius * BODY_SIZE_RATIO, _planet_radius * BODY_SIZE_RATIO)
	_body.material_override = _make_material(color)
	add_child(_body)

	_bar_width = _planet_radius * BAR_WIDTH_RATIO
	var bar_height: float = _planet_radius * BAR_HEIGHT_RATIO

	_bar_back = MeshInstance3D.new()
	_bar_back.mesh = _make_quad(_bar_width, bar_height)
	_bar_back.material_override = _make_material(Color(0.02, 0.04, 0.08, 0.75))
	_bar_back.position = Vector3(0.0, _planet_radius * BAR_HEIGHT_OFFSET_RATIO, 0.0004)
	add_child(_bar_back)

	_bar_fill = MeshInstance3D.new()
	_bar_fill.mesh = _make_quad(_bar_width, bar_height)
	_bar_fill.material_override = _make_material(Color(0.25, 0.65, 1.0, 0.95))
	add_child(_bar_fill)


func _make_quad(width: float, height: float) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(width, height)
	return quad


func _make_material(albedo: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = albedo
	if albedo.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
