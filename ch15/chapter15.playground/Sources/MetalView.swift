
import MetalKit

public class MetalView: MTKView, NSWindowDelegate {
    
    var queue: MTLCommandQueue! = nil
    var cps: MTLComputePipelineState! = nil
    var timer: Float = 0
    var timerBuffer: MTLBuffer!
    var texture: MTLTexture!
  
    required public init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        registerShaders()
        setUpTexture()
    }
  
    func setUpTexture() {
        let path = NSBundle.mainBundle().pathForResource("texture", ofType: "jpg")
        let textureLoader = MTKTextureLoader(device: device!)
        texture = try! textureLoader.newTextureWithContentsOfURL(NSURL(fileURLWithPath: path!), options: nil)
    }
  
    override public func drawRect(dirtyRect: NSRect) {
        if let drawable = currentDrawable {
            let commandBuffer = queue.commandBuffer()
            let commandEncoder = commandBuffer.computeCommandEncoder()
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, atIndex: 0)
            commandEncoder.setTexture(texture, atIndex: 1)
            commandEncoder.setBuffer(timerBuffer, offset: 0, atIndex: 0)
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
        let bufferPointer = timerBuffer.contents()
        memcpy(bufferPointer, &timer, sizeof(Float))
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
    }
}
