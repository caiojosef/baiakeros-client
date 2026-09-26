uniform float u_Time;
uniform sampler2D u_Tex0;
varying vec2 v_TexCoord;

void main()
{
    vec4 col = texture2D(u_Tex0, v_TexCoord);
    if (col.a > 0.5) {
        gl_FragColor = col;
        return;
    }

    vec2 stepSize = vec2(1.0 / 64.0);
    float inner =
        texture2D(u_Tex0, v_TexCoord + vec2( stepSize.x, 0.0)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(-stepSize.x, 0.0)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(0.0,  stepSize.y)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(0.0, -stepSize.y)).a;
    float outer =
        texture2D(u_Tex0, v_TexCoord + vec2( stepSize.x,  stepSize.y)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(-stepSize.x,  stepSize.y)).a +
        texture2D(u_Tex0, v_TexCoord + vec2( stepSize.x, -stepSize.y)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(-stepSize.x, -stepSize.y)).a;
    float aura = clamp(inner * 0.19 + outer * 0.12, 0.0, 1.0);
    if (aura > 0.01) {
        float pulse = 0.65 + 0.14 * sin(u_Time * 2.0);
        gl_FragColor = vec4(0.96, 0.28, 0.46, aura * pulse);
    } else {
        gl_FragColor = col;
    }
}