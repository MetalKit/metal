
#include <metal_stdlib>

using namespace metal;

struct Vertex {
    float4 position [[position]];
    float4 color;
};

vertex Vertex vertex_transform(device Vertex *vertices [[buffer(0)]],
                               uint vertexId [[vertex_id]])
{
    Vertex out;
    out.position = vertices[vertexId].position;
    out.color = vertices[vertexId].color;
    return out;
}

fragment half4 fragment_lighting(Vertex fragmentIn [[stage_in]])
{
//    return half4(fragmentIn.color);
    return half4(0.0, 1.0, 0.0, 1.0);
}
