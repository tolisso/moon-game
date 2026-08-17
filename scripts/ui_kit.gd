class_name UiKit
extends RefCounted

## Shared building blocks for the two in-game windows, so they look the same
## without a theme resource.

const TITLE_FONT_SIZE: int = 17
const CELL_FONT_SIZE: int = 15
const HINT_FONT_SIZE: int = 13
const ACTION_WIDTH: float = 190.0

const TEXT_COLOR: Color = Color(0.87, 0.92, 1.0)
const TITLE_COLOR: Color = Color(1.0, 0.85, 0.5)
const HINT_COLOR: Color = Color(0.55, 0.64, 0.78)
const WARN_COLOR: Color = Color(1.0, 0.55, 0.45)


## Builds CenterContainer > PanelContainer > VBoxContainer inside `owner` and
## returns the column that content should go into.
static func centered_panel(owner: Control) -> VBoxContainer:
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(centre)

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	centre.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column


static func panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	style.border_color = Color(0.35, 0.62, 0.9, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16.0)
	return style


static func label(text: String, font_size: int, font_color: Color) -> Label:
	var item: Label = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", font_color)
	return item


static func title(text: String) -> Label:
	return label(text, TITLE_FONT_SIZE, TITLE_COLOR)


static func hint(text: String) -> Label:
	return label(text, HINT_FONT_SIZE, HINT_COLOR)


static func cell(text: String, min_width: float) -> Label:
	var item: Label = label(text, CELL_FONT_SIZE, TEXT_COLOR)
	item.custom_minimum_size = Vector2(min_width, 0.0)
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return item


static func action_button(text: String, min_width: float = ACTION_WIDTH) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(min_width, 0.0)
	return button


static func row() -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	return box


static func swatch(color: Color) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(14.0, 14.0)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect
