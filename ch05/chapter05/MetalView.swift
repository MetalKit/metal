//
//  MetalView.swift
//  chapter05
//
//  Created by Marius on 2/3/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import MetalKit

class MetalView: MTKView {
    
    var vertex_buffer: MTLBuffer!
    var uniform_buffer: MTLBuffer!
    var rps: MTLRenderPipelineState! = nil
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        render()
    }
    
    func render() {
        device = MTLCreateSystemDefaultDevice()
        createBuffers()
        registerShaders()
        sendToGPU()
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
        
        func translationMatrix(var matrix: Matrix, _ position: float3) -> Matrix {
            matrix.m[12] = position.x
            matrix.m[13] = position.y
            matrix.m[14] = position.z
            return matrix
        }
        
        func scalingMatrix(var matrix: Matrix, _ scale: Float) -> Matrix {
            matrix.m[0] = scale
            matrix.m[5] = scale
            matrix.m[10] = scale
            matrix.m[15] = 1.0
            return matrix
        }
        
        func rotationMatrix(var matrix: Matrix, _ rot: float3) -> Matrix {
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
        
        func modelMatrix(var matrix: Matrix) -> Matrix {
            matrix = rotationMatrix(matrix, float3(0.0, 0.0, 0.1))
            matrix = scalingMatrix(matrix, 0.25)
            matrix = translationMatrix(matrix, float3(0.0, 0.5, 0.0))
            return matrix
        }
    }
    
    func createBuffers() {
        let vertex_data = [
            Vertex(position: [-1.0, -1.0, 0.0, 1.0], color: [1, 0, 0, 1]),
            Vertex(position: [ 1.0, -1.0, 0.0, 1.0], color: [0, 1, 0, 1]),
            Vertex(position: [ 0.0,  1.0, 0.0, 1.0], color: [0, 0, 1, 1])
        ]        
        vertex_buffer = device!.newBufferWithBytes(vertex_data, length: sizeof(Vertex) * 3, options:[])
        uniform_buffer = device!.newBufferWithLength(sizeof(Float) * 16, options: [])
        let bufferPointer = uniform_buffer.contents()
        memcpy(bufferPointer, Matrix().modelMatrix(Matrix()).m, sizeof(Float) * 16)
    }
    
    func registerShaders() {
        let library = device!.newDefaultLibrary()!
        let vertex_func = library.newFunctionWithName("vertex_func")
        let frag_func = library.newFunctionWithName("fragment_func")
        let rpld = MTLRenderPipelineDescriptor()
        rpld.vertexFunction = vertex_func
        rpld.fragmentFunction = frag_func
        rpld.colorAttachments[0].pixelFormat = .BGRA8Unorm
        do {
            try rps = device!.newRenderPipelineStateWithDescriptor(rpld)
        } catch let error {
            self.print("\(error)")
        }
    }
    
    func sendToGPU() {
        if let rpd = currentRenderPassDescriptor, drawable = currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            let command_buffer = device!.newCommandQueue().commandBuffer()
            let command_encoder = command_buffer.renderCommandEncoderWithDescriptor(rpd)
            command_encoder.setRenderPipelineState(rps)
            command_encoder.setVertexBuffer(vertex_buffer, offset: 0, atIndex: 0)
            command_encoder.setVertexBuffer(uniform_buffer, offset: 0, atIndex: 1)
            command_encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            command_encoder.endEncoding()
            command_buffer.presentDrawable(drawable)
            command_buffer.commit()
        }
    }
}
