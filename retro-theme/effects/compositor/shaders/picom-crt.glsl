#version 330
// CRT window shader for picom (X11 compositor).
// Applies curvature, scanlines, phosphor mask and vignette to a window's content.
// Wire it to terminal windows only via a window-shader rule (see install.sh / README).
//
// picom calls window_shader(); `tex` is the window texture, `texcoord` is in pixels.
in vec2 texcoord;
uniform sampler2D tex;
uniform float opacity;
vec4 default_post_processing(vec4 c);

vec2 curve(vec2 uv)
{
    uv = uv * 2.0 - 1.0;
    uv *= 1.04;
    uv.x *= 1.0 + pow(abs(uv.y) / 4.0, 2.0);
    uv.y *= 1.0 + pow(abs(uv.x) / 3.5, 2.0);
    return uv * 0.5 + 0.5;
}

vec4 window_shader()
{
    vec2 size = vec2(textureSize(tex, 0));
    vec2 uv   = texcoord / size;          // normalize to 0..1
    vec2 cuv  = curve(uv);

    // Outside the curved screen = transparent black (keeps window edges clean).
    if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0)
        return vec4(0.0, 0.0, 0.0, 0.0);

    vec4 c = texture(tex, cuv * size);    // picom samples in pixel space

    // Scanlines.
    float scan = sin(cuv.y * size.y * 1.6) * 0.08;
    c.rgb -= scan;

    // Phosphor column mask.
    float mask = 0.92 + 0.08 * sin(cuv.x * size.x * 3.14159);
    c.rgb *= mask;

    // Vignette.
    float vig = 16.0 * cuv.x * cuv.y * (1.0 - cuv.x) * (1.0 - cuv.y);
    c.rgb *= pow(vig, 0.18);

    c.rgb *= 1.12;
    return c * opacity;
}
