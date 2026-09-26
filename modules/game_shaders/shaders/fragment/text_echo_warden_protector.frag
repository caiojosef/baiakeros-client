uniform sampler2D u_Tex0;
uniform vec4 u_Color;
varying vec2 v_TexCoord;

void main()
{
    vec4 base = texture2D(u_Tex0, v_TexCoord);
    if (base.a > 0.1) {
        gl_FragColor = vec4(base.rgb * u_Color.rgb, base.a);
        return;
    }

    vec2 texel = vec2(1.0 / 512.0);
    float inner = 0.0;
    float outer = 0.0;
    for (float angle = 0.0; angle < 6.28318; angle += 0.785398) {
        vec2 direction = vec2(cos(angle), sin(angle)) * texel;
        inner += texture2D(u_Tex0, v_TexCoord + direction * 0.8).a;
        outer += texture2D(u_Tex0, v_TexCoord + direction * 1.8).a;
    }
    float smoke = clamp(inner * 0.085 + outer * 0.035, 0.0, 0.7);
    if (smoke > 0.02) {
        gl_FragColor = vec4(0.93, 0.31, 0.48, smoke);
    } else {
        discard;
    }
}