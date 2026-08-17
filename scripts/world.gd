extends Node3D

## Game root: owns the planet, camera controls, rover selection and orders.

const PLANET_RADIUS: float = 1.0
const ROTATE_SPEED_DEG: float = 80.0
const MAX_PITCH_DEG: float = 85.0
## A click within this angular distance of a rover selects it instead of
## issuing a move order.
const PICK_ANGLE_DEG: float = 6.0
const PATH_SAMPLES: int = 96
const CAMERA_MIN_DIST: float = 1.6
const CAMERA_MAX_DIST: float = 6.0
const CAMERA_ZOOM_STEP: float = 0.2

@onready var _planet_pivot: Node3D = $PlanetPivot
@onready var _graticule: Graticule = $PlanetPivot/Graticule
@onready var _rovers_root: Node3D = $PlanetPivot/Rovers
@onready var _paths_root: Node3D = $PlanetPivot/Paths
@onready var _camera: Camera3D = $Camera3D
@onready var _info_label: Label = $UI/InfoLabel

var _yaw_deg: float = 0.0
var _pitch_deg: float = 15.0
var _camera_distance: float = 3.0
var _rovers: Array[Rover] = []
var _paths: Array[PathView] = []
var _selected: Rover = null
var _cursor_geo: GeoCoord = null


func _ready() -> void:
	_graticule.build(PLANET_RADIUS)
	_spawn_rovers()
	_apply_planet_rotation()
	_apply_camera_distance()


func _process(delta: float) -> void:
	_handle_rotation(delta)
	_refresh_paths()
	_refresh_info()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed:
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				_handle_click(button.position)
			MOUSE_BUTTON_RIGHT:
				_select(null)
			MOUSE_BUTTON_WHEEL_UP:
				_camera_distance = maxf(_camera_distance - CAMERA_ZOOM_STEP, CAMERA_MIN_DIST)
				_apply_camera_distance()
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera_distance = minf(_camera_distance + CAMERA_ZOOM_STEP, CAMERA_MAX_DIST)
				_apply_camera_distance()
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		_cursor_geo = _geo_under_cursor(motion.position)


func _spawn_rovers() -> void:
	var starts: Array[GeoCoord] = [
		GeoCoord.new(15.0, 20.0),
		GeoCoord.new(-30.0, 60.0),
		GeoCoord.new(45.0, 330.0),
	]
	var colors: Array[Color] = [
		Color(1.0, 0.44, 0.26),
		Color(0.4, 0.85, 0.45),
		Color(0.35, 0.7, 1.0),
	]
	for i in starts.size():
		var rover: Rover = Rover.new()
		_rovers_root.add_child(rover)
		rover.setup(PLANET_RADIUS, starts[i], colors[i], "Ровер %d" % (i + 1))
		_rovers.append(rover)

		var path: PathView = PathView.new()
		_paths_root.add_child(path)
		path.setup(PLANET_RADIUS, colors[i])
		_paths.append(path)


func _handle_rotation(delta: float) -> void:
	var spin: float = Input.get_axis("ui_left", "ui_right")
	var tilt: float = Input.get_axis("ui_down", "ui_up")
	if is_zero_approx(spin) and is_zero_approx(tilt):
		return
	_yaw_deg = fposmod(_yaw_deg + spin * ROTATE_SPEED_DEG * delta, 360.0)
	_pitch_deg = clampf(_pitch_deg + tilt * ROTATE_SPEED_DEG * delta, -MAX_PITCH_DEG, MAX_PITCH_DEG)
	_apply_planet_rotation()


func _apply_planet_rotation() -> void:
	# Spin around the planet axis first, then tilt the whole globe towards the
	# camera, so that the poles behave the way a desk globe does.
	_planet_pivot.basis = (
		Basis(Vector3.RIGHT, deg_to_rad(_pitch_deg)) * Basis(Vector3.UP, deg_to_rad(_yaw_deg))
	)


func _apply_camera_distance() -> void:
	_camera.position = Vector3(0.0, 0.0, _camera_distance)


func _refresh_paths() -> void:
	for i in _rovers.size():
		_paths[i].refresh(_rovers[i].remaining_path(PATH_SAMPLES))


func _handle_click(screen_pos: Vector2) -> void:
	var clicked: GeoCoord = _geo_under_cursor(screen_pos)
	if clicked == null:
		_select(null)
		return
	var rover: Rover = _rover_near(clicked)
	if rover != null:
		_select(rover)
	elif _selected != null:
		_selected.order_move_to(clicked)


func _select(rover: Rover) -> void:
	if _selected != null:
		_selected.set_selected(false)
	_selected = rover
	if _selected != null:
		_selected.set_selected(true)


func _rover_near(point: GeoCoord) -> Rover:
	var best: Rover = null
	var best_deg: float = PICK_ANGLE_DEG
	for rover in _rovers:
		var distance: float = rover.geo.arc_to_deg(point)
		if distance <= best_deg:
			best_deg = distance
			best = rover
	return best


## Converts a screen position into planet coordinates, or null when the ray
## misses the globe. Only the hemisphere facing the camera can be hit.
func _geo_under_cursor(screen_pos: Vector2) -> GeoCoord:
	var to_planet: Transform3D = _planet_pivot.global_transform.affine_inverse()
	var origin: Vector3 = to_planet * _camera.project_ray_origin(screen_pos)
	var direction: Vector3 = to_planet.basis * _camera.project_ray_normal(screen_pos)
	var hit: Geo.SphereHit = Geo.ray_sphere(origin, direction, PLANET_RADIUS)
	if not hit.hit:
		return null
	return Geo.geo_from_unit(hit.point)


func _refresh_info() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Стрелки — вращение планеты · Колесо мыши — зум")
	lines.append("ЛКМ по роверу — выбрать · ЛКМ по планете — приказ ехать · ПКМ — снять выбор")
	if _selected == null:
		lines.append("Ровер не выбран")
	else:
		var status: String = "стоит"
		if _selected.is_moving():
			status = (
				"едет в (%s), осталось %.1f°"
				% [str(_selected.target_geo()), _selected.remaining_arc_deg()]
			)
		lines.append("%s: (%s) — %s" % [_selected.title, str(_selected.geo), status])
	if _cursor_geo != null:
		lines.append("Курсор: (%s)" % str(_cursor_geo))
	_info_label.text = "\n".join(lines)
