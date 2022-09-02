
#include <metal_stdlib>
using namespace metal;

struct Ray {
    float3 origin;
    float3 direction;
    Ray(float3 o, float3 d) {
        origin = o;
        direction = d;
    }
};

struct Sphere {
    float3 center;
    float radius;
    Sphere(float3 c, float r) {
        center = c;
        radius = r;
    }
};

struct Plane {
    float yCoord;
    Plane(float y) {
        yCoord = y;
    }
};

struct Light {
    float3 position;
    Light(float3 pos) {
        position = pos;
    }
};

float unionOp(float d0, float d1) {
    return min(d0, d1);
}

float differenceOp(float d0, float d1) {
    return max(d0, -d1);
}

float distToSphere(Ray ray, Sphere s) {
    return length(ray.origin - s.center) - s.radius;
}

float distToPlane(Ray ray, Plane plane) {
    return ray.origin.y - plane.yCoord;
}

float distToScene(Ray r) {
    Plane p = Plane(0.0);
    float d2p = distToPlane(r, p);
    Sphere s1 = Sphere(float3(2.0), 1.9);
    Sphere s2 = Sphere(float3(0.0, 4.0, 0.0), 4.0);
    Sphere s3 = Sphere(float3(0.0, 4.0, 0.0), 3.9);
    Ray repeatRay = r;
    repeatRay.origin = fract(r.origin / 4.0) * 4.0;
    float d2s1 = distToSphere(repeatRay, s1);
    float d2s2 = distToSphere(r, s2);
    float d2s3 = distToSphere(r, s3);
    float dist = differenceOp(d2s2, d2s3);
    dist = differenceOp(dist, d2s1);
    dist = unionOp(d2p, dist);
    return dist;
}

float3 getNormal(Ray ray) {
    float2 eps = float2(0.001, 0.0);
    float3 n = float3(distToScene(Ray(ray.origin + eps.xyy, ray.direction)) -
                      distToScene(Ray(ray.origin - eps.xyy, ray.direction)),
                      distToScene(Ray(ray.origin + eps.yxy, ray.direction)) -
                      distToScene(Ray(ray.origin - eps.yxy, ray.direction)),
                      distToScene(Ray(ray.origin + eps.yyx, ray.direction)) -
                      distToScene(Ray(ray.origin - eps.yyx, ray.direction)));
    return normalize(n);
}

float lighting(Ray ray, float3 normal, Light light) {
    float3 lightRay = normalize(light.position - ray.origin);
    float diffuse = max(0.0, dot(normal, lightRay));
    float3 reflectedRay = reflect(ray.direction, normal);
    float specular = max(0.0, dot(reflectedRay, lightRay));
    specular = pow(specular, 200.0);
    return diffuse + specular;
}

float shadow(Ray ray, float k, Light l) {
    float3 lightDir = l.position - ray.origin;
    float lightDist = length(lightDir);
    lightDir = normalize(lightDir);
    float eps = 0.1;
    float distAlongRay = eps * 2.0;
    float light = 1.0;
    for (int i=0; i<100; i++) {
        Ray lightRay = Ray(ray.origin + lightDir * distAlongRay, lightDir);
        float dist = distToScene(lightRay);
        light = min(light, 1.0 - (eps - dist) / eps);
        distAlongRay += dist * 0.5;
        eps += dist * k;
        if (distAlongRay > lightDist) { break; }
    }
    return max(light, 0.0);
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    constant float &time [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    uv.y = -uv.y;
    Ray ray = Ray(float3(0.0, 4.0, -12.0), normalize(float3(uv, 1.0)));
    float3 col = float3(1.0);
    bool hit = false;
    for (int i=0; i<200; i++) {
        float dist = distToScene(ray);
        if (dist < 0.001) {
            hit = true;
            break;
        }
        ray.origin += ray.direction * dist;
    }
    if (!hit) {
        col = float3(0.5);
    } else {
        float3 n = getNormal(ray);
        Light light = Light(float3(sin(time) * 10.0, 5.0, cos(time) * 10.0));
        float l = lighting(ray, n, light);
        float s = shadow(ray, 0.3, light);
        col = col * l * s;
    }
    Light light2 = Light(float3(0.0, 5.0, -15.0));
    float3 lightRay = normalize(light2.position - ray.origin);
    float fl = max(0.0, dot(getNormal(ray), lightRay) / 2.0);
    col = col + fl;
    output.write(float4(col, 1.0), gid);
}
