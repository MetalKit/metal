//
//  MetalView.swift
//  chapter03
//
//  Created by Marius on 1/12/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import MetalKit

class MetalView: MTKView {

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        render()
    }
    
    func render() {
        device = MTLCreateSystemDefaultDevice()
        let vertex_data:[Float] = [-1.0, -1.0, 0.0, 1.0,
                                    1.0, -1.0, 0.0, 1.0,
                                    0.0,  1.0, 0.0, 1.0]
        let data_size = vertex_data.count * sizeof(Float)
        let vertex_buffer = device!.newBufferWithBytes(vertex_data, length: data_size, options: [])
        let library = device!.newDefaultLibrary()!
        let vertex_func = library.newFunctionWithName("vertex_func")
        let frag_func = library.newFunctionWithName("fragment_func")
        let rpld = MTLRenderPipelineDescriptor()
        rpld.vertexFunction = vertex_func
        rpld.fragmentFunction = frag_func
        rpld.colorAttachments[0].pixelFormat = .BGRA8Unorm
        var rps: MTLRenderPipelineState! = nil
        do {
            try rps = device!.newRenderPipelineStateWithDescriptor(rpld)
        } catch let error {
            self.print("\(error)")
        }
        if let rpd = currentRenderPassDescriptor, drawable = currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 0.5, 1.0)
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
