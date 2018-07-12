//
//  Transforms.swift
//
//  Created by Marius Horga on 7/7/18.
//

import simd

func translate(tx: Float, ty: Float, tz: Float) -> float4x4 {
  return float4x4(
    float4( 1,  0,  0,  0),
    float4( 0,  1,  0,  0),
    float4( 0,  0,  1,  0),
    float4(tx, ty, tz,  1)
  )
}

func rotate(radians: Float, axis: float3) -> float4x4 {
  let normalizedAxis = normalize(axis)
  let ct = cosf(radians)
  let st = sinf(radians)
  let ci = 1 - ct
  let x = normalizedAxis.x, y = normalizedAxis.y, z = normalizedAxis.z
  
  return float4x4(
    float4(    ct + x * x * ci,  y * x * ci + z * st,  z * x * ci - y * st,  0),
    float4(x * y * ci - z * st,      ct + y * y * ci,  z * y * ci + x * st,  0),
    float4(x * z * ci + y * st,  y * z * ci - x * st,      ct + z * z * ci,  0),
    float4(                  0,                    0,                    0,  1)
  )
}

func scale(sx: Float, sy: Float, sz: Float) -> float4x4 {
  return float4x4(
    float4(sx,   0,   0,  0),
    float4( 0,  sy,   0,  0),
    float4( 0,   0,  sz,  0),
    float4( 0,   0,   0,  1)
  )
}
