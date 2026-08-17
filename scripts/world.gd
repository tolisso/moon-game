extends Node3D

## Game root: owns the planet, the camera, the fleet parked at the base, the
## delivery orders appearing on the surface and the gold purse.
## Gameplay numbers are not here — they live in `balance.gd`.

const PLANET_RADIUS: float = 1.0
const ROTATE_SPEED_DEG: float = 80.0
const MAX_PITCH_DEG: float = 85.0
const PATH_SAMPLES: int = 96
const CAMERA_MIN_DIST: float = 1.6
const CAMERA_MAX_DIST: float = 6.0
const CAMERA_ZOOM_STEP: float = 0.2
const BASE_GEO_LAT: float = 0.0
const BASE_GEO_LON: float = 40.0

@onready var _planet_pivot: Node3D = $PlanetPivot
@onready var _graticule: Graticule = $PlanetPivot/Graticule
@onready var _base: BaseStation = $PlanetPivot/Base
@onready var _rovers_root: Node3D = $PlanetPivot/Rovers
@onready var _paths_root: Node3D = $PlanetPivot/Paths
@onready var _orders_root: Node3D = $PlanetPivot/Orders
@onready var _camera: Camera3D = $Camera3D
@onready var _mission_dialog: MissionDialog = $UI/MissionDialog
@onready var _upgrade_dialog: UpgradeDialog = $UI/UpgradeDialog
@onready var _gold_label: Label = $UI/GoldLabel

## Chosen so the base sits in the middle of the screen at startup.
var _yaw_deg: float = 310.0
var _pitch_deg: float = 15.0
var _camera_distance: float = 3.0
var _gold: int = Balance.START_GOLD
var _elapsed: float = 0.0
var _rovers: Array[Rover] = []
var _paths: Array[PathView] = []
var _orders: Array[DeliveryOrder] = []
var _next_order_in: float = 0.0


func _ready() -> void:
	_graticule.build(PLANET_RADIUS)
	_base.setup(PLANET_RADIUS, GeoCoord.new(BASE_GEO_LAT, BASE_GEO_LON))
	_mission_dialog.dispatch_requested.connect(_on_dispatch_requested)
	_upgrade_dialog.upgrade_requested.connect(_on_upgrade_requested)
	_spawn_fleet()
	_apply_planet_rotation()
	_apply_camera_distance()
	_refresh_gold()
	for i in Balance.START_ORDERS:
		_spawn_order()
	_next_order_in = randf_range(Balance.ORDER_INTERVAL_MIN, Balance.ORDER_INTERVAL_MAX)


func _process(delta: float) -> void:
	_elapsed += delta
	_handle_rotation(delta)
	_handle_order_spawning(delta)
	_refresh_paths()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if _any_dialog_open():
				_close_dialogs()
			else:
				_handle_click(button.position)
		MOUSE_BUTTON_RIGHT:
			_close_dialogs()
		MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(_camera_distance - CAMERA_ZOOM_STEP, CAMERA_MIN_DIST)
			_apply_camera_distance()
		MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(_camera_distance + CAMERA_ZOOM_STEP, CAMERA_MAX_DIST)
			_apply_camera_distance()


func _spawn_fleet() -> void:
	var colors: Array[Color] = [
		Color(1.0, 0.44, 0.26),
		Color(0.4, 0.85, 0.45),
		Color(0.35, 0.7, 1.0),
		Color(0.95, 0.55, 0.9),
		Color(0.95, 0.88, 0.4),
	]
	for i in Balance.ROVER_COUNT:
		var rover: Rover = Rover.new()
		rover.title = "Ровер %d" % (i + 1)
		rover.color = colors[i % colors.size()]
		rover.base_speed_deg = snappedf(
			randf_range(Balance.START_SPEED_MIN, Balance.START_SPEED_MAX), 1.0
		)
		rover.max_energy = snappedf(
			randf_range(Balance.START_ENERGY_MIN, Balance.START_ENERGY_MAX), 5.0
		)
		rover.strength = snappedf(
			randf_range(Balance.START_STRENGTH_MIN, Balance.START_STRENGTH_MAX), 1.0
		)
		rover.delivered.connect(_on_delivered)
		_rovers_root.add_child(rover)
		rover.initialize(PLANET_RADIUS, _base.geo)
		_rovers.append(rover)

		var path: PathView = PathView.new()
		_paths_root.add_child(path)
		path.setup(PLANET_RADIUS, rover.color)
		_paths.append(path)


func _handle_order_spawning(delta: float) -> void:
	if _orders.size() >= Balance.MAX_ORDERS:
		return
	_next_order_in -= delta
	if _next_order_in > 0.0:
		return
	_next_order_in = randf_range(Balance.ORDER_INTERVAL_MIN, Balance.ORDER_INTERVAL_MAX)
	_spawn_order()


func _spawn_order() -> void:
	var cargo: float = _next_order_cargo()
	var reach_deg: float = minf(_fleet_reach_deg(cargo), Balance.ORDER_MAX_DISTANCE_DEG)
	if reach_deg <= Balance.ORDER_MIN_DISTANCE_DEG:
		return
	var order: DeliveryOrder = DeliveryOrder.new()
	_orders_root.add_child(order)
	order.setup(
		PLANET_RADIUS,
		_geo_away_from_base(randf_range(Balance.ORDER_MIN_DISTANCE_DEG, reach_deg)),
		cargo
	)
	_orders.append(order)


## Grows linearly with play time, with some jitter around the trend.
func _next_order_cargo() -> float:
	var target: float = Balance.order_target_cargo(_elapsed)
	var jitter: float = randf_range(
		1.0 - Balance.ORDER_CARGO_JITTER, 1.0 + Balance.ORDER_CARGO_JITTER
	)
	return maxf(round(target * jitter), 1.0)


## One-way distance the biggest battery in the fleet can afford with this load.
func _fleet_reach_deg(cargo: float) -> float:
	var best: float = 0.0
	for rover in _rovers:
		best = maxf(best, Balance.reach_deg(rover.max_energy, cargo))
	return best * Balance.ORDER_REACH_MARGIN


## Random point at the given angular distance from the base, any direction.
func _geo_away_from_base(distance_deg: float) -> GeoCoord:
	var centre: Vector3 = _base.geo.to_unit()
	var u: Vector3 = Geo.any_tangent(centre)
	var v: Vector3 = centre.cross(u)
	var azimuth: float = randf() * TAU
	var radial: Vector3 = u * cos(azimuth) + v * sin(azimuth)
	var distance: float = deg_to_rad(distance_deg)
	return Geo.geo_from_unit(centre * cos(distance) + radial * sin(distance))


func _on_dispatch_requested(rover: Rover, order: DeliveryOrder) -> void:
	var distance_deg: float = _base.geo.arc_to_deg(order.geo)
	if order.assigned or not rover.rejection_reason(distance_deg, order.cargo).is_empty():
		return
	order.set_assigned(true)
	rover.dispatch(order)


func _on_delivered(order: DeliveryOrder) -> void:
	_gold += Balance.delivery_reward(_base.geo.arc_to_deg(order.geo), order.cargo)
	_refresh_gold()
	_orders.erase(order)
	if _mission_dialog.showing_order() == order:
		_mission_dialog.close()
	order.queue_free()


func _on_upgrade_requested(rover: Rover, stat: Rover.Stat) -> void:
	var cost: int = rover.upgrade_cost(stat)
	if cost > _gold:
		return
	_gold -= cost
	rover.apply_upgrade(stat)
	_refresh_gold()


func _refresh_gold() -> void:
	_gold_label.text = "Золото: %d" % _gold
	_upgrade_dialog.set_gold(_gold)


func _any_dialog_open() -> bool:
	return _mission_dialog.is_open() or _upgrade_dialog.is_open()


func _close_dialogs() -> void:
	_mission_dialog.close()
	_upgrade_dialog.close()


func _handle_rotation(delta: float) -> void:
	var spin: float = Input.get_axis("ui_right", "ui_left")
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
	var point: GeoCoord = _geo_under_cursor(screen_pos)
	if point == null:
		return
	var order: DeliveryOrder = _order_near(point)
	if order != null:
		_mission_dialog.open(order, _rovers, _base.geo.arc_to_deg(order.geo))
	elif _base.covers(point):
		_upgrade_dialog.open(_rovers, _gold)


func _order_near(point: GeoCoord) -> DeliveryOrder:
	var best: DeliveryOrder = null
	var best_deg: float = INF
	for order in _orders:
		if order.assigned:
			continue
		var distance: float = order.geo.arc_to_deg(point)
		if distance <= order.pick_radius_deg() and distance < best_deg:
			best_deg = distance
			best = order
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
