//
//  MetalView.swift
//  chapter04
//
//  Created by Marius on 1/26/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import MetalKit

class MetalView: MTKView {
    
    var vertex_buffer: MTLBuffer!
    var rps: MTLRenderPipelineState! = nil
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        render()
    }
    
    func render() {
        device = MTLCreateSystemDefaultDevice()
        createBuffer()
        registerShaders()
        sendToGPU()
    }
    
    struct Vertex {
        var position: vector_float4
        var color: vector_float4
    };
    
    func createBuffer() {
        let vertex_data = [Vertex(position: [-1.0, -1.0, 0.0, 1.0], color: [1, 0, 0, 1]),
                           Vertex(position: [ 1.0, -1.0, 0.0, 1.0], color: [0, 1, 0, 1]),
                           Vertex(position: [ 0.0,  1.0, 0.0, 1.0], color: [0, 0, 1, 1])]
        vertex_buffer = device!.newBufferWithBytes(vertex_data, length: sizeof(Vertex) * 3, options:[])
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
            command_encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            command_encoder.endEncoding()
            command_buffer.presentDrawable(drawable)
            command_buffer.commit()
        }
    }
}
