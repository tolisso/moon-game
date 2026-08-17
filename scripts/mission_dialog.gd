class_name MissionDialog
extends Control

## Window that opens on a delivery order. Rovers are sorted by delivery time as
## if their battery were full; the ones that cannot make it even on a full
## charge sink to the bottom of the list.

signal dispatch_requested(rover: Rover, order: DeliveryOrder)

const NAME_WIDTH: float = 100.0
const STATUS_WIDTH: float = 230.0
const ENERGY_WIDTH: float = 130.0
const SEND_WIDTH: float = 44.0


## One fleet entry; keeps the live cells so the list can update in place
## instead of being rebuilt while the player is aiming at a button.
class Row:
	extends RefCounted

	var rover: Rover = null
	var status: Label = null
	var energy: Label = null
	var send: Button = null
	var box: HBoxContainer = null
	## Cells are created in the normal text colour; only switch the override
	## when the state actually flips.
	var _showing_reason: bool = false

	func refresh(distance_deg: float, cargo: float) -> void:
		energy.text = "энергия %.0f/%.0f" % [rover.energy, rover.max_energy]
		var why: String = rover.rejection_reason(distance_deg, cargo)
		var possible: bool = why.is_empty()
		if possible:
			status.text = "%.1f с" % rover.travel_time(distance_deg, cargo)
		else:
			status.text = why
		send.disabled = not possible
		box.modulate = Color(1.0, 1.0, 1.0, 1.0 if possible else 0.55)
		if _showing_reason != not possible:
			_showing_reason = not possible
			status.add_theme_color_override(
				"font_color", UiKit.WARN_COLOR if _showing_reason else UiKit.TEXT_COLOR
			)


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
	column.add_child(UiKit.hint("Сортировка по времени рейса. Esc или ПКМ — закрыть"))
	visible = false


func is_open() -> bool:
	return visible


func showing_order() -> DeliveryOrder:
	return _order


func open(order: DeliveryOrder, fleet: Array[Rover], distance_deg: float) -> void:
	_order = order
	_distance_deg = distance_deg
	var cargo: float = order.cargo
	_title.text = (
		"Заказ: %.0f т · %.0f° от базы · нужно энергии %.0f · награда %d зол."
		% [
			cargo,
			distance_deg,
			Balance.trip_energy(distance_deg, cargo),
			Balance.delivery_reward(distance_deg, cargo),
		]
	)

	for row in _rows:
		_rows_box.remove_child(row.box)
		row.box.queue_free()
	_rows.clear()
	for rover in _sorted_fleet(fleet, distance_deg, cargo):
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


## Fastest first, ignoring the current charge; hopeless rovers last.
func _sorted_fleet(fleet: Array[Rover], distance_deg: float, cargo: float) -> Array[Rover]:
	var sorted: Array[Rover] = fleet.duplicate()
	sorted.sort_custom(
		func(a: Rover, b: Rover) -> bool:
			var a_can: bool = a.can_ever_deliver(distance_deg, cargo)
			var b_can: bool = b.can_ever_deliver(distance_deg, cargo)
			if a_can != b_can:
				return a_can
			return a.travel_time(distance_deg, cargo) < b.travel_time(distance_deg, cargo)
	)
	return sorted


func _refresh() -> void:
	if _order == null:
		return
	for row in _rows:
		row.refresh(_distance_deg, _order.cargo)


func _build_row(rover: Rover) -> Row:
	var row: Row = Row.new()
	row.rover = rover
	row.box = UiKit.row()
	row.box.add_child(UiKit.swatch(rover.color))
	row.box.add_child(UiKit.cell(rover.title, NAME_WIDTH))
	row.status = UiKit.cell("", STATUS_WIDTH)
	row.box.add_child(row.status)
	row.energy = UiKit.cell("", ENERGY_WIDTH)
	row.box.add_child(row.energy)

	row.send = UiKit.action_button("▶", SEND_WIDTH)
	row.send.tooltip_text = "Отправить"
	row.send.pressed.connect(_on_send_pressed.bind(rover))
	row.box.add_child(row.send)
	return row


func _on_send_pressed(rover: Rover) -> void:
	if _order == null:
		return
	dispatch_requested.emit(rover, _order)
	close()
