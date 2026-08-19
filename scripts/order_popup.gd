class_name OrderPopup
extends PanelContainer

## Compact 2D card pinned above a delivery marker in screen space.
## The whole card is the click target; the old send button is a visual slot.

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
var _action: PanelContainer = null
var _action_label: Label = null
var _can_send: bool = false
var _idle_style: StyleBoxFlat = null
var _hover_style: StyleBoxFlat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_idle_style = _card_style(false)
	_hover_style = _card_style(true)
	add_theme_stylebox_override("panel", _idle_style)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.custom_minimum_size = Vector2(INNER_WIDTH, CARD_HEIGHT - 16.0)
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	_timer = ProgressBar.new()
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	_action = PanelContainer.new()
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action.custom_minimum_size = Vector2(INNER_WIDTH, BUTTON_HEIGHT)
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action.add_theme_stylebox_override("panel", _action_style())
	column.add_child(_action)

	_action_label = Label.new()
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", UiKit.CELL_FONT_SIZE)
	_action.add_child(_action_label)


func setup(target: DeliveryOrder) -> void:
	order = target
	_reward.text = "%d золото" % Balance.delivery_reward(0.0, target.cargo)
	_weight.text = "вес %d" % int(target.cargo)
	_timer.value = target.lifetime_ratio()


func refresh(rover: Rover) -> void:
	if rover == null or order == null:
		return
	_timer.value = order.lifetime_ratio()
	var expired: bool = order.time_left <= 0.0
	var too_heavy: bool = not rover.can_carry(order.cargo)

	if expired:
		_set_action("истекло", UiKit.WARN_COLOR, false)
	elif too_heavy:
		_set_action("вес", UiKit.WARN_COLOR, false)
	else:
		var wait: float = rover.wait_until_start(order.geo)
		if wait > 0.05:
			_set_action("%.1f с" % wait, UiKit.HINT_COLOR, false)
		else:
			_set_action("▶", UiKit.TEXT_COLOR, true)


func _set_action(text: String, color: Color, can_send: bool) -> void:
	_can_send = can_send
	_action_label.text = text
	_action_label.add_theme_color_override("font_color", color)


func _fixed_label(font_size: int, color: Color) -> Label:
	var item: Label = UiKit.label("", font_size, color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.custom_minimum_size = Vector2(INNER_WIDTH, font_size + 4.0)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return item


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null:
		return
	accept_event()
	if not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _can_send and order != null:
		send_pressed.emit(order)


func update_hover() -> void:
	if _idle_style == null or _hover_style == null:
		return
	var hovered: bool = (
		_can_send
		and mouse_filter != Control.MOUSE_FILTER_IGNORE
		and _is_top_hovered()
	)
	add_theme_stylebox_override("panel", _hover_style if hovered else _idle_style)


func _is_top_hovered() -> bool:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	var node: Node = hovered
	while node != null:
		if node == self:
			return true
		node = node.get_parent()
	return false


func _card_style(hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if hovered:
		style.bg_color = Color(0.1, 0.16, 0.26, 0.97)
		style.border_color = Color(0.6, 0.85, 1.0, 1.0)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.05, 0.07, 0.11, 0.94)
		style.border_color = Color(0.35, 0.62, 0.9, 0.8)
		style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8.0)
	return style


func _action_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.0)
	style.set_border_width_all(0)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
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
