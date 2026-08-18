extends Node3D

## Game root: planet, camera, fleet, orders, gold, rover selection.
## Gameplay numbers live in `balance.gd`.

const PLANET_RADIUS: float = 1.0
const ROTATE_SPEED_DEG: float = 80.0
const MAX_PITCH_DEG: float = 85.0
const PATH_SAMPLES: int = 96
const CAMERA_MIN_DIST: float = 1.6
const CAMERA_MAX_DIST: float = 6.0
const CAMERA_ZOOM_STEP: float = 0.2
const BASE_GEO_LAT: float = 90.0
const BASE_GEO_LON: float = 0.0
const POPUP_LIFT: float = 0.12
const NUMBER_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3]
const NUMBER_KEYS_PAD: Array[int] = [KEY_KP_1, KEY_KP_2, KEY_KP_3]

@onready var _planet_pivot: Node3D = $PlanetPivot
@onready var _graticule: Graticule = $PlanetPivot/Graticule
@onready var _base: BaseStation = $PlanetPivot/Base
@onready var _rovers_root: Node3D = $PlanetPivot/Rovers
@onready var _paths_root: Node3D = $PlanetPivot/Paths
@onready var _orders_root: Node3D = $PlanetPivot/Orders
@onready var _range_view: RangeView = $PlanetPivot/RangeView
@onready var _camera: Camera3D = $Camera3D
@onready var _upgrade_dialog: UpgradeDialog = $UI/UpgradeDialog
@onready var _gold_label: Label = $UI/GoldLabel
@onready var _status_label: Label = $UI/StatusLabel
@onready var _popups_root: Control = $UI/OrderPopups

## Pitch is clamped to ±85°; start at the top so the north-pole base faces us.
var _yaw_deg: float = 0.0
var _pitch_deg: float = MAX_PITCH_DEG
var _camera_distance: float = 3.0
var _gold: int = Balance.START_GOLD
var _elapsed: float = 0.0
var _rovers: Array[Rover] = []
var _paths: Array[PathView] = []
var _orders: Array[DeliveryOrder] = []
var _popups: Array[OrderPopup] = []
var _next_order_in: float = 0.0
var _selected: Rover = null


func _ready() -> void:
	_graticule.build(PLANET_RADIUS)
	_base.setup(PLANET_RADIUS, GeoCoord.new(BASE_GEO_LAT, BASE_GEO_LON))
	_range_view.setup(PLANET_RADIUS)
	_upgrade_dialog.upgrade_requested.connect(_on_upgrade_requested)
	_spawn_fleet()
	_apply_planet_rotation()
	_apply_camera_distance()
	_refresh_gold()
	_refresh_status()
	for i in Balance.START_ORDERS:
		_spawn_order()
	_next_order_in = randf_range(Balance.ORDER_INTERVAL_MIN, Balance.ORDER_INTERVAL_MAX)


func _process(delta: float) -> void:
	_elapsed += delta
	_handle_rotation(delta)
	_handle_order_spawning(delta)
	_refresh_paths()
	_refresh_selection_visuals()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if _handle_number_key(key.keycode):
			get_viewport().set_input_as_handled()
			return
		if key.is_action_pressed("ui_cancel") and not _upgrade_dialog.is_open():
			_select_rover(null)
			return

	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if _upgrade_dialog.is_open():
				_upgrade_dialog.close()
			else:
				_handle_click(button.position)
		MOUSE_BUTTON_RIGHT:
			_upgrade_dialog.close()
			_select_rover(null)
		MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(_camera_distance - CAMERA_ZOOM_STEP, CAMERA_MIN_DIST)
			_apply_camera_distance()
		MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(_camera_distance + CAMERA_ZOOM_STEP, CAMERA_MAX_DIST)
			_apply_camera_distance()


func _handle_number_key(keycode: int) -> bool:
	for i in NUMBER_KEYS.size():
		if keycode == NUMBER_KEYS[i] or keycode == NUMBER_KEYS_PAD[i]:
			if i >= _rovers.size():
				return true
			var rover: Rover = _rovers[i]
			_select_rover(null if _selected == rover else rover)
			return true
	return false


func _spawn_fleet() -> void:
	var colors: Array[Color] = [
		Color(1.0, 0.44, 0.26),
		Color(0.4, 0.85, 0.45),
		Color(0.35, 0.7, 1.0),
	]
	for i in Balance.ROVER_COUNT:
		var rover: Rover = Rover.new()
		rover.title = "Ровер %d" % (i + 1)
		rover.color = colors[i % colors.size()]
		rover.max_energy = Balance.START_ENERGY
		rover.max_weight = Balance.START_WEIGHT
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
	var order: DeliveryOrder = DeliveryOrder.new()
	_orders_root.add_child(order)
	order.setup(
		PLANET_RADIUS,
		_geo_away_from_base(
			randf_range(Balance.ORDER_MIN_DISTANCE_DEG, Balance.ORDER_MAX_DISTANCE_DEG)
		),
		float(randi_range(Balance.ORDER_WEIGHT_MIN, Balance.ORDER_WEIGHT_MAX))
	)
	_orders.append(order)
	if _selected != null:
		_rebuild_popups()


func _geo_away_from_base(distance_deg: float) -> GeoCoord:
	var centre: Vector3 = _base.geo.to_unit()
	var u: Vector3 = Geo.any_tangent(centre)
	var v: Vector3 = centre.cross(u)
	var azimuth: float = randf() * TAU
	var radial: Vector3 = u * cos(azimuth) + v * sin(azimuth)
	var distance: float = deg_to_rad(distance_deg)
	return Geo.geo_from_unit(centre * cos(distance) + radial * sin(distance))


func _select_rover(rover: Rover) -> void:
	_selected = rover
	if _selected == null:
		_range_view.hide_ranges()
		_clear_popups()
	else:
		_rebuild_popups()
	_refresh_status()
	_refresh_selection_visuals()


func _rebuild_popups() -> void:
	_clear_popups()
	if _selected == null:
		return
	for order in _orders:
		if order.assigned:
			continue
		var distance_deg: float = _base.geo.arc_to_deg(order.geo)
		if not _selected.can_reach(distance_deg):
			continue
		var popup: OrderPopup = OrderPopup.new()
		_popups_root.add_child(popup)
		popup.setup(order)
		popup.send_pressed.connect(_on_popup_send)
		_popups.append(popup)


func _clear_popups() -> void:
	for popup in _popups:
		popup.queue_free()
	_popups.clear()


func _refresh_selection_visuals() -> void:
	_refresh_status()
	if _selected == null:
		return
	_range_view.show_ranges(
		_base.geo,
		_selected.current_range_deg(),
		_selected.max_range_deg(),
		not _selected.is_busy()
	)
	var surviving: Array[OrderPopup] = []
	for popup in _popups:
		if popup.order == null or not is_instance_valid(popup.order) or popup.order.assigned:
			popup.queue_free()
			continue
		var distance_deg: float = _base.geo.arc_to_deg(popup.order.geo)
		if not _selected.can_reach(distance_deg):
			popup.queue_free()
			continue
		popup.refresh(_selected, distance_deg)
		_place_popup(popup)
		surviving.append(popup)
	_popups = surviving


func _place_popup(popup: OrderPopup) -> void:
	var world_pos: Vector3 = _order_popup_world(popup.order)
	if not _is_front_facing(world_pos):
		popup.visible = false
		return
	popup.visible = true
	var screen: Vector2 = _camera.unproject_position(world_pos)
	var card_size: Vector2 = popup.size
	if card_size.x < 1.0 or card_size.y < 1.0:
		card_size = popup.get_combined_minimum_size()
	popup.position = screen - Vector2(card_size.x * 0.5, card_size.y + 8.0)


func _order_popup_world(order: DeliveryOrder) -> Vector3:
	var local: Vector3 = order.geo.to_unit() * (PLANET_RADIUS + POPUP_LIFT)
	return _planet_pivot.to_global(local)


func _is_front_facing(world_pos: Vector3) -> bool:
	var normal: Vector3 = (world_pos - _planet_pivot.global_position).normalized()
	return normal.dot(_camera.global_position - world_pos) > 0.0


func _on_popup_send(order: DeliveryOrder) -> void:
	if _selected == null:
		return
	_try_dispatch(_selected, order)


func _try_dispatch(rover: Rover, order: DeliveryOrder) -> void:
	var distance_deg: float = _base.geo.arc_to_deg(order.geo)
	if order.assigned or not rover.can_start_now(distance_deg, order.cargo):
		return
	order.set_assigned(true)
	rover.dispatch(order)
	_rebuild_popups()


func _on_delivered(order: DeliveryOrder) -> void:
	_gold += Balance.delivery_reward(_base.geo.arc_to_deg(order.geo), order.cargo)
	_refresh_gold()
	_orders.erase(order)
	order.queue_free()
	if _selected != null:
		_rebuild_popups()


func _on_upgrade_requested(rover: Rover, stat: Rover.Stat) -> void:
	if rover.is_stat_maxed(stat):
		return
	var cost: int = rover.upgrade_cost(stat)
	if cost > _gold:
		return
	_gold -= cost
	rover.apply_upgrade(stat)
	_refresh_gold()
	if _selected != null:
		_rebuild_popups()


func _refresh_gold() -> void:
	_gold_label.text = "Золото: %d" % _gold
	_upgrade_dialog.set_gold(_gold)


func _refresh_status() -> void:
	if _selected == null:
		_status_label.text = ""
		return
	if _selected.is_busy():
		_status_label.text = "%s · возврат %.1f с" % [_selected.title, _selected.remaining_trip_time()]
	else:
		_status_label.text = (
			"%s · заряд %.2f/%d · вес %d"
			% [_selected.title, _selected.energy, _selected.max_energy, _selected.max_weight]
		)


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
	if _base.covers(point):
		_upgrade_dialog.open(_rovers, _gold)


func _geo_under_cursor(screen_pos: Vector2) -> GeoCoord:
	var to_planet: Transform3D = _planet_pivot.global_transform.affine_inverse()
	var origin: Vector3 = to_planet * _camera.project_ray_origin(screen_pos)
	var direction: Vector3 = to_planet.basis * _camera.project_ray_normal(screen_pos)
	var hit: Geo.SphereHit = Geo.ray_sphere(origin, direction, PLANET_RADIUS)
	if not hit.hit:
		return null
	return Geo.geo_from_unit(hit.point)
