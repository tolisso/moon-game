class_name SaveStore
extends RefCounted

## SQLite save slots. Each app launch is a new game; this only stores explicit
## snapshots. Extra columns on `saves` keep craters, difficulty, camera and
## spawn timer so a load can rebuild the round completely.

const DB_PATH: String = "user://moon_saves"


var _db: SQLite = null


func open() -> void:
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.foreign_keys = true
	_db.verbosity_level = 0
	if not _db.open_db():
		push_error("SaveStore: cannot open database: %s" % _db.error_message)
		return
	_ensure_schema()


func close() -> void:
	if _db != null:
		_db.close_db()
		_db = null


func write_save(snapshot: Dictionary) -> int:
	if _db == null:
		return -1
	_db.query("BEGIN TRANSACTION;")
	var ok: bool = _db.query_with_bindings(
		"""
		INSERT INTO saves (
			remaining_time, score, gold, difficulty, next_order_in, round_over,
			yaw, pitch, camera_distance, selected_rover, crater_json, created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
		""",
		[
			snapshot.get("remaining_time", 0.0),
			snapshot.get("score", 0),
			snapshot.get("gold", 0),
			snapshot.get("difficulty", 3),
			snapshot.get("next_order_in", 0.0),
			1 if snapshot.get("round_over", false) else 0,
			snapshot.get("yaw", 0.0),
			snapshot.get("pitch", 0.0),
			snapshot.get("camera_distance", 3.0),
			snapshot.get("selected_rover", -1),
			snapshot.get("crater_json", "[]"),
			int(Time.get_unix_time_from_system()),
		]
	)
	if not ok:
		_db.query("ROLLBACK;")
		push_error("SaveStore: insert save failed: %s" % _db.error_message)
		return -1
	var save_id: int = _db.last_insert_rowid
	var order_ids: Dictionary = {}
	var orders: Array = snapshot.get("orders", [])
	for i in orders.size():
		var order: Dictionary = orders[i]
		ok = _db.query_with_bindings(
			"""
			INSERT INTO deliveries (
				save_id, lat, lon, created_at, weight, time_left, assigned
			) VALUES (?, ?, ?, ?, ?, ?, ?);
			""",
			[
				save_id,
				order.get("lat", 0.0),
				order.get("lon", 0.0),
				order.get("created_at", 0.0),
				order.get("weight", 1.0),
				order.get("time_left", 0.0),
				1 if order.get("assigned", false) else 0,
			]
		)
		if not ok:
			_db.query("ROLLBACK;")
			push_error("SaveStore: insert delivery failed: %s" % _db.error_message)
			return -1
		order_ids[i] = _db.last_insert_rowid
	var rovers: Array = snapshot.get("rovers", [])
	for rover in rovers:
		var order_local: int = int(rover.get("order_index", -1))
		var delivery_id = order_ids.get(order_local, null)
		ok = _db.query_with_bindings(
			"""
			INSERT INTO rovers (
				save_id, slot, state, lat, lon, order_id,
				max_energy, max_weight, energy, cargo
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
			""",
			[
				save_id,
				rover.get("slot", 0),
				rover.get("state", 0),
				rover.get("lat", 90.0),
				rover.get("lon", 0.0),
				delivery_id,
				rover.get("max_energy", 1),
				rover.get("max_weight", 1),
				rover.get("energy", 1.0),
				rover.get("cargo", 0.0),
			]
		)
		if not ok:
			_db.query("ROLLBACK;")
			push_error("SaveStore: insert rover failed: %s" % _db.error_message)
			return -1
	_db.query("COMMIT;")
	return save_id


func list_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _db == null:
		return result
	if not _db.query(
		"SELECT id, remaining_time, score, gold, created_at FROM saves ORDER BY created_at DESC, id DESC;"
	):
		return result
	for row in _db.query_result:
		result.append(row)
	return result


func load_save(save_id: int) -> Dictionary:
	var empty: Dictionary = {}
	if _db == null:
		return empty
	var rows: Array = _db.select_rows("saves", "id = %d" % save_id, ["*"])
	if rows.is_empty():
		return empty
	var snapshot: Dictionary = rows[0]
	snapshot["round_over"] = int(snapshot.get("round_over", 0)) != 0
	snapshot["orders"] = _db.select_rows("deliveries", "save_id = %d" % save_id, ["*"])
	snapshot["rovers"] = _db.select_rows("rovers", "save_id = %d" % save_id, ["*"])
	return snapshot


func delete_save(save_id: int) -> void:
	if _db == null:
		return
	_db.query_with_bindings("DELETE FROM saves WHERE id = ?;", [save_id])


func _ensure_schema() -> void:
	_db.query(
		"""
		CREATE TABLE IF NOT EXISTS saves (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			remaining_time REAL NOT NULL,
			score INTEGER NOT NULL,
			gold INTEGER NOT NULL,
			difficulty INTEGER NOT NULL,
			next_order_in REAL NOT NULL,
			round_over INTEGER NOT NULL,
			yaw REAL NOT NULL,
			pitch REAL NOT NULL,
			camera_distance REAL NOT NULL,
			selected_rover INTEGER NOT NULL,
			crater_json TEXT NOT NULL,
			created_at INTEGER NOT NULL
		);
		"""
	)
	_db.query(
		"""
		CREATE TABLE IF NOT EXISTS deliveries (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			save_id INTEGER NOT NULL,
			lat REAL NOT NULL,
			lon REAL NOT NULL,
			created_at REAL NOT NULL,
			weight REAL NOT NULL,
			time_left REAL NOT NULL,
			assigned INTEGER NOT NULL,
			FOREIGN KEY (save_id) REFERENCES saves(id) ON DELETE CASCADE
		);
		"""
	)
	_db.query(
		"""
		CREATE TABLE IF NOT EXISTS rovers (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			save_id INTEGER NOT NULL,
			slot INTEGER NOT NULL,
			state INTEGER NOT NULL,
			lat REAL NOT NULL,
			lon REAL NOT NULL,
			order_id INTEGER,
			max_energy INTEGER NOT NULL,
			max_weight INTEGER NOT NULL,
			energy REAL NOT NULL,
			cargo REAL NOT NULL,
			FOREIGN KEY (save_id) REFERENCES saves(id) ON DELETE CASCADE,
			FOREIGN KEY (order_id) REFERENCES deliveries(id) ON DELETE SET NULL
		);
		"""
	)
