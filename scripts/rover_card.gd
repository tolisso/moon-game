class_name RoverCard
extends PanelContainer

## Left-rail card: select a rover and buy energy / weight upgrades.

signal selected(rover: Rover)
signal upgrade_requested(rover: Rover, stat: Rover.Stat)

const BUTTON_HEIGHT: float = 32.0
const SWATCH_SIZE: float = 18.0


var rover: Rover = null

var _status: Label = null
var _energy_button: Button = null
var _weight_button: Button = null
var _idle_style: StyleBoxFlat = null
var _selected_style: StyleBoxFlat = null


func setup(target: Rover) -> void:
	rover = target
	mouse_filter = Control.MOUSE_FILTER_STOP
	_idle_style = _make_style(Color(0.07, 0.09, 0.13, 0.98), Color(0.28, 0.42, 0.58, 0.75))
	_selected_style = _make_style(Color(0.1, 0.14, 0.2, 0.98), Color(rover.color.lightened(0.15)))
	_selected_style.set_border_width_all(2)
	add_theme_stylebox_override("panel", _idle_style)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var header: HBoxContainer = UiKit.row()
	header.add_child(_swatch(rover.color))
	var title: Label = UiKit.cell(rover.title, 0.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	column.add_child(header)

	_status = UiKit.label("", UiKit.HINT_FONT_SIZE, UiKit.HINT_COLOR)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var buttons: HBoxContainer = UiKit.row()
	buttons.add_theme_constant_override("separation", 8)
	_energy_button = _stat_button()
	_weight_button = _stat_button()
	_energy_button.pressed.connect(_on_upgrade.bind(Rover.Stat.ENERGY))
	_weight_button.pressed.connect(_on_upgrade.bind(Rover.Stat.WEIGHT))
	buttons.add_child(_energy_button)
	buttons.add_child(_weight_button)
	column.add_child(buttons)


func refresh(gold: int, is_selected: bool) -> void:
	if rover == null:
		return
	add_theme_stylebox_override("panel", _selected_style if is_selected else _idle_style)
	if rover.is_busy():
		_status.text = "в рейсе · %.1f с" % rover.remaining_trip_time()
	else:
		_status.text = "на базе · заряд %.2f/%d" % [rover.energy, rover.max_energy]
	_refresh_button(_energy_button, Rover.Stat.ENERGY, "Энергия", gold)
	_refresh_button(_weight_button, Rover.Stat.WEIGHT, "Вес", gold)


func _refresh_button(button: Button, stat: Rover.Stat, caption: String, gold: int) -> void:
	var level: int = int(rover.stat_value(stat))
	button.text = "%s %d" % [caption, level]
	if rover.is_stat_maxed(stat):
		button.disabled = true
		return
	button.disabled = gold < rover.upgrade_cost(stat)


func _stat_button() -> Button:
	var button: Button = UiKit.action_button("", 0.0)
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _swatch(color: Color) -> ColorRect:
	var rect: ColorRect = UiKit.swatch(color)
	rect.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	return rect


func _on_upgrade(stat: Rover.Stat) -> void:
	upgrade_requested.emit(rover, stat)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	selected.emit(rover)
	accept_event()


func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12.0)
	return style
