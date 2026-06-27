// CRT shader for Windows Terminal (set via profiles.defaults.experimental.pixelShaderPath).
// Curvature, scanlines, phosphor mask, vignette, chromatic aberration, slight glow.
Texture2D    shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

// Barrel curvature of the virtual CRT screen.
float2 curve(float2 uv)
{
    uv = (uv - 0.5) * 2.0;
    uv *= 1.04;
    uv.x *= 1.0 + pow(abs(uv.y) / 4.0, 2.0);
    uv.y *= 1.0 + pow(abs(uv.x) / 3.5, 2.0);
    uv = (uv / 2.0) + 0.5;
    return uv;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = curve(tex);

    // Outside the curved screen = black (the tube bezel).
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return float4(0.0, 0.0, 0.0, 1.0);

    // Chromatic aberration toward the edges.
    float ca = 0.0012;
    float3 col;
    col.r = shaderTexture.Sample(samplerState, float2(uv.x + ca, uv.y)).r;
    col.g = shaderTexture.Sample(samplerState, uv).g;
    col.b = shaderTexture.Sample(samplerState, float2(uv.x - ca, uv.y)).b;

    // Scanlines.
    float scan = sin(uv.y * Resolution.y * 1.6) * 0.08;
    col -= scan;

    // Phosphor column mask.
    float mask = 0.92 + 0.08 * sin(uv.x * Resolution.x * 3.14159);
    col *= mask;

    // Vignette.
    float vig = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    col *= pow(vig, 0.18);

    // Overall brightness lift.
    col *= 1.12;

    return float4(col, 1.0);
}
