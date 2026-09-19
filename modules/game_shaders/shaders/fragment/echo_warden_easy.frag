const float offset = 1.0 / 64.0;
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

    float aura =
        texture2D(u_Tex0, v_TexCoord + vec2( offset,  0.0)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(-offset,  0.0)).a +
        texture2D(u_Tex0, v_TexCoord + vec2( 0.0,  offset)).a +
        texture2D(u_Tex0, v_TexCoord + vec2( 0.0, -offset)).a +
        texture2D(u_Tex0, v_TexCoord + vec2( offset,  offset)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(-offset,  offset)).a +
        texture2D(u_Tex0, v_TexCoord + vec2( offset, -offset)).a +
        texture2D(u_Tex0, v_TexCoord + vec2(-offset, -offset)).a;

    if (aura > 0.0) {
        float pulse = 0.68 + 0.27 * ((sin(u_Time * 7.0) + 1.0) * 0.5);
        gl_FragColor = vec4(1.00, 0.30, 0.52, pulse);
    } else {
        gl_FragColor = col;
    }
}
