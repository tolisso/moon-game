class_name DeliveryOrder
extends Node3D

## A drop point that appeared somewhere on the planet and waits for cargo.
## Marker size grows with the requested amount, so the map hints at the load
## before the dialog is opened.

const BASE_RADIUS_DEG: float = 2.2
const RADIUS_PER_CARGO_DEG: float = 0.32
const MAX_RADIUS_DEG: float = 9.0
const RING_WIDTH_RATIO: float = 0.01
const CLICK_MARGIN_DEG: float = 2.5
const AREA_OFFSET: float = 1.0016
const RING_OFFSET: float = 1.0026
const DOT_OFFSET: float = 1.0036

var geo: GeoCoord = GeoCoord.new()
var cargo: float = 1.0
var assigned: bool = false

var _radius_deg: float = BASE_RADIUS_DEG
var _pieces: Array[MeshInstance3D] = []
var _colors: Array[Color] = []


func setup(planet_radius: float, place: GeoCoord, required_cargo: float) -> void:
	geo = place.copy()
	cargo = required_cargo
	_radius_deg = minf(BASE_RADIUS_DEG + cargo * RADIUS_PER_CARGO_DEG, MAX_RADIUS_DEG)
	var centre: Vector3 = geo.to_unit()
	_add(
		SphereShapes.cap(centre, _radius_deg, planet_radius, AREA_OFFSET, Color(1.0, 0.6, 0.2, 0.22))
	)
	_add(
		SphereShapes.ring(
			centre,
			_radius_deg,
			planet_radius,
			RING_OFFSET,
			planet_radius * RING_WIDTH_RATIO,
			Color(1.0, 0.72, 0.28, 0.9)
		)
	)
	_add(
		SphereShapes.cap(
			centre, _radius_deg * 0.32, planet_radius, DOT_OFFSET, Color(1.0, 0.85, 0.45, 1.0)
		)
	)


## Angular radius that still counts as a click on this order.
func pick_radius_deg() -> float:
	return _radius_deg + CLICK_MARGIN_DEG


func set_assigned(value: bool) -> void:
	assigned = value
	for i in _pieces.size():
		var color: Color = _colors[i]
		if value:
			color = color.darkened(0.45)
			color.a *= 0.55
		var material: StandardMaterial3D = _pieces[i].material_override as StandardMaterial3D
		material.albedo_color = color


func _add(piece: MeshInstance3D) -> void:
	_pieces.append(piece)
	_colors.append((piece.material_override as StandardMaterial3D).albedo_color)
	add_child(piece)
