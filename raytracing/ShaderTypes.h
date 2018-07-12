//
//  ShaderTypes.h
//
//  Created by Marius Horga on 7/7/18.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#define TRIANGLE_MASK_GEOMETRY 1
#define TRIANGLE_MASK_LIGHT    2

#define RAY_MASK_PRIMARY   3
#define RAY_MASK_SHADOW    1
#define RAY_MASK_SECONDARY 1

struct Camera {
  vector_float3 position;
  vector_float3 right;
  vector_float3 up;
  vector_float3 forward;
};

struct AreaLight {
  vector_float3 position;
  vector_float3 forward;
  vector_float3 right;
  vector_float3 up;
  vector_float3 color;
};

struct Uniforms
{
  unsigned int width;
  unsigned int height;
  unsigned int blocksWide;
  unsigned int frameIndex;
  struct Camera camera;
  struct AreaLight light;
};

#endif /* ShaderTypes_h */
