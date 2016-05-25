//
//  MetalView.swift
//  chapter02
//
//  Created by Marius on 1/9/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import MetalKit

class MetalView: MTKView {

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        render()
    }
 
    func render() {
        let device = MTLCreateSystemDefaultDevice()!
        self.device = device
        let rpd = MTLRenderPassDescriptor()
        let bleen = MTLClearColor(red: 0, green: 0.5, blue: 0.5, alpha: 1)
        rpd.colorAttachments[0].texture = currentDrawable!.texture
        rpd.colorAttachments[0].clearColor = bleen
        rpd.colorAttachments[0].loadAction = .Clear
        let commandQueue = device.newCommandQueue()
        let commandBuffer = commandQueue.commandBuffer()
        let encoder = commandBuffer.renderCommandEncoderWithDescriptor(rpd)
        encoder.endEncoding()
        commandBuffer.presentDrawable(currentDrawable!)
        commandBuffer.commit()
    }
}
