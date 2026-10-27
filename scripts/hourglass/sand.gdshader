shader_type canvas_item;
// Turns a picture of soft blobs, one per grain, into a mass of sand: a surface
// where the blobs add up past a threshold, lit from the upper left, with fine
// speckle and a darker edge, so the pile looks like sand and not like beads.

uniform sampler2D density : filter_linear, repeat_disable;
uniform vec4 sand : source_color = vec4(0.85, 0.64, 0.25, 1.0);
uniform float threshold = 0.5;
// The shape of the glass: half its width at each height, measured from the top
// centre of the glass, which sits at glass_top in the picture.
uniform sampler2D widths : filter_linear, repeat_disable;
uniform vec2 glass_top;
uniform float glass_height = 1100.0;
uniform vec2 view_size;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(density, 0));
	float d = texture(density, UV).r;
	float surface = smoothstep(threshold - 0.04, threshold + 0.04, d);
	// The slope of the density is the slope of the pile.
	float dx = texture(density, UV + vec2(texel.x * 3.0, 0.0)).r - texture(density, UV - vec2(texel.x * 3.0, 0.0)).r;
	float dy = texture(density, UV + vec2(0.0, texel.y * 3.0)).r - texture(density, UV - vec2(0.0, texel.y * 3.0)).r;
	vec3 normal = normalize(vec3(-dx * 3.0, -dy * 3.0, 1.0));
	float lit = clamp(dot(normal, normalize(vec3(-0.45, -0.65, 0.75))), 0.0, 1.0);
	vec2 pixel = floor(UV / texel / 1.6);
	float speckle = hash(pixel) - 0.5;
	float grain = hash(floor(UV / texel / 4.0)) - 0.5;
	float depth = smoothstep(threshold, threshold + 1.1, d);
	vec3 colour = sand.rgb * (0.84 + 0.40 * lit) * (0.86 + 0.16 * depth);
	colour *= 1.0 + speckle * 0.16 + grain * 0.10;
	colour = mix(colour * 0.78, colour, smoothstep(threshold, threshold + 0.35, d));
	// Nothing is drawn outside the glass.
	vec2 local = UV * view_size - glass_top;
	float half_width = texture(widths, vec2((clamp(local.y, 0.0, glass_height) + 0.5) / (glass_height + 1.0), 0.5)).r;
	float inside = (1.0 - smoothstep(half_width - 1.5, half_width, abs(local.x))) * step(0.0, local.y) * step(local.y, glass_height);
	COLOR = vec4(colour, surface * inside);
}
