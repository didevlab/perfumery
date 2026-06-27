// Futuristic glow for Ghostty (Shadertoy-compatible)
// No curvature, no scanlines. Neon bloom + subtle aberration + soft vignette.
// iChannel0 = terminal contents | iResolution | iTime

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    vec3 col = texture(iChannel0, uv).rgb;

    // subtle chromatic aberration
    float ca = 0.0008;
    col.r = texture(iChannel0, uv + vec2(ca, 0.0)).r;
    col.b = texture(iChannel0, uv - vec2(ca, 0.0)).b;

    // bloom: sum of blurred samples around the pixel (neon glow)
    vec3 bloom = vec3(0.0);
    float total = 0.0;
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            vec2 off = vec2(float(x), float(y)) / iResolution.xy * 2.5;
            float w = 1.0 / (1.0 + float(x*x + y*y));
            bloom += texture(iChannel0, uv + off).rgb * w;
            total += w;
        }
    }
    bloom /= total;
    // add only the bright part -> neon halo
    col += pow(bloom, vec3(1.5)) * 0.45;

    // soft vignette
    float vig = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    col *= pow(vig, 0.10);

    col *= 1.05;

    fragColor = vec4(col, 1.0);
}
