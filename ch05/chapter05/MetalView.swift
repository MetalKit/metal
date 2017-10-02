//
//  MetalView.swift
//  chapter05
//
//  Created by Marius on 2/3/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import MetalKit

class MetalView: MTKView {
    
    var commandQueue: MTLCommandQueue?
    var rps: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        createBuffers()
        registerShaders()
    }
    
    struct Vertex {
        var position: vector_float4
        var color: vector_float4
    }
    
    struct Matrix {
        var m: [Float]
        init() {
            m = [1, 0, 0, 0,
                 0, 1, 0, 0,
                 0, 0, 1, 0,
                 0, 0, 0, 1
            ]
        }
        func translationMatrix(_ matrix: Matrix, _ position: float3) -> Matrix {
            var matrix = matrix
            matrix.m[12] = position.x
            matrix.m[13] = position.y
            matrix.m[14] = position.z
            return matrix
        }
        func scalingMatrix(_ matrix: Matrix, _ scale: Float) -> Matrix {
            var matrix = matrix
            matrix.m[0] = scale
            matrix.m[5] = scale
            matrix.m[10] = scale
            matrix.m[15] = 1.0
            return matrix
        }
        func rotationMatrix(_ matrix: Matrix, _ rot: float3) -> Matrix {
            var matrix = matrix
            matrix.m[0] = cos(rot.y) * cos(rot.z)
            matrix.m[4] = cos(rot.z) * sin(rot.x) * sin(rot.y) - cos(rot.x) * sin(rot.z)
            matrix.m[8] = cos(rot.x) * cos(rot.z) * sin(rot.y) + sin(rot.x) * sin(rot.z)
            matrix.m[1] = cos(rot.y) * sin(rot.z)
            matrix.m[5] = cos(rot.x) * cos(rot.z) + sin(rot.x) * sin(rot.y) * sin(rot.z)
            matrix.m[9] = -cos(rot.z) * sin(rot.x) + cos(rot.x) * sin(rot.y) * sin(rot.z)
            matrix.m[2] = -sin(rot.y)
            matrix.m[6] = cos(rot.y) * sin(rot.x)
            matrix.m[10] = cos(rot.x) * cos(rot.y)
            matrix.m[15] = 1.0
            return matrix
        }
        func modelMatrix(_ matrix: Matrix) -> Matrix {
            var matrix = matrix
            matrix = rotationMatrix(matrix, float3(0.0, 0.0, 0.1))
            matrix = scalingMatrix(matrix, 0.25)
            matrix = translationMatrix(matrix, float3(0.0, 0.5, 0.0))
            return matrix
        }
    }
    
    func createBuffers() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device!.makeCommandQueue()
        let vertex_data = [Vertex(position: [-1.0, -1.0, 0.0, 1.0], color: [1, 0, 0, 1]),
                           Vertex(position: [ 1.0, -1.0, 0.0, 1.0], color: [0, 1, 0, 1]),
                           Vertex(position: [ 0.0,  1.0, 0.0, 1.0], color: [0, 0, 1, 1])
        ]        
        vertexBuffer = device!.makeBuffer(bytes: vertex_data, length: MemoryLayout<Vertex>.size * 3, options:[])
        uniformBuffer = device!.makeBuffer(length: MemoryLayout<Float>.size * 16, options: [])
        let bufferPointer = uniformBuffer.contents()
        memcpy(bufferPointer, Matrix().modelMatrix(Matrix()).m, MemoryLayout<Float>.size * 16)
    }
    
    func registerShaders() {
        let library = device!.makeDefaultLibrary()!
        let vertex_func = library.makeFunction(name: "vertex_func")
        let frag_func = library.makeFunction(name: "fragment_func")
        let rpld = MTLRenderPipelineDescriptor()
        rpld.vertexFunction = vertex_func
        rpld.fragmentFunction = frag_func
        rpld.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            try rps = device!.makeRenderPipelineState(descriptor: rpld)
        } catch let error {
            self.printView("\(error)")
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        if let rpd = currentRenderPassDescriptor, let drawable = currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            let commandBuffer = device!.makeCommandQueue()?.makeCommandBuffer()
            let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd)
            commandEncoder?.setRenderPipelineState(rps!)
            commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            commandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
            commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            commandEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}
