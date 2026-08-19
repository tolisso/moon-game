extends Control

## Game root: left UI pane and a right 3D viewport, plus fleet and orders.
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
const DIFFICULTY_COLORS: Array[Color] = [
	Color(0.32, 0.82, 0.28),
	Color(0.72, 0.88, 0.18),
	Color(0.96, 0.82, 0.16),
	Color(1.0, 0.52, 0.14),
	Color(0.88, 0.18, 0.14),
	Color(0.5, 0.08, 0.16),
]

@onready var _planet_pivot: Node3D = %PlanetPivot
@onready var _graticule: Graticule = %PlanetPivot/Graticule
@onready var _craters: Craters = %PlanetPivot/Craters
@onready var _base: BaseStation = %PlanetPivot/Base
@onready var _rovers_root: Node3D = %PlanetPivot/Rovers
@onready var _paths_root: Node3D = %PlanetPivot/Paths
@onready var _orders_root: Node3D = %PlanetPivot/Orders
@onready var _range_view: RangeView = %PlanetPivot/RangeView
@onready var _camera: Camera3D = %Camera3D
@onready var _world_view: SubViewportContainer = %WorldView
@onready var _left_panel: PanelContainer = %LeftPanel
@onready var _gold_label: Label = %GoldLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _fleet_host: VBoxContainer = %Fleet
@onready var _popups_root: Control = %OrderPopups
@onready var _difficulty_slider: HSlider = %DifficultySlider
@onready var _difficulty_label: Label = %DifficultyLabel

## Pitch is clamped to ±85°; start at the top so the north-pole base faces us.
var _yaw_deg: float = 0.0
var _pitch_deg: float = MAX_PITCH_DEG
var _camera_distance: float = 3.0
var _gold: int = Balance.START_GOLD
var _gold_earned: int = 0
var _round_left: float = Balance.ROUND_DURATION_SEC
var _round_over: bool = false
var _score_overlay: Control = null
var _score_label: Label = null
var _rovers: Array[Rover] = []
var _cards: Array[RoverCard] = []
var _paths: Array[PathView] = []
var _orders: Array[DeliveryOrder] = []
var _popups: Array[OrderPopup] = []
var _next_order_in: float = 0.0
var _selected: Rover = null
var _difficulty: int = 3


func _ready() -> void:
	_graticule.build(PLANET_RADIUS)
	_base.setup(PLANET_RADIUS, GeoCoord.new(BASE_GEO_LAT, BASE_GEO_LON))
	_craters.setup(PLANET_RADIUS, _base.geo)
	_range_view.setup(PLANET_RADIUS)
	_range_view.build_contours(_base.geo, _craters)
	_style_left_panel()
	_style_right_pane()
	_style_top_bar()
	_setup_difficulty_slider()
	_build_score_overlay()
	_spawn_fleet()
	_apply_planet_rotation()
	_apply_camera_distance()
	_world_view.gui_input.connect(_on_world_gui_input)
	_refresh_gold()
	_refresh_timer()
	_refresh_fleet_cards()
	for i in Balance.START_ORDERS:
		_spawn_order()
	_next_order_in = Balance.ORDER_SPAWN_INTERVAL


func _setup_difficulty_slider() -> void:
	_difficulty_slider.min_value = Balance.STAT_MIN
	_difficulty_slider.max_value = Balance.STAT_MAX
	_difficulty_slider.step = 1.0
	_difficulty_slider.focus_mode = Control.FOCUS_NONE
	_difficulty_slider.value = _difficulty
	_difficulty_slider.value_changed.connect(_on_difficulty_changed)
	_style_difficulty_slider()
	_refresh_difficulty_label()


func _on_difficulty_changed(value: float) -> void:
	_difficulty = int(value)
	_refresh_difficulty_label()
	_style_difficulty_slider()


func _refresh_difficulty_label() -> void:
	_difficulty_label.text = "Сложность: %d (max вес и дальность)" % _difficulty
	_difficulty_label.add_theme_color_override("font_color", _difficulty_color())


func _process(delta: float) -> void:
	if _round_over:
		return
	_tick_round(delta)
	_handle_rotation(delta)
	_tick_orders(delta)
	_handle_order_spawning(delta)
	_refresh_paths()
	_refresh_selection_visuals()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if _handle_number_key(key.keycode):
			get_viewport().set_input_as_handled()
			return
		if key.is_action_pressed("ui_cancel"):
			_select_rover(null)
			return

func _on_world_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_RIGHT:
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
		rover.initialize(PLANET_RADIUS, _base.geo, _craters)
		_rovers.append(rover)

		var path: PathView = PathView.new()
		_paths_root.add_child(path)
		path.setup(PLANET_RADIUS, rover.color)
		_paths.append(path)

		var card: RoverCard = RoverCard.new()
		_fleet_host.add_child(card)
		card.setup(rover)
		card.selected.connect(_on_card_selected)
		card.upgrade_requested.connect(_on_upgrade_requested)
		_cards.append(card)


func _handle_order_spawning(delta: float) -> void:
	if _orders.size() >= Balance.MAX_ORDERS:
		return
	_next_order_in -= delta
	if _next_order_in > 0.0:
		return
	_next_order_in = Balance.ORDER_SPAWN_INTERVAL
	_spawn_order()


func _tick_orders(delta: float) -> void:
	var expired: Array[DeliveryOrder] = []
	for order in _orders:
		order.tick(delta)
		if order.is_expired():
			expired.append(order)
	for order in expired:
		_remove_order(order)


func _remove_order(order: DeliveryOrder) -> void:
	_orders.erase(order)
	order.queue_free()
	if _selected != null:
		_rebuild_popups()


func _spawn_order() -> void:
	var max_dist: float = Balance.distance_deg_for_tier(_difficulty)
	var min_dist: float = minf(Balance.ORDER_MIN_DISTANCE_DEG, max_dist)
	var order: DeliveryOrder = DeliveryOrder.new()
	_orders_root.add_child(order)
	order.setup(
		PLANET_RADIUS,
		_geo_away_from_base(randf_range(min_dist, max_dist)),
		float(randi_range(Balance.ORDER_WEIGHT_MIN, _difficulty))
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
	_refresh_selection_visuals()


func _rebuild_popups() -> void:
	_clear_popups()
	if _selected == null:
		return
	for order in _orders:
		if order.assigned or order.is_expired():
			continue
		if not _selected.can_reach(order.geo):
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
	_refresh_fleet_cards()
	if _selected == null:
		return
	_range_view.show_max_energy(_selected.max_energy)
	var surviving: Array[OrderPopup] = []
	for popup in _popups:
		if popup.order == null or not is_instance_valid(popup.order) or popup.order.assigned:
			popup.queue_free()
			continue
		if popup.order.is_expired():
			popup.queue_free()
			continue
		if not _selected.can_reach(popup.order.geo):
			popup.queue_free()
			continue
		popup.refresh(_selected)
		_place_popup(popup)
		popup.update_hover()
		surviving.append(popup)
	_popups = surviving


func _place_popup(popup: OrderPopup) -> void:
	var world_pos: Vector3 = _order_popup_world(popup.order)
	if not _is_front_facing(world_pos):
		popup.modulate.a = 0.0
		popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	popup.modulate.a = 1.0
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var screen: Vector2 = _camera.unproject_position(world_pos)
	var card_size: Vector2 = Vector2(OrderPopup.CARD_WIDTH, OrderPopup.CARD_HEIGHT)
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
	if order.assigned or order.is_expired() or not rover.can_start_now(order.geo, order.cargo):
		return
	order.set_assigned(true)
	rover.dispatch(order)
	_rebuild_popups()


func _on_delivered(order: DeliveryOrder) -> void:
	var reward: int = Balance.delivery_reward(_base.geo.arc_to_deg(order.geo), order.cargo)
	_gold += reward
	_gold_earned += reward
	_refresh_gold()
	_remove_order(order)


func _on_upgrade_requested(rover: Rover, stat: Rover.Stat) -> void:
	if rover.is_stat_maxed(stat):
		return
	var cost: int = rover.upgrade_cost(stat)
	if cost > _gold:
		return
	_gold -= cost
	rover.apply_upgrade(stat)
	_refresh_gold()
	_refresh_fleet_cards()
	if rover == _selected:
		_rebuild_popups()


func _on_card_selected(rover: Rover) -> void:
	_select_rover(null if _selected == rover else rover)


func _refresh_gold() -> void:
	_gold_label.text = "Золото: %d" % _gold


func _refresh_fleet_cards() -> void:
	for card in _cards:
		card.refresh(_gold, card.rover == _selected)


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


func _style_left_panel() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.07, 1.0)
	style.border_color = Color(0.28, 0.4, 0.55, 0.85)
	style.border_width_right = 1
	_left_panel.add_theme_stylebox_override("panel", style)


func _style_right_pane() -> void:
	_world_view.mouse_filter = Control.MOUSE_FILTER_STOP


func _style_top_bar() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.07, 1.0)
	style.border_color = Color(0.28, 0.4, 0.55, 0.85)
	style.border_width_bottom = 1
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	$Layout/TopBar.add_theme_stylebox_override("panel", style)


func _style_difficulty_slider() -> void:
	var color: Color = _difficulty_color()
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	_difficulty_slider.add_theme_stylebox_override("grabber_area", fill)
	_difficulty_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	track.set_corner_radius_all(3)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	_difficulty_slider.add_theme_stylebox_override("slider", track)
	_difficulty_slider.modulate = Color.WHITE


func _difficulty_color() -> Color:
	var index: int = clampi(_difficulty - Balance.STAT_MIN, 0, DIFFICULTY_COLORS.size() - 1)
	return DIFFICULTY_COLORS[index]


func _tick_round(delta: float) -> void:
	_round_left = maxf(_round_left - delta, 0.0)
	_refresh_timer()
	if _round_left <= 0.0:
		_end_round()


func _refresh_timer() -> void:
	var total: int = int(ceil(_round_left)) if _round_left > 0.0 else 0
	var minutes: int = int(total / 60)
	var seconds: int = total % 60
	_timer_label.text = "%d:%02d" % [minutes, seconds]


func _end_round() -> void:
	_round_over = true
	_timer_label.text = "0:00"
	_score_label.text = "Счёт: %d" % _gold_earned
	_score_overlay.visible = true
	get_tree().paused = true


func _build_score_overlay() -> void:
	_score_overlay = Control.new()
	_score_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_score_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_score_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_score_overlay.visible = false
	add_child(_score_overlay)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_score_overlay.add_child(dim)
	var column: VBoxContainer = UiKit.centered_panel(_score_overlay)
	column.add_child(UiKit.title("Время вышло"))
	_score_label = UiKit.title("")
	column.add_child(_score_label)
	column.add_child(UiKit.hint("Заработано монет, без учёта трат"))
