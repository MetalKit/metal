
#include <metal_stdlib>
using namespace metal;

kernel void compute(texture2d<float, access::read> input [[texture(0)]],
                    texture2d<float, access::write> output [[texture(1)]],
                    uint2 id [[thread_position_in_grid]]) {
    uint2 index = uint2((id.x / 5) * 5, (id.y / 5) * 5);
    float4 color = input.read(index);
    output.write(color, id);
}
