
import MetalKit

public class MetalView: MTKView {
    
    var queue: MTLCommandQueue! = nil
    var cps: MTLComputePipelineState! = nil
    
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
            let command_buffer = queue.commandBuffer()
            let command_encoder = command_buffer.computeCommandEncoder()
            command_encoder.setComputePipelineState(cps)
            command_encoder.setTexture(drawable.texture, atIndex: 0)
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            command_encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            command_encoder.endEncoding()
            command_buffer.presentDrawable(drawable)
            command_buffer.commit()
        }
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
    }
}
