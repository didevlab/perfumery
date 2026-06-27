// CRT screen shader for Hyprland (Wayland).
// Set via `decoration:screen_shader = ~/.config/hypr/shaders/crt.frag`.
// NOTE: Hyprland screen shaders apply to the WHOLE screen, not a single window.
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

vec2 curve(vec2 uv)
{
    uv = uv * 2.0 - 1.0;
    uv *= 1.04;
    uv.x *= 1.0 + pow(abs(uv.y) / 4.0, 2.0);
    uv.y *= 1.0 + pow(abs(uv.x) / 3.5, 2.0);
    return uv * 0.5 + 0.5;
}

void main()
{
    vec2 uv  = v_texcoord;
    vec2 cuv = curve(uv);

    if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 col = texture2D(tex, cuv).rgb;

    // Scanlines (uses an approximate 1080p height; tweak the constant per display).
    float scan = sin(cuv.y * 1080.0 * 1.6) * 0.08;
    col -= scan;

    // Vignette.
    float vig = 16.0 * cuv.x * cuv.y * (1.0 - cuv.x) * (1.0 - cuv.y);
    col *= pow(vig, 0.18);

    col *= 1.12;
    gl_FragColor = vec4(col, 1.0);
}
