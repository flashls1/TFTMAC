#version 450
layout(set = 0, binding = 0) uniform sampler2D sourceTexture;
layout(location = 0) in vec2 uv;
layout(location = 0) out vec4 color;
layout(push_constant) uniform Push {
    vec4 tint;
    float offset;
} pc;

void main() {
    vec2 wrapped = fract(uv * 8.0 + vec2(pc.offset * 2.0, 0.0));
    color = texture(sourceTexture, wrapped) * pc.tint;
}
