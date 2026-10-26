shader_type canvas_item;
// The glass of the hourglass. Each bulb is treated as a round, hollow glass
// shape seen from the front, so every pixel has a surface direction. From that
// it works out what a glass surface does: it reflects more of the room towards
// the edges (Fresnel), it looks thicker and a little green there, and it throws
// back the bright shapes of a window and the dark of the floor. The middle is
// almost clear, so the sand shows through.

uniform sampler2D widths : filter_linear, repeat_disable;
uniform vec2 origin;
uniform vec2 rect_size;
uniform float glass_height = 1100.0;

// Half the width of the glass at a height (x) and how fast it is changing (y).
vec2 glass_at(float y) {
	float at = (clamp(y, 0.0, glass_height) + 0.5) / (glass_height + 1.0);
	return texture(widths, vec2(at, 0.5)).rg;
}

// A small room: pale sky above, a dark floor below, a big soft window up on the
// left, and a smaller light on the right. y points down the screen.
vec3 room(vec3 r) {
	float up = -r.y;
	vec3 sky = mix(vec3(0.62, 0.55, 0.46), vec3(1.0, 0.94, 0.82), smoothstep(-0.35, 0.9, up));
	vec3 colour = mix(vec3(0.34, 0.25, 0.17), sky, smoothstep(-0.55, -0.12, up));
	float window = 1.0 - smoothstep(0.10, 0.26, length((r.xy - vec2(-0.46, -0.40)) * vec2(1.0, 0.5)));
	float lamp = 1.0 - smoothstep(0.06, 0.15, length((r.xy - vec2(0.52, -0.06)) * vec2(1.0, 0.4)));
	return colour + vec3(window * 1.3 + lamp * 0.7);
}

void fragment() {
	vec2 local = UV * rect_size + origin;
	vec2 shape = glass_at(local.y);
	float hw = shape.x;
	float s = local.x / max(hw, 1.0);
	if (abs(s) >= 1.0) {
		COLOR = vec4(0.0);
	} else {
		float slope = shape.y;
		vec3 n = normalize(vec3(s, -slope, sqrt(max(1.0 - s * s, 0.0001))));
		vec3 reflected = reflect(vec3(0.0, 0.0, -1.0), n);
		float facing = n.z;
		float fresnel = 0.04 + 0.96 * pow(1.0 - facing, 4.0);
		float thick = 1.0 - facing;
		float tint_alpha = 0.015 + 0.20 * pow(thick, 1.7);
		vec3 tint = vec3(0.74, 0.88, 0.88);
		float sparkle = pow(max(dot(reflected, normalize(vec3(-0.5, -0.6, 0.62))), 0.0), 150.0);
		vec3 mirrored = room(reflected) * fresnel * 0.95;
		// The inner wall of the glass: a faint bright line a little inside the edge.
		float wall = smoothstep(0.80, 0.86, abs(s)) * (1.0 - smoothstep(0.88, 0.94, abs(s)));
		float alpha = clamp(fresnel * 0.95 + tint_alpha + sparkle + wall * 0.14, 0.0, 0.96);
		vec3 colour = (mirrored + tint * tint_alpha + vec3(sparkle) + vec3(wall * 0.16)) / max(alpha, 0.001);
		alpha *= 1.0 - smoothstep(0.972, 1.0, abs(s));
		COLOR = vec4(colour, alpha);
	}
}
