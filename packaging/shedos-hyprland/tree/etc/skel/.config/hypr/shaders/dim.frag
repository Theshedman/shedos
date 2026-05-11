#version 300 es
precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 c = texture(tex, v_texcoord);
    fragColor = vec4(c.rgb * 0.1, c.a);
}
