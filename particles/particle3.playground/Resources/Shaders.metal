
#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 position;
    float2 velocity;
};

kernel void firstPass(texture2d<half, access::write> output [[texture(0)]],
                      uint2 id [[thread_position_in_grid]]) {
    output.write(half4(0., 0., 0., 1.), id);
}

kernel void secondPass(texture2d<half, access::write> output [[texture(0)]],
                       device Particle *particles [[buffer(0)]],
                       uint id [[thread_position_in_grid]]) {
    Particle particle = particles[id];
    float2 position = particle.position;
    float2 velocity = particle.velocity;
    int width = output.get_width();
    int height = output.get_height();
    if (position.x < 0 || position.x > width) { velocity.x *= -1; }
    if (position.y < 0 || position.y > height) { velocity.y *= -1; }
    position += velocity;
    particle.position = position;
    particle.velocity = velocity;
    particles[id] = particle;
    uint2 pos = uint2(position.x, position.y);
    output.write(half4(1.), pos);
    output.write(half4(1.), pos + uint2( 1, 0));
    output.write(half4(1.), pos + uint2( 0, 1));
    output.write(half4(1.), pos - uint2( 1, 0));
    output.write(half4(1.), pos - uint2( 0, 1));
}
