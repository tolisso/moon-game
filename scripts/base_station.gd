class_name BaseStation
extends Node3D

## Home base: the only permanent object on the map. Rovers are parked here,
## invisible, until they are dispatched on a delivery.

const PAD_RADIUS_DEG: float = 3.0
const YARD_RADIUS_DEG: float = 7.0
const RING_WIDTH_RATIO: float = 0.012
const YARD_OFFSET: float = 1.0015
const RING_OFFSET: float = 1.0025
const PAD_OFFSET: float = 1.004

var geo: GeoCoord = GeoCoord.new()


## True when a click at `point` counts as clicking the base.
func covers(point: GeoCoord) -> bool:
	return geo.arc_to_deg(point) <= YARD_RADIUS_DEG


func setup(planet_radius: float, place: GeoCoord) -> void:
	geo = place.copy()
	var centre: Vector3 = geo.to_unit()
	var ring_width: float = planet_radius * RING_WIDTH_RATIO
	add_child(
		SphereShapes.cap(
			centre, YARD_RADIUS_DEG, planet_radius, YARD_OFFSET, Color(0.35, 0.85, 1.0, 0.1)
		)
	)
	add_child(
		SphereShapes.ring(
			centre,
			YARD_RADIUS_DEG,
			planet_radius,
			RING_OFFSET,
			ring_width,
			Color(0.45, 0.9, 1.0, 0.65)
		)
	)
	add_child(
		SphereShapes.cap(
			centre, PAD_RADIUS_DEG, planet_radius, PAD_OFFSET, Color(1.0, 0.82, 0.35, 1.0)
		)
	)
