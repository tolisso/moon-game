class_name UpgradeDialog
extends Control

## Base window: spend gold on rover stats. Prices grow by a factor per purchase
## (see `Balance.UPGRADE_COST_GROWTH`), the stats themselves grow linearly.

signal upgrade_requested(rover: Rover, stat: Rover.Stat)

const STATS: Array[Rover.Stat] = [
	Rover.Stat.SPEED,
	Rover.Stat.ENERGY,
	Rover.Stat.STRENGTH,
]
const NAME_WIDTH: float = 110.0
const VALUE_WIDTH: float = 170.0
const COST_WIDTH: float = 120.0
const INDENT_WIDTH: float = 24.0


class Row:
	extends RefCounted

	var rover: Rover = null
	var stat: Rover.Stat = Rover.Stat.SPEED
	var value: Label = null
	var button: Button = null


class Header:
	extends RefCounted

	var rover: Rover = null
	var status: Label = null


var _gold: int = 0
var _title: Label = null
var _list: VBoxContainer = null
var _rows: Array[Row] = []
var _headers: Array[Header] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var column: VBoxContainer = UiKit.centered_panel(self)
	_title = UiKit.title("")
	column.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	column.add_child(_list)
	column.add_child(UiKit.hint("Esc или ПКМ — закрыть"))
	visible = false


func is_open() -> bool:
	return visible


func set_gold(gold: int) -> void:
	_gold = gold


func open(fleet: Array[Rover], gold: int) -> void:
	_gold = gold
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_headers.clear()
	for rover in fleet:
		_build_rover_block(rover)
	_refresh()
	visible = true


func close() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_title.text = "База · золото: %d" % _gold
	for header in _headers:
		header.status.text = "в рейсе" if header.rover.is_busy() else "на базе"
	for row in _rows:
		row.value.text = _format_stat(row.rover, row.stat)
		var cost: int = row.rover.upgrade_cost(row.stat)
		row.button.text = "%d зол." % cost
		row.button.disabled = _gold < cost


func _build_rover_block(rover: Rover) -> void:
	var header: Header = Header.new()
	header.rover = rover
	var header_box: HBoxContainer = UiKit.row()
	header_box.add_child(UiKit.swatch(rover.color))
	header_box.add_child(UiKit.cell(rover.title, NAME_WIDTH))
	header.status = UiKit.cell("", 90.0)
	header_box.add_child(header.status)
	_headers.append(header)
	_list.add_child(header_box)

	for stat in STATS:
		var row: Row = Row.new()
		row.rover = rover
		row.stat = stat
		row.value = UiKit.cell("", VALUE_WIDTH)
		row.button = UiKit.action_button("", COST_WIDTH)
		row.button.pressed.connect(_on_upgrade_pressed.bind(rover, stat))

		var box: HBoxContainer = UiKit.row()
		box.add_child(UiKit.cell("", INDENT_WIDTH))
		box.add_child(UiKit.cell(_stat_name(stat), NAME_WIDTH))
		box.add_child(row.value)
		box.add_child(row.button)
		_rows.append(row)
		_list.add_child(box)


func _on_upgrade_pressed(rover: Rover, stat: Rover.Stat) -> void:
	upgrade_requested.emit(rover, stat)


func _stat_name(stat: Rover.Stat) -> String:
	match stat:
		Rover.Stat.SPEED:
			return "Скорость"
		Rover.Stat.ENERGY:
			return "Энергия"
		Rover.Stat.STRENGTH:
			return "Сила"
	return ""


func _format_stat(rover: Rover, stat: Rover.Stat) -> String:
	var current: float = rover.stat_value(stat)
	var upgraded: float = current + rover.stat_step(stat)
	match stat:
		Rover.Stat.SPEED:
			return "%.0f → %.0f °/с" % [current, upgraded]
		_:
			return "%.0f → %.0f" % [current, upgraded]
