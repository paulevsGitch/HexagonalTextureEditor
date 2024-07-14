shader_type spatial;

render_mode unshaded;

uniform sampler2D sourceImage: source_color, filter_linear, repeat_enable, hint_default_transparent;
uniform int imageMode = 0;
uniform int pixelMode = 0;
uniform int gradientMode = 0;
uniform float gradientPower = 3.0;
uniform int solidValue = 1;
uniform int blendValue = 0;

const float sqrt3 = 1.0 / sqrt(3.0);
const float angle30 = 30.0 / 180.0 * PI;
const float angle90 = PI * 0.5;
const float widthOffset = (1.0 - 3.0 / (2.0 * sqrt(3.0))) * 0.5;

void applyGradient(inout vec4 color, vec2 uv) {
	float grad = abs(uv.y - 0.5) * 2.0;
	if (gradientMode == 0) {
		grad = max(grad * 1.5 - 0.5, 0.0);
		grad = pow(grad, gradientPower);
	}
	else {
		float y2 = pow(1.0 - grad, 2.0);
		float x2 = pow((uv.x * 2.0 - 1.0) * 0.3, 2.0);
		grad = sqrt(y2 + x2) * 1.1 - 0.1;
		grad = pow(1.0 - min(grad, 1.0), gradientPower);
	}
	color.a = clamp(color.a * grad, 0.0, 1.0);
}

void applySolid(inout vec4 color, vec2 uv) {
	ivec2 size = textureSize(sourceImage, 0);
	float solidScale = float(solidValue) / float(size.x);
	float blendScale = float(blendValue) / float(size.x);
	float grad = 0.5 - abs(uv.y - 0.5);
	if (grad > solidScale) {
		if (blendValue < 1) color.a = 0.0;
		else {
			grad = (grad - solidScale) / blendScale;
			grad = 1.0 - min(grad, 1.0);
			color.a *= grad;
		}
	}
}

void applyTriangle(inout vec4 color, vec2 uv) {
	float grad = abs(uv.y - 0.5) * sqrt3;
	if (uv.x <= 0.5 - grad) color.a *= 0.0;
	else if (uv.x >= 0.5 + grad) color.a *= 0.0;
}

vec2 rotate(vec2 pos, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(c * pos.x - s * pos.y, s * pos.x + c * pos.y);
}

vec4 sampleImage(sampler2D image, vec2 uv) {
	if (pixelMode != 1) uv = clamp(uv, 0.0, 1.0);
	return texture(image, uv);
}

void processSide(inout vec4 color, float angle, vec2 uv) {
	uv = rotate(uv - 0.5, angle) + 0.5;
	vec2 origUV = uv;
	if (uv.y < 0.5) uv.y -= widthOffset;
	else uv.y += widthOffset;
	
	vec4 side = sampleImage(sourceImage, uv);
	
	if (imageMode == 0) applyGradient(side, uv);
	else applySolid(side, uv);
	
	applyTriangle(side, origUV);
	
	if (pixelMode == 2 && (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)) {
		side.a = 0.0;
	}
	
	color.rgb = mix(color.rgb, side.rgb, side.a);
	color.a = max(color.a, side.a);
}

void fragment() {
	vec4 color = texture(sourceImage, UV);
	processSide(color, angle30, UV);
	processSide(color, -angle30, UV);
	processSide(color, angle90, UV);
	ALBEDO = color.rgb;
	ALPHA = color.a;
}