class_name SphereShapes
extends RefCounted

## Builders for flat markers that lie on the planet surface: filled spherical
## caps and rings. Caps are split into radial bands so their triangles stay
## above the sphere instead of cutting a chord through it.

const SEGMENTS: int = 96
const BAND_DEG: float = 2.0


static func unshaded_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func cap(
	centre: Vector3, radius_deg: float, planet_radius: float, offset: float, color: Color
) -> MeshInstance3D:
	var bands: int = maxi(int(ceil(radius_deg / BAND_DEG)), 1)
	var mesh: ImmediateMesh = ImmediateMesh.new()
	for band in bands:
		var inner: PackedVector3Array = circle_points(
			centre, radius_deg * float(band) / float(bands)
		)
		var outer: PackedVector3Array = circle_points(
			centre, radius_deg * float(band + 1) / float(bands)
		)
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in SEGMENTS + 1:
			var index: int = i % SEGMENTS
			mesh.surface_add_vertex(inner[index] * planet_radius * offset)
			mesh.surface_add_vertex(outer[index] * planet_radius * offset)
		mesh.surface_end()
	return _instance(mesh, color)


static func ring(
	centre: Vector3,
	radius_deg: float,
	planet_radius: float,
	offset: float,
	width: float,
	color: Color
) -> MeshInstance3D:
	var u: Vector3 = Geo.any_tangent(centre)
	var v: Vector3 = centre.cross(u)
	var radius: float = deg_to_rad(radius_deg)
	var half_width: float = width * 0.5
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var angle: float = TAU * float(i % SEGMENTS) / float(SEGMENTS)
		var radial: Vector3 = u * cos(angle) + v * sin(angle)
		var point: Vector3 = centre * cos(radius) + radial * sin(radius)
		# Tangent to the sphere, pointing away from the centre of the ring.
		var outward: Vector3 = radial * cos(radius) - centre * sin(radius)
		var seam: Vector3 = point * planet_radius * offset
		mesh.surface_add_vertex(seam + outward * half_width)
		mesh.surface_add_vertex(seam - outward * half_width)
	mesh.surface_end()
	return _instance(mesh, color)


static func circle_points(centre: Vector3, radius_deg: float) -> PackedVector3Array:
	var u: Vector3 = Geo.any_tangent(centre)
	var v: Vector3 = centre.cross(u)
	var radius: float = deg_to_rad(radius_deg)
	var along_axis: float = cos(radius)
	var along_plane: float = sin(radius)
	var points: PackedVector3Array = PackedVector3Array()
	points.resize(SEGMENTS)
	for i in SEGMENTS:
		var angle: float = TAU * float(i) / float(SEGMENTS)
		points[i] = centre * along_axis + (u * cos(angle) + v * sin(angle)) * along_plane
	return points


static func _instance(mesh: ImmediateMesh, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = unshaded_material(color)
	return instance
