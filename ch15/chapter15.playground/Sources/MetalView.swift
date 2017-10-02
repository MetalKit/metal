
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
        queue = device!.makeCommandQueue()
        setUpTexture()
        registerShaders()
    }
  
    func setUpTexture() {
        let path = Bundle.main.path(forResource: "texture", ofType: "jpg")
        let textureLoader = MTKTextureLoader(device: device!)
        texture = try! textureLoader.newTexture(URL: URL(fileURLWithPath: path!), options: nil)
    }
  
    func registerShaders() {
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
    }

    func update() {
        timer += 0.01
        let bufferPointer = timerBuffer.contents()
        memcpy(bufferPointer, &timer, MemoryLayout<Float>.size)
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        if let drawable = view.currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, index: 0)
            commandEncoder.setTexture(texture, index: 1)
            commandEncoder.setBuffer(timerBuffer, offset: 0, index: 0)
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
