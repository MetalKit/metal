
#include <metal_stdlib>
using namespace metal;

typedef struct {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
} ImageVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageColorInOut;

typedef struct {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float3 ambientLightColor;
    float3 directionalLightDirection;
    float3 directionalLightColor;
    float materialShininess;
} SharedUniforms;

typedef struct {
    float4x4 modelMatrix;
} InstanceUniforms;

vertex ImageColorInOut capturedImageVertexTransform(ImageVertex in [[stage_in]]) {
    ImageColorInOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 capturedImageFragmentShader(ImageColorInOut in [[stage_in]],
                                            texture2d<float, access::sample> textureY [[ texture(1) ]],
                                            texture2d<float, access::sample> textureCbCr [[ texture(2) ]]) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);
    const float4x4 ycbcrToRGBTransform = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                                  float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                                  float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                                  float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));
    float4 ycbcr = float4(textureY.sample(colorSampler, in.texCoord).r, textureCbCr.sample(colorSampler, in.texCoord).rg, 1.0);
    return ycbcrToRGBTransform * ycbcr;
}

typedef struct {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    half3 normal    [[attribute(2)]];
} Vertex;

typedef struct {
    float4 position [[position]];
    float4 color;
    half3  eyePosition;
    half3  normal;
} ColorInOut;

vertex ColorInOut anchorGeometryVertexTransform(Vertex in [[stage_in]],
                                                constant SharedUniforms &sharedUniforms [[ buffer(3) ]],
                                                constant InstanceUniforms *instanceUniforms [[ buffer(2) ]],
                                                ushort vid [[vertex_id]],
                                                ushort iid [[instance_id]]) {
    ColorInOut out;
    float4 position = float4(in.position, 1.0);
    float4x4 modelMatrix = instanceUniforms[iid].modelMatrix;
    float4x4 modelViewMatrix = sharedUniforms.viewMatrix * modelMatrix;
    out.position = sharedUniforms.projectionMatrix * modelViewMatrix * position;
    ushort colorID = vid / 4 % 6;
    out.color = colorID == 0 ? float4(0.0, 1.0, 0.0, 1.0)  // Right face
              : colorID == 1 ? float4(1.0, 0.0, 0.0, 1.0)  // Left face
              : colorID == 2 ? float4(0.0, 0.0, 1.0, 1.0)  // Top face
              : colorID == 3 ? float4(1.0, 0.5, 0.0, 1.0)  // Bottom face
              : colorID == 4 ? float4(1.0, 1.0, 0.0, 1.0)  // Back face
              :                float4(1.0, 1.0, 1.0, 1.0); // Front face
    out.eyePosition = half3((modelViewMatrix * position).xyz);
    float4 normal = modelMatrix * float4(in.normal.x, in.normal.y, in.normal.z, 0.0f);
    out.normal = normalize(half3(normal.xyz));
    return out;
}

fragment float4 anchorGeometryFragmentLighting(ColorInOut in [[stage_in]],
                                               constant SharedUniforms &uniforms [[ buffer(3) ]]) {
    float3 normal = float3(in.normal);
    float3 directionalContribution = float3(0);
    {
        float nDotL = saturate(dot(normal, -uniforms.directionalLightDirection));
        float3 diffuseTerm = uniforms.directionalLightColor * nDotL;
        float3 halfwayVector = normalize(-uniforms.directionalLightDirection - float3(in.eyePosition));
        float reflectionAngle = saturate(dot(normal, halfwayVector));
        float specularIntensity = saturate(powr(reflectionAngle, uniforms.materialShininess));
        float3 specularTerm = uniforms.directionalLightColor * specularIntensity;
        directionalContribution = diffuseTerm + specularTerm;
    }
    float3 ambientContribution = uniforms.ambientLightColor;
    float3 lightContributions = ambientContribution + directionalContribution;
    float3 color = in.color.rgb * lightContributions;
    return float4(color, in.color.w);
}

typedef struct {
    float3 position [[attribute(0)]];
} DebugVertex;

vertex float4 vertexDebugPlane(DebugVertex in [[ stage_in]],
                               constant SharedUniforms &sharedUniforms [[ buffer(3) ]],
                               constant InstanceUniforms *instanceUniforms [[ buffer(2) ]],
                               ushort vid [[vertex_id]],
                               ushort iid [[instance_id]]) {
    float4 position = float4(in.position, 1.0);
    float4x4 modelMatrix = instanceUniforms[iid].modelMatrix;
    float4x4 modelViewMatrix = sharedUniforms.viewMatrix * modelMatrix;
    float4 outPosition = sharedUniforms.projectionMatrix * modelViewMatrix * position;
    return outPosition;
}

fragment float4 fragmentDebugPlane() {
    return float4(253.0/255.0, 108.0/255.0, 158.0/255.0, 1);
}
