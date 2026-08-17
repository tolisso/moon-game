class_name Geo
extends RefCounted

## Stateless math helpers for spherical coordinates.
##
## Convention: +Y is the north pole, longitude 0 points at +X and grows towards
## +Z. All returned direction vectors are unit length in planet-local space.

const EPS: float = 0.000001


class SphereHit:
	extends RefCounted

	var hit: bool = false
	var point: Vector3 = Vector3.ZERO


static func unit_from_deg(lat_deg: float, lon_deg: float) -> Vector3:
	var lat: float = deg_to_rad(lat_deg)
	var lon: float = deg_to_rad(lon_deg)
	var ring: float = cos(lat)
	return Vector3(ring * cos(lon), sin(lat), ring * sin(lon))


static func geo_from_unit(unit: Vector3) -> GeoCoord:
	var n: Vector3 = unit.normalized()
	var lat: float = rad_to_deg(asin(clampf(n.y, -1.0, 1.0)))
	var lon: float = rad_to_deg(atan2(n.z, n.x))
	return GeoCoord.new(lat, lon)


## Any unit vector tangent to the sphere at `unit`, used as a fallback where
## the north direction is undefined (exactly on a pole).
static func any_tangent(unit: Vector3) -> Vector3:
	var candidate: Vector3 = Vector3.UP.cross(unit)
	if candidate.length() < EPS:
		candidate = Vector3.RIGHT.cross(unit)
	return candidate.normalized()


static func north_tangent(unit: Vector3) -> Vector3:
	var tangent: Vector3 = Vector3.UP - unit * unit.dot(Vector3.UP)
	if tangent.length() < EPS:
		return any_tangent(unit)
	return tangent.normalized()


## Orthonormal basis whose +Z is the outward normal and whose +Y follows
## `forward` projected onto the tangent plane. Quads face +Z, so a mesh using
## this basis lies flat on the surface.
static func surface_basis(unit: Vector3, forward: Vector3) -> Basis:
	var z: Vector3 = unit.normalized()
	var y: Vector3 = forward - z * z.dot(forward)
	if y.length() < EPS:
		y = north_tangent(z)
	y = y.normalized()
	return Basis(y.cross(z), y, z)


## Rotation axis of the shortest great-circle arc from `a` to `b`.
static func arc_axis(a: Vector3, b: Vector3) -> Vector3:
	var axis: Vector3 = a.cross(b)
	if axis.length() < EPS:
		# Coincident or antipodal points leave the plane undefined, so any
		# perpendicular axis is a valid shortest route.
		axis = any_tangent(a).cross(a)
	return axis.normalized()


static func arc_angle(a: Vector3, b: Vector3) -> float:
	return acos(clampf(a.normalized().dot(b.normalized()), -1.0, 1.0))


## Samples the arc that starts at `from`, rotates around `axis` and spans
## `[start_rad, end_rad]`.
static func arc_points(
	from: Vector3, axis: Vector3, start_rad: float, end_rad: float, samples: int
) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var count: int = maxi(samples, 2)
	points.resize(count)
	for i in count:
		var t: float = float(i) / float(count - 1)
		points[i] = from.rotated(axis, lerpf(start_rad, end_rad, t))
	return points


## Nearest intersection of a ray with a sphere centred at the origin. Only hits
## in front of the ray count, so this naturally picks the visible hemisphere.
static func ray_sphere(origin: Vector3, dir: Vector3, radius: float) -> SphereHit:
	var result: SphereHit = SphereHit.new()
	var d: Vector3 = dir.normalized()
	var b: float = 2.0 * origin.dot(d)
	var c: float = origin.length_squared() - radius * radius
	var discriminant: float = b * b - 4.0 * c
	if discriminant < 0.0:
		return result
	var root: float = sqrt(discriminant)
	var t_near: float = (-b - root) * 0.5
	var t_far: float = (-b + root) * 0.5
	var t: float = t_near if t_near > 0.0 else t_far
	if t <= 0.0:
		return result
	result.hit = true
	result.point = origin + d * t
	return result
