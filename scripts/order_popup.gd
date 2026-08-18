class_name OrderPopup
extends PanelContainer

## Compact 2D card pinned above a delivery marker in screen space.

signal send_pressed(order: DeliveryOrder)

const CARD_WIDTH: float = 118.0


var order: DeliveryOrder = null

var _reward: Label = null
var _weight: Label = null
var _action: Label = null
var _send: Button = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	add_theme_stylebox_override("panel", _style())

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	_reward = UiKit.label("", UiKit.CELL_FONT_SIZE, UiKit.TITLE_COLOR)
	column.add_child(_reward)
	_weight = UiKit.label("", UiKit.CELL_FONT_SIZE, UiKit.TEXT_COLOR)
	column.add_child(_weight)
	_action = UiKit.label("", UiKit.HINT_FONT_SIZE, UiKit.HINT_COLOR)
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_action)
	_send = UiKit.action_button("▶", CARD_WIDTH - 20.0)
	_send.pressed.connect(_on_send)
	column.add_child(_send)


func setup(target: DeliveryOrder) -> void:
	order = target
	_reward.text = "%d золото" % Balance.DELIVERY_REWARD
	_weight.text = "вес %d" % int(target.cargo)


func refresh(rover: Rover, distance_deg: float) -> void:
	if rover == null or order == null:
		return
	var too_heavy: bool = not rover.can_carry(order.cargo)
	_send.visible = not too_heavy
	if too_heavy:
		_action.visible = true
		_action.text = "вес"
		_action.add_theme_color_override("font_color", UiKit.WARN_COLOR)
		return
	_action.add_theme_color_override("font_color", UiKit.HINT_COLOR)
	var wait: float = rover.wait_until_start(distance_deg)
	if wait > 0.05:
		_action.visible = true
		_action.text = "%.1f с" % wait
		_send.disabled = true
	else:
		_action.visible = false
		_send.disabled = false


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
