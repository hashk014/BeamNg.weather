// Original precipitation shader for modern Direct3D/Vulkan compilation.
// Constant names match the native Precipitation renderer's bindings.
cbuffer perDraw : register(b0)
{
    float4x4 modelview;
    float2 fadeStartEnd;
    float3 cameraPos;
    float3 ambient;
};
struct VertexInput
{
    float3 position : POSITION;
    float2 uv : TEXCOORD0;
};
struct VertexOutput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 color : COLOR0;
    float nearMask : TEXCOORD1;
};
VertexOutput main(VertexInput input)
{
    VertexOutput output;
    output.position = mul(modelview, float4(input.position, 1.0));
    output.uv = input.uv;
    float cameraDistance = distance(cameraPos, input.position);
    float guardRadius = max(0.0, -fadeStartEnd.x);
    output.nearMask = guardRadius > 0.0 ? cameraDistance - guardRadius : 1.0;
    float fadeStart = guardRadius > 0.0 ? fadeStartEnd.y * 0.55 : fadeStartEnd.x;
    float fade = 1.0;
    if (fadeStartEnd.y > fadeStart)
        fade = 1.0 - saturate((cameraDistance - fadeStart) / (fadeStartEnd.y - fadeStart));
    output.color = float4(max(ambient, 0.0), fade);
    return output;
}
