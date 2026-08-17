class_name Graticule
extends MeshInstance3D

## Lat/lon grid drawn on the planet. Without it a plain sphere looks static
## while rotating.

const STEP_DEG: float = 30.0
const SEGMENTS: int = 72
const OFFSET: float = 1.001


func build(planet_radius: float) -> void:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.9, 1.0, 0.22)

	var lines: ImmediateMesh = ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES, material)

	var meridians: int = int(360.0 / STEP_DEG)
	for m in meridians:
		var lon: float = float(m) * STEP_DEG
		for s in SEGMENTS:
			var lat_a: float = lerpf(-90.0, 90.0, float(s) / float(SEGMENTS))
			var lat_b: float = lerpf(-90.0, 90.0, float(s + 1) / float(SEGMENTS))
			lines.surface_add_vertex(Geo.unit_from_deg(lat_a, lon) * planet_radius * OFFSET)
			lines.surface_add_vertex(Geo.unit_from_deg(lat_b, lon) * planet_radius * OFFSET)

	var parallels: int = int(180.0 / STEP_DEG) - 1
	for p in parallels:
		var lat: float = -90.0 + float(p + 1) * STEP_DEG
		for s in SEGMENTS:
			var lon_a: float = 360.0 * float(s) / float(SEGMENTS)
			var lon_b: float = 360.0 * float(s + 1) / float(SEGMENTS)
			lines.surface_add_vertex(Geo.unit_from_deg(lat, lon_a) * planet_radius * OFFSET)
			lines.surface_add_vertex(Geo.unit_from_deg(lat, lon_b) * planet_radius * OFFSET)

	lines.surface_end()
	mesh = lines
