
#include <metal_stdlib>

using namespace metal;

float differenceOp(float d0, float d1) {
    return max(d0, -d1);
}

float distanceToRect( float2 point, float2 center, float2 size ) {
    point -= center;
    point = abs(point);
    point -= size / 2.;
    return max(point.x, point.y);
}

float distanceToScene( float2 point ) {
    float d2r1 = distanceToRect( point, float2(0.), float2(0.45, 0.85) );
    float2 mod = point - 0.1 * floor(point / 0.1);
    float d2r2 = distanceToRect( mod, float2( 0.05 ), float2(0.02, 0.04) );
    float diff = differenceOp(d2r1, d2r2);
    return diff;
}

float getShadow(float2 point, float2 lightPos) {
    float2 lightDir = normalize(lightPos - point);
    float dist2light = length(lightDir);
    float distAlongRay = 0.0;
    for (float i=0.0; i < 80.; i++) {
        float2 currentPoint = point + lightDir * distAlongRay;
        float d2scene = distanceToScene(currentPoint);
        if (d2scene <= 0.001) { return 0.0; }
        distAlongRay += d2scene;
        if (distAlongRay > dist2light) { break; }
    }
    return 1.;
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    constant float &timer [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    float d2scene = distanceToScene(uv);
    bool i = d2scene < 0.0;
    float4 color = i ? float4( .1, .5, .5, 1. ) : float4( .7, .8, .8, 1. );
    float2 lightPos = float2(1.3 * sin(timer), 1.3 * cos(timer));
    float dist2light = length(lightPos - uv);
    color *= max(0.0, 2. - dist2light );
    float shadow = getShadow(uv, lightPos);
    shadow = shadow * 0.5 + 0.5;
    color *= shadow;
    output.write(color, gid);
}
