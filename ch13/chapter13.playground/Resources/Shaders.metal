
#include <metal_stdlib>

using namespace metal;

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    constant float &timer [[buffer(1)]],
                    constant float2 &mouse [[buffer(2)]],
                    uint2 gid [[thread_position_in_grid]])
{
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    float radius = 0.5;
    float distance = length(uv) - radius;
//    output.write(distance < 0 ? float4(1) : float4(0), gid);
    
    float planet = float(sqrt(radius * radius - uv.x * uv.x - uv.y * uv.y));
//    planet /= radius;
//    output.write(distance < 0 ? float4(planet) : float4(0), gid);

    float3 normal = normalize(float3(uv.x, uv.y, planet));
//    output.write(distance < 0 ? float4(float3(normal), 1) : float4(0), gid);
    
    float3 source = normalize(float3(cos(timer), sin(timer), 1));
//    float3 source = normalize(float3(-1, 0, 1));
    float light = dot(normal, source);
    output.write(distance < 0 ? float4(float3(light), 1) : float4(0), gid);
}
