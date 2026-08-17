class_name Rover
extends Node3D

## A unit living on the planet surface. Its authoritative position is the
## geographic coordinate; the 3D transform is derived from it every frame.

const ANGULAR_SPEED_DEG: float = 22.0
const BODY_SIZE_RATIO: float = 0.07
const HALO_SIZE_RATIO: float = 0.12
## Lifts the flat quads off the surface so they never z-fight with the sphere.
const SURFACE_OFFSET: float = 1.004

var geo: GeoCoord = GeoCoord.new()
var color: Color = Color.WHITE
var title: String = "Rover"

var _planet_radius: float = 1.0
var _moving: bool = false
var _start_unit: Vector3 = Vector3.RIGHT
var _axis: Vector3 = Vector3.UP
var _total_rad: float = 0.0
var _travelled_rad: float = 0.0
var _target: GeoCoord = null
var _body: MeshInstance3D = null
var _halo: MeshInstance3D = null


func setup(planet_radius: float, start: GeoCoord, body_color: Color, rover_title: String) -> void:
	_planet_radius = planet_radius
	geo = start.copy()
	color = body_color
	title = rover_title
	_build_meshes()
	_apply_transform()


func is_moving() -> bool:
	return _moving


func target_geo() -> GeoCoord:
	return _target


func remaining_arc_deg() -> float:
	if not _moving:
		return 0.0
	return rad_to_deg(_total_rad - _travelled_rad)


func set_selected(selected: bool) -> void:
	_halo.visible = selected


## Sends the rover along the shortest great-circle arc towards `destination`.
func order_move_to(destination: GeoCoord) -> void:
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


func stop() -> void:
	_moving = false
	_target = null
	_total_rad = 0.0
	_travelled_rad = 0.0


## Points of the arc still ahead of the rover, in planet-local unit vectors.
func remaining_path(samples: int) -> PackedVector3Array:
	if not _moving:
		return PackedVector3Array()
	return Geo.arc_points(_start_unit, _axis, _travelled_rad, _total_rad, samples)


func _process(delta: float) -> void:
	if not _moving:
		return
	_travelled_rad += deg_to_rad(ANGULAR_SPEED_DEG) * delta
	if _travelled_rad >= _total_rad:
		geo = _target.copy()
		stop()
	else:
		geo = Geo.geo_from_unit(_start_unit.rotated(_axis, _travelled_rad))
	_apply_transform()


func _apply_transform() -> void:
	var unit: Vector3 = geo.to_unit()
	var forward: Vector3 = _axis.cross(unit) if _moving else Geo.north_tangent(unit)
	transform = Transform3D(
		Geo.surface_basis(unit, forward), unit * _planet_radius * SURFACE_OFFSET
	)


func _build_meshes() -> void:
	_halo = MeshInstance3D.new()
	_halo.mesh = _make_quad(_planet_radius * HALO_SIZE_RATIO)
	_halo.material_override = _make_material(Color(1.0, 1.0, 1.0, 0.45))
	_halo.position = Vector3(0.0, 0.0, -0.0005)
	_halo.visible = false
	add_child(_halo)

	_body = MeshInstance3D.new()
	_body.mesh = _make_quad(_planet_radius * BODY_SIZE_RATIO)
	_body.material_override = _make_material(color)
	add_child(_body)


func _make_quad(size: float) -> QuadMesh:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	return quad


func _make_material(albedo: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = albedo
	if albedo.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
