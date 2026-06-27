// Retro CRT shader for Ghostty (Shadertoy-compatible)
// Effects: screen curvature, scanlines, vignette and a subtle phosphor glow.
// iChannel0 = terminal contents | iResolution | iTime

// CRT "screen" curvature
vec2 curve(vec2 uv) {
    uv = (uv - 0.5) * 2.0;
    uv *= 1.05;
    uv.x *= 1.0 + pow(abs(uv.y) / 4.0, 2.0);
    uv.y *= 1.0 + pow(abs(uv.x) / 3.5, 2.0);
    uv = (uv / 2.0) + 0.5;
    return uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec2 cuv = curve(uv);

    // outside the curved screen = black (tube borders)
    if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 col = texture(iChannel0, cuv).rgb;

    // subtle chromatic aberration at the edges
    float ca = 0.0012;
    col.r = texture(iChannel0, cuv + vec2(ca, 0.0)).r;
    col.b = texture(iChannel0, cuv - vec2(ca, 0.0)).b;

    // scanlines
    float scan = sin(cuv.y * iResolution.y * 1.6) * 0.08;
    col -= scan;

    // phosphor mask (columns)
    float mask = 0.92 + 0.08 * sin(cuv.x * iResolution.x * 3.14159);
    col *= mask;

    // vignette
    float vig = 16.0 * cuv.x * cuv.y * (1.0 - cuv.x) * (1.0 - cuv.y);
    col *= pow(vig, 0.18);

    // overall brightness/glow
    col *= 1.12;

    fragColor = vec4(col, 1.0);
}
