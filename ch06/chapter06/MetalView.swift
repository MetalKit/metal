//
//  MetalView.swift
//  chapter06
//
//  Created by Marius on 2/10/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import Cocoa

class MetalView: NSView {
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        render()
    }
    
    override class func layerClass() -> AnyClass {
        return CAMetalLayer.self
    }
    
    var metalLayer: CAMetalLayer {
        return layer as! CAMetalLayer
    }
    
    func render() {
        let device = MTLCreateSystemDefaultDevice()!
        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        let drawable = metalLayer.nextDrawable()
        let texture = drawable!.texture
        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = texture
        rpd.colorAttachments[0].loadAction = .Clear
        rpd.colorAttachments[0].storeAction = .Store
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
        let commandQueue = device.newCommandQueue()
        let commandBuffer = commandQueue.commandBuffer()
        let commandEncoder = commandBuffer.renderCommandEncoderWithDescriptor(rpd)
        commandEncoder.endEncoding()
        commandBuffer.presentDrawable(drawable!)
        commandBuffer.commit()
    }
}
