class_name LoadDialog
extends Control

## Lists every SQLite save: load or delete.

signal load_requested(save_id: int)
signal closed


var _list: VBoxContainer = null
var _store: SaveStore = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var column: VBoxContainer = UiKit.centered_panel(self)
	column.add_child(UiKit.title("Сохранения"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520.0, 260.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var close_button: Button = UiKit.action_button("Закрыть", 160.0)
	close_button.pressed.connect(_on_close)
	column.add_child(close_button)


func open(store: SaveStore) -> void:
	_store = store
	_rebuild()
	visible = true


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _store == null:
		return
	var saves: Array[Dictionary] = _store.list_saves()
	if saves.is_empty():
		_list.add_child(UiKit.hint("Пока нет сохранений"))
		return
	for row in saves:
		_list.add_child(_make_row(row))


func _make_row(row: Dictionary) -> Control:
	var box: HBoxContainer = UiKit.row()
	var remaining: float = float(row.get("remaining_time", 0.0))
	var total: int = int(ceil(remaining)) if remaining > 0.0 else 0
	var stamp: String = Time.get_datetime_string_from_unix_time(int(row.get("created_at", 0)), true)
	var caption: Label = UiKit.cell(
		"#%d  %d:%02d  счёт %d  золото %d  %s"
		% [
			int(row.get("id", 0)),
			int(total / 60),
			total % 60,
			int(row.get("score", 0)),
			int(row.get("gold", 0)),
			stamp,
		],
		0.0
	)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(caption)
	var load_button: Button = UiKit.action_button("Загрузить", 110.0)
	load_button.pressed.connect(_on_load.bind(int(row.get("id", 0))))
	box.add_child(load_button)
	var delete_button: Button = UiKit.action_button("Удалить", 90.0)
	delete_button.pressed.connect(_on_delete.bind(int(row.get("id", 0))))
	box.add_child(delete_button)
	return box


func _on_load(save_id: int) -> void:
	load_requested.emit(save_id)
	_on_close()


func _on_delete(save_id: int) -> void:
	if _store != null:
		_store.delete_save(save_id)
	_rebuild()


func _on_close() -> void:
	visible = false
	closed.emit()
