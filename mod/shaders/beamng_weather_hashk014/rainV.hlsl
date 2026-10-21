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
};
VertexOutput main(VertexInput input)
{
    VertexOutput output;
    output.position = mul(modelview, float4(input.position, 1.0));
    output.uv = input.uv;
    float fade = 1.0;
    if (fadeStartEnd.y > fadeStartEnd.x)
        fade = 1.0 - saturate((distance(cameraPos, input.position) - fadeStartEnd.x) / (fadeStartEnd.y - fadeStartEnd.x));
    output.color = float4(max(ambient, 0.0), fade);
    return output;
}
