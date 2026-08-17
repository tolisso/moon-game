class_name MissionDialog
extends Control

## Window that opens on a delivery order and lists the whole fleet: capacity,
## energy, speed under this load, round-trip time and whether the rover can
## take the job.

signal dispatch_requested(rover: Rover, order: DeliveryOrder)

const NAME_WIDTH: float = 90.0
const CARGO_WIDTH: float = 80.0
const ENERGY_WIDTH: float = 150.0
const SPEED_WIDTH: float = 130.0
const TIME_WIDTH: float = 80.0


## One fleet entry; keeps the live cells so the list can update in place
## instead of being rebuilt while the player is aiming at a button.
class Row:
	extends RefCounted

	var rover: Rover = null
	var energy: Label = null
	var speed: Label = null
	var time: Label = null
	var send: Button = null
	var reason: Label = null
	var box: HBoxContainer = null

	func refresh(cargo: float, distance_deg: float) -> void:
		energy.text = "энергия %.0f/%.0f" % [rover.energy, rover.max_energy]
		speed.text = "%.0f → %.0f °/с" % [rover.base_speed_deg, rover.loaded_speed(cargo)]
		time.text = "%.1f с" % rover.travel_time(distance_deg, cargo)
		var why: String = rover.rejection_reason(cargo, distance_deg * 2.0)
		var possible: bool = why.is_empty()
		send.visible = possible
		reason.visible = not possible
		reason.text = why
		box.modulate = Color(1.0, 1.0, 1.0, 1.0 if possible else 0.5)


var _order: DeliveryOrder = null
var _distance_deg: float = 0.0
var _title: Label = null
var _rows_box: VBoxContainer = null
var _rows: Array[Row] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column: VBoxContainer = UiKit.centered_panel(self)
	_title = UiKit.title("")
	column.add_child(_title)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	column.add_child(_rows_box)
	column.add_child(UiKit.hint("Скорость показана без груза → с этим грузом. Esc или ПКМ — закрыть"))
	visible = false


func is_open() -> bool:
	return visible


func showing_order() -> DeliveryOrder:
	return _order


func open(order: DeliveryOrder, fleet: Array[Rover], distance_deg: float) -> void:
	_order = order
	_distance_deg = distance_deg
	_title.text = (
		"Заказ: %.0f т · до точки %.0f° · награда %d зол."
		% [order.cargo, distance_deg, Balance.delivery_reward(distance_deg, order.cargo)]
	)
	for row in _rows:
		_rows_box.remove_child(row.box)
		row.box.queue_free()
	_rows.clear()
	for rover in fleet:
		var row: Row = _build_row(rover)
		_rows.append(row)
		_rows_box.add_child(row.box)
	_refresh()
	visible = true


func close() -> void:
	visible = false
	_order = null


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _order == null:
		return
	for row in _rows:
		row.refresh(_order.cargo, _distance_deg)


func _build_row(rover: Rover) -> Row:
	var row: Row = Row.new()
	row.rover = rover
	row.box = UiKit.row()
	row.box.add_child(UiKit.swatch(rover.color))
	row.box.add_child(UiKit.cell(rover.title, NAME_WIDTH))
	row.box.add_child(UiKit.cell("до %.0f т" % rover.max_cargo, CARGO_WIDTH))
	row.energy = UiKit.cell("", ENERGY_WIDTH)
	row.box.add_child(row.energy)
	row.speed = UiKit.cell("", SPEED_WIDTH)
	row.box.add_child(row.speed)
	row.time = UiKit.cell("", TIME_WIDTH)
	row.box.add_child(row.time)

	# Button and reason share a width so the panel does not jump when a rover
	# switches between available and rejected.
	row.send = UiKit.action_button("Отправить")
	row.send.pressed.connect(_on_send_pressed.bind(rover))
	row.box.add_child(row.send)
	row.reason = UiKit.cell("", UiKit.ACTION_WIDTH)
	row.reason.add_theme_color_override("font_color", UiKit.WARN_COLOR)
	row.box.add_child(row.reason)
	return row


func _on_send_pressed(rover: Rover) -> void:
	if _order == null:
		return
	dispatch_requested.emit(rover, _order)
	close()
