//
//  Shaders.metal
//
//  Created by Marius Horga on 7/7/18.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

struct Ray {
  packed_float3 origin;
  uint mask;
  packed_float3 direction;
  float maxDistance;
  float3 color;
};

struct Intersection {
  float distance;
  int primitiveIndex;
  float2 coordinates;
};

kernel void rayKernel(uint2 tid [[thread_position_in_grid]],
                      constant Uniforms & uniforms [[buffer(0)]],
                      device Ray *rays [[buffer(1)]],
                      device float2 *random [[buffer(2)]],
                      texture2d<float, access::write> dstTex [[texture(0)]])
{
  if (tid.x < uniforms.width && tid.y < uniforms.height) {
    unsigned int rayIdx = tid.y * uniforms.width + tid.x;
    device Ray & ray = rays[rayIdx];
    float2 pixel = (float2)tid;
    float2 r = random[(tid.y % 16) * 16 + (tid.x % 16)];
    pixel += r;
    float2 uv = (float2)pixel / float2(uniforms.width, uniforms.height);
    uv = uv * 2.0f - 1.0f;
    constant Camera & camera = uniforms.camera;
    ray.origin = camera.position;
    ray.direction = normalize(uv.x * camera.right +
                              uv.y * camera.up +
                              camera.forward);
    ray.mask = RAY_MASK_PRIMARY;
    ray.maxDistance = INFINITY;
    ray.color = float3(1.0f, 1.0f, 1.0f);
    dstTex.write(float4(0.0f, 0.0f, 0.0f, 0.0f), tid);
  }
}

template<typename T>
inline T interpolateVertexAttribute(device T *attributes, Intersection intersection) {
  float3 uvw;
  uvw.xy = intersection.coordinates;
  uvw.z = 1.0f - uvw.x - uvw.y;
  unsigned int triangleIndex = intersection.primitiveIndex;
  T T0 = attributes[triangleIndex * 3 + 0];
  T T1 = attributes[triangleIndex * 3 + 1];
  T T2 = attributes[triangleIndex * 3 + 2];
  return uvw.x * T0 + uvw.y * T1 + uvw.z * T2;
}

inline void sampleAreaLight(constant AreaLight & light,
                            float2 u,
                            float3 position,
                            thread float3 & lightDirection,
                            thread float3 & lightColor,
                            thread float & lightDistance)
{
  u = u * 2.0f - 1.0f;
  float3 samplePosition = light.position +
  light.right * u.x +
  light.up * u.y;
  lightDirection = samplePosition - position;
  lightDistance = length(lightDirection);
  float inverseLightDistance = 1.0f / max(lightDistance, 1e-3f);
  lightDirection *= inverseLightDistance;
  lightColor = light.color;
  lightColor *= (inverseLightDistance * inverseLightDistance);
  lightColor *= saturate(dot(-lightDirection, light.forward));
}

inline float3 sampleCosineWeightedHemisphere(float2 u) {
  float phi = 2.0f * M_PI_F * u.x;
  float cos_phi;
  float sin_phi = sincos(phi, cos_phi);
  float cos_theta = sqrt(u.y);
  float sin_theta = sqrt(1.0f - cos_theta * cos_theta);
  return float3(sin_theta * cos_phi, cos_theta, sin_theta * sin_phi);
}

inline float3 alignHemisphereWithNormal(float3 sample, float3 normal) {
  float3 up = normal;
  float3 right = normalize(cross(normal, float3(0.0072f, 1.0f, 0.0034f)));
  float3 forward = cross(right, up);
  return sample.x * right + sample.y * up + sample.z * forward;
}

kernel void shadeKernel(uint2 tid [[thread_position_in_grid]],
                        constant Uniforms & uniforms,
                        device Ray *rays,
                        device Ray *shadowRays,
                        device Intersection *intersections,
                        device float3 *vertexColors,
                        device float3 *vertexNormals,
                        device float2 *random,
                        device uint *triangleMasks,
                        texture2d<float, access::write> dstTex)
{
  if (tid.x < uniforms.width && tid.y < uniforms.height) {
    unsigned int rayIdx = tid.y * uniforms.width + tid.x;
    device Ray & ray = rays[rayIdx];
    device Ray & shadowRay = shadowRays[rayIdx];
    device Intersection & intersection = intersections[rayIdx];
    float3 color = ray.color;
    if (ray.maxDistance >= 0.0f && intersection.distance >= 0.0f) {
      uint mask = triangleMasks[intersection.primitiveIndex];
      if (mask == TRIANGLE_MASK_GEOMETRY) {
        float3 intersectionPoint = ray.origin + ray.direction * intersection.distance;
        float3 surfaceNormal = interpolateVertexAttribute(vertexNormals, intersection);
        surfaceNormal = normalize(surfaceNormal);
        float2 r = random[(tid.y % 16) * 16 + (tid.x % 16)];
        float3 lightDirection;
        float3 lightColor;
        float lightDistance;
        sampleAreaLight(uniforms.light, r, intersectionPoint, lightDirection,
                        lightColor, lightDistance);
        lightColor *= saturate(dot(surfaceNormal, lightDirection));
        color *= interpolateVertexAttribute(vertexColors, intersection);
        shadowRay.origin = intersectionPoint + surfaceNormal * 1e-3f;
        shadowRay.direction = lightDirection;
        shadowRay.mask = RAY_MASK_SHADOW;
        shadowRay.maxDistance = lightDistance - 1e-3f;
        shadowRay.color = lightColor * color;
        float3 sampleDirection = sampleCosineWeightedHemisphere(r);
        sampleDirection = alignHemisphereWithNormal(sampleDirection, surfaceNormal);
        ray.origin = intersectionPoint + surfaceNormal * 1e-3f;
        ray.direction = sampleDirection;
        ray.color = color;
        ray.mask = RAY_MASK_SECONDARY;
      }
      else {
        dstTex.write(float4(uniforms.light.color, 1.0f), tid);
        ray.maxDistance = -1.0f;
        shadowRay.maxDistance = -1.0f;
      }
    }
    else {
      ray.maxDistance = -1.0f;
      shadowRay.maxDistance = -1.0f;
    }
  }
}

kernel void shadowKernel(uint2 tid [[thread_position_in_grid]],
                         constant Uniforms & uniforms,
                         device Ray *shadowRays,
                         device float *intersections,
                         texture2d<float, access::read_write> dstTex)
{
  if (tid.x < uniforms.width && tid.y < uniforms.height) {
    unsigned int rayIdx = tid.y * uniforms.width + tid.x;
    device Ray & shadowRay = shadowRays[rayIdx];
    float intersectionDistance = intersections[rayIdx];
    if (shadowRay.maxDistance >= 0.0f && intersectionDistance < 0.0f) {
      float3 color = shadowRay.color;
      color += dstTex.read(tid).xyz;
      dstTex.write(float4(color, 1.0f), tid);
    }
  }
}

kernel void accumulateKernel(uint2 tid [[thread_position_in_grid]],
                             constant Uniforms & uniforms,
                             texture2d<float> renderTex,
                             texture2d<float, access::read_write> accumTex)
{
  if (tid.x < uniforms.width && tid.y < uniforms.height) {
    float3 color = renderTex.read(tid).xyz;
    if (uniforms.frameIndex > 0) {
      float3 prevColor = accumTex.read(tid).xyz;
      prevColor *= uniforms.frameIndex;
      color += prevColor;
      color /= (uniforms.frameIndex + 1);
    }
    accumTex.write(float4(color, 1.0f), tid);
  }
}

struct Vertex {
  float4 position [[position]];
  float2 uv;
};

constant float2 quadVertices[] = {
  float2(-1, -1),
  float2(-1,  1),
  float2( 1,  1),
  float2(-1, -1),
  float2( 1,  1),
  float2( 1, -1)
};

vertex Vertex vertexShader(unsigned short vid [[vertex_id]])
{
  float2 position = quadVertices[vid];
  Vertex out;
  out.position = float4(position, 0, 1);
  out.uv = position * 0.5f + 0.5f;
  return out;
}

fragment float4 fragmentShader(Vertex in [[stage_in]],
                               texture2d<float> tex)
{
  constexpr sampler s(min_filter::nearest, mag_filter::nearest, mip_filter::none);
  float3 color = tex.sample(s, in.uv).xyz;
  color = color / (1.0f + color);
  return float4(color, 1.0f);
}
