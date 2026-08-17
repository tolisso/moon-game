class_name MissionDialog
extends Control

## Window that opens on a delivery order and lists the whole fleet: capacity,
## energy, speed, round-trip time and whether the rover can take the job.

signal dispatch_requested(rover: Rover, order: DeliveryOrder)

const TITLE_FONT_SIZE: int = 17
const CELL_FONT_SIZE: int = 15
const ACTION_WIDTH: float = 190.0


## One fleet entry; keeps the live cells so the list can update in place
## instead of being rebuilt while the player is aiming at a button.
class Row:
	extends RefCounted

	var rover: Rover = null
	var box: HBoxContainer = null
	var energy: Label = null
	var time: Label = null
	var send: Button = null
	var reason: Label = null

	func refresh(cargo: float, round_trip_deg: float) -> void:
		energy.text = "энергия %.0f/%.0f" % [rover.energy, rover.max_energy]
		time.text = "%.1f с" % rover.travel_time(round_trip_deg)
		var why: String = rover.rejection_reason(cargo, round_trip_deg)
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

	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	centre.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	_title = _make_label("", TITLE_FONT_SIZE, Color(1.0, 0.85, 0.5))
	column.add_child(_title)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	column.add_child(_rows_box)

	column.add_child(_make_label("Esc или ПКМ — закрыть", CELL_FONT_SIZE - 2, Color(0.55, 0.64, 0.78)))
	visible = false


func is_open() -> bool:
	return visible


func showing_order() -> DeliveryOrder:
	return _order


func open(order: DeliveryOrder, fleet: Array[Rover], distance_deg: float) -> void:
	_order = order
	_distance_deg = distance_deg
	_title.text = (
		"Заказ: %.0f т · до точки %.0f° · туда-обратно %.0f°"
		% [order.cargo, distance_deg, distance_deg * 2.0]
	)
	for row in _rows:
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
		row.refresh(_order.cargo, _distance_deg * 2.0)


func _build_row(rover: Rover) -> Row:
	var row: Row = Row.new()
	row.rover = rover
	row.box = HBoxContainer.new()
	row.box.add_theme_constant_override("separation", 10)

	var swatch: ColorRect = ColorRect.new()
	swatch.color = rover.color
	swatch.custom_minimum_size = Vector2(14.0, 14.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.box.add_child(swatch)

	row.box.add_child(_make_cell(rover.title, 90.0))
	row.box.add_child(_make_cell("до %.0f т" % rover.max_cargo, 80.0))
	row.energy = _make_cell("", 150.0)
	row.box.add_child(row.energy)
	row.box.add_child(_make_cell("%.0f°/с" % rover.speed_deg, 70.0))
	row.time = _make_cell("", 80.0)
	row.box.add_child(row.time)

	# Button and reason share a width so the panel does not jump when a rover
	# switches between available and rejected.
	row.send = Button.new()
	row.send.text = "Отправить"
	row.send.focus_mode = Control.FOCUS_NONE
	row.send.custom_minimum_size = Vector2(ACTION_WIDTH, 0.0)
	row.send.pressed.connect(_on_send_pressed.bind(rover))
	row.box.add_child(row.send)

	row.reason = _make_cell("", ACTION_WIDTH)
	row.reason.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	row.box.add_child(row.reason)
	return row


func _on_send_pressed(rover: Rover) -> void:
	if _order == null:
		return
	dispatch_requested.emit(rover, _order)
	close()


func _make_cell(text: String, min_width: float) -> Label:
	var label: Label = _make_label(text, CELL_FONT_SIZE, Color(0.87, 0.92, 1.0))
	label.custom_minimum_size = Vector2(min_width, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_label(text: String, font_size: int, font_color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	style.border_color = Color(0.35, 0.62, 0.9, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16.0)
	return style
