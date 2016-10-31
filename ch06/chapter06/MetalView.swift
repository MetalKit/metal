//
//  MetalView.swift
//  chapter06
//
//  Created by Marius on 2/10/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import Foundation
import UIKit
import MetalKit

class MetalView: UIView {
    
    var commandQueue: MTLCommandQueue!
    
    var metalLayer: CAMetalLayer {
        return self.layer as! CAMetalLayer
    }
    
    override class var layerClass : AnyClass {
        return CAMetalLayer.self
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        let device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()
        redraw()
    }
    
    fileprivate func redraw() {
        let drawable = metalLayer.nextDrawable()!
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 1, 1, 1)
        descriptor.colorAttachments[0].texture = drawable.texture
        let commandBuffer = commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
