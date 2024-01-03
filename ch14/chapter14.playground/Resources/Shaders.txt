
#include <metal_stdlib>

using namespace metal;

float random(float2 p)
{
    return fract(sin(dot(p, float2(15.79, 81.93)) * 45678.9123));
}

float noise(float2 p)
{
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float bottom = mix(random(i + float2(0)), random(i + float2(1.0, 0.0)), f.x);
    float top = mix(random(i + float2(0.0, 1.0)), random(i + float2(1)), f.x);
    float t = mix(bottom, top, f.y);
    return t;
}

float fbm(float2 uv)
{
    float sum = 0;
    float amp = 0.7;
    for(int i = 0; i < 4; ++i)
    {
        sum += noise(uv) * amp;
        uv += uv * 1.2;
        amp *= 0.4;
    }
    return sum;
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    constant float &timer [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    float radius = 0.5;
    float distance = length(uv) - radius;
    uv = fmod(uv + float2(timer * 0.2, 0), float2(width, height));
    float t = fbm( uv * 3 );
    output.write(distance < 0 ? float4(float3(t), 1) : float4(0), gid);
}
