
extends RefCounted
class_name IndustrialMaterials


# ============================================================
# PROCEDURAL INDUSTRIAL PBR MATERIAL
# ============================================================

static func make_surface(
	base_color: Color,
	metallic: float,
	roughness: float,
	seed_value: int,
	bump_strength: float = 0.12
) -> StandardMaterial3D:

	var noise := FastNoiseLite.new()

	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.55

	# Procedural normal map.
	var normal_map := NoiseTexture2D.new()

	normal_map.width = 256
	normal_map.height = 256
	normal_map.seamless = true
	normal_map.as_normal_map = true
	normal_map.bump_strength = bump_strength
	normal_map.noise = noise

	# Procedural roughness map.
	var roughness_map := NoiseTexture2D.new()

	roughness_map.width = 256
	roughness_map.height = 256
	roughness_map.seamless = true
	roughness_map.noise = noise

	# Configure PBR material.
	var material := StandardMaterial3D.new()

	material.albedo_color = base_color
	material.metallic = metallic
	material.roughness = roughness

	material.normal_enabled = true
	material.normal_texture = normal_map
	material.normal_scale = 0.15

	material.roughness_texture = roughness_map
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	return material


# ============================================================
# EMISSIVE MATERIAL
# ============================================================

static func make_emissive(
	base_color: Color,
	emission_color: Color,
	energy: float = 2.0
) -> StandardMaterial3D:

	var material := StandardMaterial3D.new()

	material.albedo_color = base_color
	material.metallic = 0.55
	material.roughness = 0.3

	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy

	return material


# ============================================================
# BLACK HOLE ACCRETION DISK SHADER
# ============================================================

static func make_black_hole_material() -> ShaderMaterial:

	var shader := Shader.new()

	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	vec2 p = UV - vec2(0.5);

	float r = length(p);
	float a = atan(p.y, p.x);

	float swirl = sin(a * 13.0 + r * 65.0 - TIME * 2.8);
	float bands = sin(r * 100.0 - TIME * 5.0);

	vec3 inner = vec3(0.005, 0.008, 0.025);
	vec3 orange = vec3(1.0, 0.19, 0.025);
	vec3 cyan = vec3(0.025, 0.22, 0.55);

	float ring = smoothstep(0.44, 0.25, r)
		* smoothstep(0.10, 0.19, r);

	vec3 color = mix(inner, orange, ring);

	color += cyan * max(swirl, 0.0) * ring * 0.35;
	color += orange * max(bands, 0.0) * ring * 0.2;

	ALBEDO = color;
	EMISSION = color * 2.0;
}
"""

	var material := ShaderMaterial.new()

	material.shader = shader

	return material
