// Neon-glow shader for Windows Terminal (pixelShaderPath).
// Bloom + faint chromatic aberration + soft vignette. No curvature/scanlines.
Texture2D    shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = tex;

    // Faint chromatic aberration.
    float ca = 0.0008;
    float3 col;
    col.r = shaderTexture.Sample(samplerState, float2(uv.x + ca, uv.y)).r;
    col.g = shaderTexture.Sample(samplerState, uv).g;
    col.b = shaderTexture.Sample(samplerState, float2(uv.x - ca, uv.y)).b;

    // Bloom: weighted blur of the surrounding texels -> neon halo.
    float3 bloom = float3(0.0, 0.0, 0.0);
    float  total = 0.0;
    [unroll] for (int x = -3; x <= 3; x++)
    {
        [unroll] for (int y = -3; y <= 3; y++)
        {
            float2 off = float2(x, y) / Resolution * 2.5;
            float  w   = 1.0 / (1.0 + (float)(x * x + y * y));
            bloom += shaderTexture.Sample(samplerState, uv + off).rgb * w;
            total += w;
        }
    }
    bloom /= total;
    col += pow(bloom, float3(1.5, 1.5, 1.5)) * 0.45;

    // Soft vignette.
    float vig = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    col *= pow(vig, 0.10);

    col *= 1.05;
    return float4(col, 1.0);
}
