
import MetalKit

public class MetalView: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice!
    var queue: MTLCommandQueue! = nil
    var cps: MTLComputePipelineState! = nil
    var timer: Float = 0
    var timerBuffer: MTLBuffer!
    var texture: MTLTexture!
  
    override public init() {
        super.init()
        device = MTLCreateSystemDefaultDevice()!
        queue = device!.newCommandQueue()
        setUpTexture()
        registerShaders()
    }
  
    func setUpTexture() {
        let path = Bundle.main.pathForResource("texture", ofType: "jpg")
        let textureLoader = MTKTextureLoader(device: device!)
        texture = try! textureLoader.newTexture(withContentsOf: URL(fileURLWithPath: path!), options: nil)
    }
  
    func registerShaders() {
        let path = Bundle.main.pathForResource("Shaders", ofType: "metal")
        do {
            let input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            let library = try device!.newLibrary(withSource: input, options: nil)
            let kernel = library.newFunction(withName: "compute")!
            cps = try device!.newComputePipelineState(with: kernel)
        } catch let e {
            Swift.print("\(e)")
        }
        timerBuffer = device!.newBuffer(withLength: sizeof(Float.self), options: [])
    }

    func update() {
        timer += 0.01
        let bufferPointer = timerBuffer.contents()
        memcpy(bufferPointer, &timer, sizeof(Float.self))
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        if let drawable = view.currentDrawable {
            let commandBuffer = queue.commandBuffer()
            let commandEncoder = commandBuffer.computeCommandEncoder()
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, at: 0)
            commandEncoder.setTexture(texture, at: 1)
            commandEncoder.setBuffer(timerBuffer, offset: 0, at: 0)
            update()
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
