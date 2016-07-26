//
//  MetalView.swift
//  chapter07
//
//  Created by Marius on 2/29/16.
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
    
    func createBuffers() {
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device!.newCommandQueue()
        let vertex_data = [Vertex(position: [-1.0, -1.0, 0.0, 1.0], color: [1, 0, 0, 1]),
                           Vertex(position: [ 1.0, -1.0, 0.0, 1.0], color: [0, 1, 0, 1]),
                           Vertex(position: [ 0.0,  1.0, 0.0, 1.0], color: [0, 0, 1, 1])
        ]
        vertexBuffer = device!.newBuffer(withBytes: vertex_data, length: sizeof(Vertex.self) * 3, options:[])
        uniformBuffer = device!.newBuffer(withLength: sizeof(Float.self) * 16, options: [])
        let bufferPointer = uniformBuffer.contents()
        memcpy(bufferPointer, Matrix().modelMatrix(Matrix()).m, sizeof(Float.self) * 16)
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
        super.draw(dirtyRect)
        if let rpd = currentRenderPassDescriptor, drawable = currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            let commandBuffer = device!.newCommandQueue().commandBuffer()
            let commandEncoder = commandBuffer.renderCommandEncoder(with: rpd)
            commandEncoder.setRenderPipelineState(rps!)
            commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
            commandEncoder.drawPrimitives(.triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
