class_name RangeView
extends Node3D

## Two range rings around the base: current energy and a full battery.
## A ring of 180° would collapse to the opposite pole, so radii are clamped.

const RING_OFFSET: float = 1.003
const RING_WIDTH_RATIO: float = 0.01
const MAX_VISIBLE_DEG: float = 179.0
const MIN_VISIBLE_DEG: float = 1.5

var _planet_radius: float = 1.0
var _current_ring: MeshInstance3D = null
var _max_ring: MeshInstance3D = null
var _shown_current: float = -1.0
var _shown_max: float = -1.0


func setup(planet_radius: float) -> void:
	_planet_radius = planet_radius
	_max_ring = MeshInstance3D.new()
	_current_ring = MeshInstance3D.new()
	add_child(_max_ring)
	add_child(_current_ring)
	visible = false


func hide_ranges() -> void:
	visible = false
	_shown_current = -1.0
	_shown_max = -1.0


func show_ranges(centre: GeoCoord, current_deg: float, max_deg: float, show_current: bool) -> void:
	visible = true
	var current_draw: float = current_deg if show_current else -1.0
	if is_equal_approx(current_draw, _shown_current) and is_equal_approx(max_deg, _shown_max):
		return
	_shown_current = current_draw
	_shown_max = max_deg
	_set_ring(
		_max_ring, centre, max_deg, Color(0.35, 0.7, 1.0, 0.35), _planet_radius * RING_WIDTH_RATIO
	)
	_set_ring(
		_current_ring,
		centre,
		current_draw,
		Color(0.85, 0.95, 1.0, 0.85),
		_planet_radius * RING_WIDTH_RATIO * 1.35
	)


func _set_ring(
	ring: MeshInstance3D, centre: GeoCoord, radius_deg: float, color: Color, width: float
) -> void:
	if radius_deg < MIN_VISIBLE_DEG or radius_deg > MAX_VISIBLE_DEG:
		ring.visible = false
		return
	ring.visible = true
	ring.mesh = null
	var built: MeshInstance3D = SphereShapes.ring(
		centre.to_unit(), radius_deg, _planet_radius, RING_OFFSET, width, color
	)
	ring.mesh = built.mesh
	ring.material_override = built.material_override
	built.queue_free()
