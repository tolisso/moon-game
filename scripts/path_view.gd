class_name PathView
extends Node3D

## Draws the remaining route of a rover as a flat ribbon lying on the surface,
## plus a diamond marker at the destination. Both sit just above the sphere, so
## the sphere itself clips whatever is behind the horizon.

const RIBBON_OFFSET: float = 1.002
const RIBBON_WIDTH_RATIO: float = 0.014
const MARKER_SIZE_RATIO: float = 0.05

var _planet_radius: float = 1.0
var _half_width: float = 0.01
var _mesh: ImmediateMesh = null
var _material: StandardMaterial3D = null
var _line: MeshInstance3D = null
var _marker: MeshInstance3D = null


func setup(planet_radius: float, color: Color) -> void:
	_planet_radius = planet_radius
	_half_width = planet_radius * RIBBON_WIDTH_RATIO * 0.5

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(color.r, color.g, color.b, 0.65)

	_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _mesh
	add_child(_line)

	var marker_quad: QuadMesh = QuadMesh.new()
	var marker_size: float = planet_radius * MARKER_SIZE_RATIO
	marker_quad.size = Vector2(marker_size, marker_size)
	_marker = MeshInstance3D.new()
	_marker.mesh = marker_quad
	_marker.material_override = _material
	add_child(_marker)

	visible = false


func refresh(points: PackedVector3Array) -> void:
	_mesh.clear_surfaces()
	if points.size() < 2:
		visible = false
		return
	visible = true
	_build_ribbon(points)
	_place_marker(points[points.size() - 1])


func _build_ribbon(points: PackedVector3Array) -> void:
	var count: int = points.size()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
	for i in count:
		var unit: Vector3 = points[i]
		var previous: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, count - 1)]
		var along: Vector3 = next - previous
		along -= unit * unit.dot(along)
		if along.length() < Geo.EPS:
			along = Geo.north_tangent(unit)
		var side: Vector3 = unit.cross(along.normalized()) * _half_width
		var centre: Vector3 = unit * _planet_radius * RIBBON_OFFSET
		_mesh.surface_add_vertex(centre + side)
		_mesh.surface_add_vertex(centre - side)
	_mesh.surface_end()


func _place_marker(unit: Vector3) -> void:
	var basis_on_surface: Basis = Geo.surface_basis(unit, Geo.north_tangent(unit))
	_marker.transform = Transform3D(
		basis_on_surface * Basis(Vector3(0.0, 0.0, 1.0), PI * 0.25),
		unit * _planet_radius * RIBBON_OFFSET
	)
