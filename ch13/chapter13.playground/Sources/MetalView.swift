
import MetalKit

public class MetalView: MTKView, NSWindowDelegate {
    
    var queue: MTLCommandQueue! = nil
    var cps: MTLComputePipelineState! = nil
    var timer: Float = 0
    var timerBuffer: MTLBuffer!
    var mouseBuffer: MTLBuffer!
    var pos: NSPoint!
    
    override public func mouseDown(with event: NSEvent) {
        pos = convertToLayer(convert(event.locationInWindow, from: nil))
        let scale = layer!.contentsScale
        pos.x *= scale
        pos.y *= scale
    }
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        registerShaders()
    }
    
    override public func draw(_ dirtyRect: NSRect) {
        if let drawable = currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, index: 0)
            commandEncoder.setBuffer(mouseBuffer, offset: 0, index: 2)
            commandEncoder.setBuffer(timerBuffer, offset: 0, index: 1)
            update()
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
    }
    
    func update() {
        timer += 0.01
        var bufferPointer = timerBuffer.contents()
        memcpy(bufferPointer, &timer, MemoryLayout<Float>.size)
        bufferPointer = mouseBuffer.contents()
        memcpy(bufferPointer, &pos, MemoryLayout<NSPoint>.size)
    }
    
    func registerShaders() {
        queue = device!.makeCommandQueue()
        let path = Bundle.main.path(forResource: "Shaders", ofType: "metal")
        do {
            let input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            let library = try device!.makeLibrary(source: input, options: nil)
            let kernel = library.makeFunction(name: "compute")!
            cps = try device!.makeComputePipelineState(function: kernel)
        } catch let e {
            Swift.print("\(e)")
        }
        timerBuffer = device!.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        mouseBuffer = device!.makeBuffer(length: MemoryLayout<NSPoint>.size, options: [])
    }
}
