#version 450
layout(location = 0) out vec2 uv;
layout(push_constant) uniform Push {
    vec4 tint;
    float offset;
} pc;

void main() {
    vec2 positions[3] = vec2[](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));
    vec2 position = positions[gl_VertexIndex];
    uv = position * 0.5 + 0.5;
    gl_Position = vec4(position.x + pc.offset, position.y, 0.0, 1.0);
}
