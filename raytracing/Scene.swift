//
//  Scene.swift
//
//  Created by Marius Horga on 7/7/18.
//

import simd

var vertices = [float3]()
var normals = [float3]()
var colors = [float3]()
var masks = [uint]()

struct Faces: OptionSet {
  let rawValue: Int
  
  static let positiveX = Faces(rawValue: 1)
  static let negativeX = Faces(rawValue: 2)
  static let positiveY = Faces(rawValue: 4)
  static let negativeY = Faces(rawValue: 8)
  static let positiveZ = Faces(rawValue: 16)
  static let negativeZ = Faces(rawValue: 32)
  static let all       = Faces(rawValue: 64)
}

func getTriangleNormal(v0: float3, v1: float3, v2: float3) -> float3 {
  let e1 = normalize(v1 - v0)
  let e2 = normalize(v2 - v0)
  return cross(e1, e2)
}

func createCubeFace(cubeVertices: [float3],
                    color: float3,
                    i0: Int,
                    i1: Int,
                    i2: Int,
                    i3: Int,
                    inwardNormals: Bool,
                    triangleMask: uint)
{
  let v0 = cubeVertices[i0]
  let v1 = cubeVertices[i1]
  let v2 = cubeVertices[i2]
  let v3 = cubeVertices[i3]
  
  var n0 = getTriangleNormal(v0: v0, v1: v1, v2: v2)
  var n1 = getTriangleNormal(v0: v0, v1: v2, v2: v3)
  
  if (inwardNormals) {
    n0 = -n0
    n1 = -n1
  }
  
  vertices += [v0, v1, v2, v0, v2, v3]
  normals += [n0, n0, n0, n1, n1, n1]
  colors += [color, color, color, color, color, color]
  masks += [triangleMask, triangleMask]
}

func createCube(faceMask: Faces,
                color: float3,
                transform: float4x4,
                inwardNormals: Bool,
                triangleMask: Int32)
{
  var cubeVertices = [
    float3(-0.5, -0.5, -0.5),
    float3( 0.5, -0.5, -0.5),
    float3(-0.5,  0.5, -0.5),
    float3( 0.5,  0.5, -0.5),
    float3(-0.5, -0.5,  0.5),
    float3( 0.5, -0.5,  0.5),
    float3(-0.5,  0.5,  0.5),
    float3( 0.5,  0.5,  0.5)
  ]
  
  for i in 0...7 {
    let vertex = cubeVertices[i]
    var transformedVertex = float4(vertex.x, vertex.y, vertex.z, 1.0)
    transformedVertex = transform * transformedVertex
    cubeVertices[i] = float3(transformedVertex.x, transformedVertex.y, transformedVertex.z)
  }
  if faceMask.contains(.negativeX) || faceMask.contains(.all) {
    createCubeFace(cubeVertices: cubeVertices, color: color, i0: 0, i1: 4, i2: 6, i3: 2, inwardNormals: inwardNormals, triangleMask: uint(triangleMask))
  }
  if faceMask.contains(.positiveX) || faceMask.contains(.all)   {
    createCubeFace(cubeVertices: cubeVertices, color: color, i0: 1, i1: 3, i2: 7, i3: 5, inwardNormals: inwardNormals, triangleMask: uint(triangleMask))
  }
  if faceMask.contains(.negativeY) || faceMask.contains(.all) {
    createCubeFace(cubeVertices: cubeVertices, color: color, i0: 0, i1: 1, i2: 5, i3: 4, inwardNormals: inwardNormals, triangleMask: uint(triangleMask))
  }
  if faceMask.contains(.positiveY) || faceMask.contains(.all) {
    createCubeFace(cubeVertices: cubeVertices, color: color, i0: 2, i1: 6, i2: 7, i3: 3, inwardNormals: inwardNormals, triangleMask: uint(triangleMask))
  }
  if faceMask.contains(.negativeZ) || faceMask.contains(.all) {
    createCubeFace(cubeVertices: cubeVertices, color: color, i0: 0, i1: 2, i2: 3, i3: 1, inwardNormals: inwardNormals, triangleMask: uint(triangleMask))
  }
  if faceMask.contains(.positiveZ) || faceMask.contains(.all) {
    createCubeFace(cubeVertices: cubeVertices, color: color, i0: 4, i1: 5, i2: 7, i3: 6, inwardNormals: inwardNormals, triangleMask: uint(triangleMask))
  }
}
