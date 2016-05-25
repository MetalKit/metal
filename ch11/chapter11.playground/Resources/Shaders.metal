
#include <metal_stdlib>

using namespace metal;

float distToCircle(float2 point, float2 center, float radius)
{
    return length(point - center) - radius;
}

float smootherstep(float e1, float e2, float x)
{
    x = clamp((x - e1) / (e2 - e1), 0.0, 1.0);
    return x * x * x * (x * (x * 6 - 15) + 10);
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);
    
//    //uncomment this code block for the 1st part of the tutorial and comment out the others
//    uv = uv * 2.0 - 1.0;
//    float distance = distToCircle(uv, float2(0), 0.5);
//    float xMax = width/height;
//    float4 sun = float4(1, 0.7, 0, 1) * (1 - distance);
//    float4 planet = float4(0);
//    float radius = 0.5;
//    float m = smootherstep(radius - 0.005, radius + 0.005, length(uv - float2(xMax-1, 0)));
//    float4 pixel = mix(planet, sun, m);
//    output.write(pixel, gid);

//    // uncomment this code block for the 2nd part of the tutorial and comment out the others
//    float3 color = float3(0.7);
//    if(fmod(uv.x, 0.1) < 0.005 || fmod(uv.y, 0.1) < 0.005) color = float3(0,0,1);
//    float2 uv_ext = uv * 2.0 - 1.0;
//    if(abs(uv_ext.x) < 0.02 || abs(uv_ext.y) < 0.02) color = float3(1, 0, 0);
//    if(abs(uv_ext.x - uv_ext.y) < 0.02 || abs(uv_ext.x + uv_ext.y) < 0.02) color = float3(0, 1, 0);
//    output.write(float4(color, 1), gid);
    
    // uncomment this code block for the 3rd part of the tutorial and comment out the others
    float2 cc = 1.1*float2( 0.5*cos(0.1) - 0.25*cos(0.2), 0.5*sin(0.1) - 0.25*sin(0.2) );
    float4 dmin = float4(1000.0);
    float2 z = (-1.0 + 2.0*uv)*float2(1.7,1.0);
    for( int i=0; i<64; i++ ) {
        z = cc + float2( z.x*z.x - z.y*z.y, 2.0*z.x*z.y );
        dmin=min(dmin, float4(abs(0.0+z.y + 0.5*sin(z.x)), abs(1.0+z.x + 0.5*sin(z.y)), dot(z,z), length( fract(z)-0.5) ) );
    }
    float3 color = float3( dmin.w );
    color = mix( color, float3(1.00,0.80,0.60), min(1.0,pow(dmin.x*0.25,0.20)) );
    color = mix( color, float3(0.72,0.70,0.60), min(1.0,pow(dmin.y*0.50,0.50)) );
    color = mix( color, float3(1.00,1.00,1.00), 1.0-min(1.0,pow(dmin.z*1.00,0.15) ));
    color = 1.25*color*color;
    color *= 0.5 + 0.5*pow(16.0*uv.x*(1.0-uv.x)*uv.y*(1.0-uv.y),0.15);
    output.write(float4(color, 1), gid);
}
