
import MetalKit

public class MetalView: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice!
    var queue: MTLCommandQueue!
    var cps: MTLComputePipelineState!
    var time: Float = 0
    var timeBuffer: MTLBuffer!
    
    override public init() {
        super.init()
        registerShaders()
    }
    
    func registerShaders() {
        device = MTLCreateSystemDefaultDevice()!
        queue = device.makeCommandQueue()
        let path = Bundle.main.path(forResource: "Shaders", ofType: "metal")
        do {
            let input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            let library = try device.makeLibrary(source: input, options: nil)
            let kernel = library.makeFunction(name: "compute")!
            cps = try device.makeComputePipelineState(function: kernel)
        } catch let e {
            Swift.print("\(e)")
        }
        timeBuffer = device!.makeBuffer(length: MemoryLayout<Float>.size, options: [])
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        if let drawable = view.currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, index: 0)
            commandEncoder.setBuffer(timeBuffer, offset: 0, index: 0)
            time += 0.01
            let bufferPointer = timeBuffer.contents()
            memcpy(bufferPointer, &time, MemoryLayout<Float>.size)
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width / threadGroupCount.width, drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
