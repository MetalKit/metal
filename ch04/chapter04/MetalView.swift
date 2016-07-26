//
//  MetalView.swift
//  chapter04
//
//  Created by Marius on 1/26/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import MetalKit

class MetalView: MTKView {
    
    var commandQueue: MTLCommandQueue?
    var rps: MTLRenderPipelineState?
    var vertexBuffer: MTLBuffer?
    
    struct Vertex {
        var position: vector_float4
        var color: vector_float4
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        createBuffer()
        registerShaders()
    }
    
    func createBuffer() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device!.newCommandQueue()
        let vertexData = [Vertex(position: [-1.0, -1.0, 0.0, 1.0], color: [1, 0, 0, 1]),
                          Vertex(position: [ 1.0, -1.0, 0.0, 1.0], color: [0, 1, 0, 1]),
                          Vertex(position: [ 0.0,  1.0, 0.0, 1.0], color: [0, 0, 1, 1])]
        vertexBuffer = device!.newBuffer(withBytes: vertexData, length: sizeof(Vertex.self) * 3, options:[])
    }
    
    func registerShaders() {
        let library = device!.newDefaultLibrary()!
        let vertex_func = library.newFunction(withName: "vertex_func")
        let frag_func = library.newFunction(withName: "fragment_func")
        let rpld = MTLRenderPipelineDescriptor()
        rpld.vertexFunction = vertex_func
        rpld.fragmentFunction = frag_func
        rpld.colorAttachments[0].pixelFormat = .bgra8Unorm
        do {
            try rps = device!.newRenderPipelineState(with: rpld)
        } catch let error {
            self.print("\(error)")
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        if let drawable = currentDrawable, let rpd = currentRenderPassDescriptor {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            let commandBuffer = commandQueue!.commandBuffer()
            let commandEncoder = commandBuffer.renderCommandEncoder(with: rpd)
            commandEncoder.setRenderPipelineState(rps!)
            commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
            commandEncoder.drawPrimitives(.triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
