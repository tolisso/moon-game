class_name OrderPopup
extends PanelContainer

## Compact 2D card pinned above a delivery marker in screen space.
## Every row has a fixed slot so refresh never changes size or shifts siblings.

signal send_pressed(order: DeliveryOrder)

const CARD_WIDTH: float = 118.0
const CARD_HEIGHT: float = 86.0
const TIMER_HEIGHT: float = 6.0
const BUTTON_HEIGHT: float = 28.0
const INNER_WIDTH: float = CARD_WIDTH - 16.0


var order: DeliveryOrder = null

var _timer: ProgressBar = null
var _reward: Label = null
var _weight: Label = null
var _send: Button = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	add_theme_stylebox_override("panel", _style())

	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(INNER_WIDTH, CARD_HEIGHT - 16.0)
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	_timer = ProgressBar.new()
	_timer.custom_minimum_size = Vector2(INNER_WIDTH, TIMER_HEIGHT)
	_timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer.max_value = 1.0
	_timer.value = 1.0
	_timer.show_percentage = false
	_timer.add_theme_stylebox_override("background", _timer_back())
	_timer.add_theme_stylebox_override("fill", _timer_fill())
	column.add_child(_timer)

	_reward = _fixed_label(UiKit.CELL_FONT_SIZE, UiKit.TITLE_COLOR)
	column.add_child(_reward)
	_weight = _fixed_label(UiKit.CELL_FONT_SIZE, UiKit.TEXT_COLOR)
	column.add_child(_weight)

	_send = UiKit.action_button("▶", INNER_WIDTH)
	_send.custom_minimum_size = Vector2(INNER_WIDTH, BUTTON_HEIGHT)
	_send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_send.pressed.connect(_on_send)
	column.add_child(_send)


func setup(target: DeliveryOrder) -> void:
	order = target
	_reward.text = "%d золото" % Balance.DELIVERY_REWARD
	_weight.text = "вес %d" % int(target.cargo)
	_timer.value = target.lifetime_ratio()


func refresh(rover: Rover, distance_deg: float) -> void:
	if rover == null or order == null:
		return
	_timer.value = order.lifetime_ratio()
	var expired: bool = order.time_left <= 0.0
	var too_heavy: bool = not rover.can_carry(order.cargo)

	if expired:
		_set_button("истекло", UiKit.WARN_COLOR, false)
	elif too_heavy:
		_set_button("вес", UiKit.WARN_COLOR, false)
	else:
		var wait: float = rover.wait_until_start(distance_deg)
		if wait > 0.05:
			_set_button("%.1f с" % wait, UiKit.HINT_COLOR, false)
		else:
			_set_button("▶", UiKit.TEXT_COLOR, true)


func _set_button(text: String, color: Color, can_send: bool) -> void:
	_send.text = text
	_send.disabled = not can_send
	_send.add_theme_color_override("font_color", color)
	_send.add_theme_color_override("font_disabled_color", color)
	_send.modulate = Color.WHITE


func _fixed_label(font_size: int, color: Color) -> Label:
	var label: Label = UiKit.label("", font_size, color)
	label.custom_minimum_size = Vector2(INNER_WIDTH, font_size + 4.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _on_send() -> void:
	if order != null:
		send_pressed.emit(order)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.94)
	style.border_color = Color(0.35, 0.62, 0.9, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8.0)
	return style


func _timer_back() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 1.0)
	style.set_corner_radius_all(2)
	return style


func _timer_fill() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.72, 0.28, 1.0)
	style.set_corner_radius_all(2)
	return style
