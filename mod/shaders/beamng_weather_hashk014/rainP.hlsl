// Original rain texture sampling; straight alpha matches native rain blending.
Texture2D diffuseMap : register(t0);
SamplerState diffuseMapSampler : register(s0);
struct PixelInput
{
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 color : COLOR0;
    float nearMask : TEXCOORD1;
};
float4 main(PixelInput input) : SV_Target0
{
    clip(input.nearMask);
    return diffuseMap.Sample(diffuseMapSampler, input.uv) * input.color;
}
