class_name GeoCoord
extends RefCounted

## A point on the planet surface: latitude and longitude in degrees.
##
## Any input values are accepted (including the 0..360 range for latitude).
## They are folded into canonical storage: latitude in [-90, 90], longitude in
## [0, 360). Walking past a pole flips the hemisphere and shifts longitude by
## 180 degrees, which is what actually happens on a sphere.

var lat_deg: float = 0.0
var lon_deg: float = 0.0


func _init(lat: float = 0.0, lon: float = 0.0) -> void:
	set_deg(lat, lon)


func set_deg(lat: float, lon: float) -> void:
	var folded_lat: float = fposmod(lat + 90.0, 360.0) - 90.0
	var folded_lon: float = lon
	if folded_lat > 90.0:
		folded_lat = 180.0 - folded_lat
		folded_lon += 180.0
	lat_deg = folded_lat
	lon_deg = fposmod(folded_lon, 360.0)


func copy() -> GeoCoord:
	return GeoCoord.new(lat_deg, lon_deg)


func to_unit() -> Vector3:
	return Geo.unit_from_deg(lat_deg, lon_deg)


## Angular distance to another point, in degrees (0..180).
func arc_to_deg(other: GeoCoord) -> float:
	return rad_to_deg(Geo.arc_angle(to_unit(), other.to_unit()))


func _to_string() -> String:
	return "%.1f°, %.1f°" % [lat_deg, lon_deg]
