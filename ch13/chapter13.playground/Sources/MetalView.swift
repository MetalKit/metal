
import MetalKit

public class MetalView: MTKView, NSWindowDelegate {
    
    var queue: MTLCommandQueue! = nil
    var cps: MTLComputePipelineState! = nil
    var timer: Float = 0
    var timerBuffer: MTLBuffer!
    var mouseBuffer: MTLBuffer!
    var pos: NSPoint!
    
    override public func mouseDown(event: NSEvent) {
        pos = convertPointToLayer(convertPoint(event.locationInWindow, fromView: nil))
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
    
    override public func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        if let drawable = currentDrawable {
            let commandBuffer = queue.commandBuffer()
            let commandEncoder = commandBuffer.computeCommandEncoder()
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, atIndex: 0)
            commandEncoder.setBuffer(mouseBuffer, offset: 0, atIndex: 2)
            commandEncoder.setBuffer(timerBuffer, offset: 0, atIndex: 1)
            update()
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.presentDrawable(drawable)
            commandBuffer.commit()
        }
        
    }
    
    func update() {
        timer += 0.01
        var bufferPointer = timerBuffer.contents()
        memcpy(bufferPointer, &timer, sizeof(Float))
        bufferPointer = mouseBuffer.contents()
        memcpy(bufferPointer, &pos, sizeof(NSPoint))
    }
    
    func registerShaders() {
        queue = device!.newCommandQueue()
        let path = NSBundle.mainBundle().pathForResource("Shaders", ofType: "metal")
        do {
            let input = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
            let library = try device!.newLibraryWithSource(input, options: nil)
            let kernel = library.newFunctionWithName("compute")!
            cps = try device!.newComputePipelineStateWithFunction(kernel)
        } catch let e {
            Swift.print("\(e)")
        }
        timerBuffer = device!.newBufferWithLength(sizeof(Float), options: [])
        mouseBuffer = device!.newBufferWithLength(sizeof(NSPoint), options: [])
    }
}
