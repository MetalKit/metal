
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

struct Box {
    float3 center;
    float size;
    Box(float3 c, float s) {
        center = c;
        size = s;
    }
};

struct Camera {
    float3 position;
    Ray ray = Ray(float3(0), float3(0));
    float rayDivergence;
    Camera(float3 pos, Ray r, float div) {
        position = pos;
        ray = r;
        rayDivergence = div;
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

float distToBox(Ray r, Box b) {
    float3 d = abs(r.origin - b.center) - float3(b.size);
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float distToScene(Ray r) {
    Plane p = Plane(0.0);
    float d2p = distToPlane(r, p);
    Sphere s1 = Sphere(float3(0.0, 0.5, 0.0), 8.0);
    Sphere s2 = Sphere(float3(0.0, 0.5, 0.0), 6.0);
    Sphere s3 = Sphere(float3(10., -5., -10.), 15.0);
    Box b = Box(float3(1., 1., -4.), 1.);
    float dtb = distToBox(r, b);
    float d2s1 = distToSphere(r, s1);
    float d2s2 = distToSphere(r, s2);
    float d2s3 = distToSphere(r, s3);
    float dist = differenceOp(d2s1, d2s2);
    dist = differenceOp(dist, d2s3);
    dist = unionOp(dist, dtb);
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

float ao(float3 pos, float3 n) {
    float eps = 0.01;
    pos += n * eps * 2.0;
    float occlusion = 0.0;
    for (float i=1.0; i<10.0; i++) {
        float d = distToScene(Ray(pos, float3(0)));
        float coneWidth = 2.0 * eps;
        float occlusionAmount = max(coneWidth - d, 0.);
        float occlusionFactor = occlusionAmount / coneWidth;
        occlusionFactor  *= 1.0 - (i / 10.0);
        occlusion = max(occlusion, occlusionFactor);
        eps *= 2.0;
        pos += n * eps;
    }
    return max(0.0, 1.0 - occlusion);
}

Camera setupCam(float3 pos, float3 target, float fov, float2 uv, int x) {
    uv *= fov;
    float3 cw = normalize(target - pos );
    float3 cp = float3(0.0, 1.0, 0.0);
    float3 cu = normalize(cross(cw, cp));
    float3 cv = normalize(cross(cu, cw));
    Ray ray = Ray(pos, normalize(uv.x * cu + uv.y * cv + 0.5 * cw));
    Camera cam = Camera(pos, ray, fov / float(x));
    return cam;
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    constant float &time [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]]) {
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    uv.y = -uv.y;
    float3 camPos = float3(sin(time) * 10., 3., cos(time) * 10.);
    Camera cam = setupCam(camPos, float3(0), 1.25, uv, width);
    float3 col = float3(1.0);
    bool hit = false;
    for (int i=0; i<200; i++) {
        float dist = distToScene(cam.ray);
        if (dist < 0.001) {
            hit = true;
            break;
        }
        cam.ray.origin += cam.ray.direction * dist;
    }
    if (!hit) {
        col = float3(0.5);
    } else {
        float3 n = getNormal(cam.ray);
        float o = ao(cam.ray.origin, n);
        col = col * o;
    }
    output.write(float4(col, 1.0), gid);
}
