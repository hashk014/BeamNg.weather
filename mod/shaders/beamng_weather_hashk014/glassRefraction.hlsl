// Original surface-bead lens shader. Uses the installed game's draw ABI;
// no engine shader source or frame images are bundled with the mod.
#define SHADERGEN_CUSTOM_MATERIAL_CBUFFER
#define MFT_MATERIAL_LAYER_COUNT 1
#include "shaders/common/material/shadergen/shadergen.h.hlsl"
#if defined(MFT_Bindless)
#include "shaders/common/material/shadergen/bindlessArena.h.hlsl"
#else
cspPrimitiveBuffer_t getPrimData() { return cspPrimBuffer; }
#endif
MaterialUniforms getMaterialData() { return (MaterialUniforms)0; }
#include "shaders/common/material/shadergen/materialDrawId.h.hlsl"

Texture2D sceneColor : REGISTER(t0, materialSpace);
SamplerState sceneColorSampler : REGISTER(s0, materialSpace);
cbuffer cspMaterial : REGISTER(b4, materialSpace) { float refractionStrength; };

struct BeadPixel {
    float4 position : SV_POSITION;
    float2 atlas : TEXCOORD0;
    float4 projected : TEXCOORD1;
};

BeadPixel mainV(vertexIARAW raw, svInstanceData instance, uint vertexID : SV_VertexID) {
    BeadPixel o;
    uint2 ids = getInstanceMeshId(instance);
    VertexIa v = getVertexIA(raw, vertexID);
    float4x4 world = getInstanceTransform(ids.x);
    // Subtract the split camera origin before projecting to retain precision.
    world = subMatrixPosition(subMatrixPosition(world, eyePosWorld), cameraRemainder);
    float4 camera = mul(worldToCameraPos0, mul(world, mul(getPrimData().localTrans, float4(v.pos, 1))));
    o.position = mul(cameraToScreen, camera);
    o.projected = o.position;
    o.atlas = v.texCoords.xy;
    return o;
}

float4 mainP(BeadPixel p) : SV_Target0 {
    float2 lens = frac(p.atlas * 4.0) * 2.0 - 1.0;
    float r2 = dot(lens, lens);
    clip(0.92 - r2);
    float2 screen = p.projected.xy / p.projected.w * float2(0.5, -0.5) + 0.5;
    float dome = sqrt(saturate(1.0 - r2));
    // Convert a radial displacement within the bead to screen pixels. This
    // ties refraction to its projected size and rotates it with the window.
    float2 dx = ddx(lens), dy = ddy(lens);
    float determinant = dx.x * dy.y - dx.y * dy.x;
    float2 desired = -lens * dome * 0.55 * refractionStrength;
    float2 pixels = abs(determinant) > 1e-8
        ? float2(desired.x * dy.y - desired.y * dy.x, dx.x * desired.y - dx.y * desired.x) / determinant
        : float2(0, 0);
    pixels = clamp(pixels, -32.0, 32.0);
    // Screen UV derivatives also work when the refraction buffer is downscaled.
    float2 offset = ddx(screen) * pixels.x + ddy(screen) * pixels.y;
    float3 refracted = sceneColor.Sample(sceneColorSampler, saturate(screen + offset)).rgb;
    float rim = pow(saturate(r2), 5.0);
    float highlight = exp(-dot(lens + float2(0.32, 0.38), lens + float2(0.32, 0.38)) * 90.0);
    float age = floor(p.atlas.x * 4.0) + floor(p.atlas.y * 4.0) * 4.0;
    float fade = saturate((16.0 - age) / 4.0);
    float mask = smoothstep(0.92, 0.72, r2) * fade;
    return float4(refracted * (1.0 - rim * 0.16) + highlight * 0.18, mask * 0.94);
}
