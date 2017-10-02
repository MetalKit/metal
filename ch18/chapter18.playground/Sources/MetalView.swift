
import MetalKit

public class MetalView: NSObject, MTKViewDelegate {
    weak var view: MTKView!
    let commandQueue: MTLCommandQueue!
    let device: MTLDevice!
    let cps: MTLComputePipelineState!
    
    public init?(mtkView: MTKView, shader: String) {
        view = mtkView
        view.clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)
        view.colorPixelFormat = .bgra8Unorm
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()
        let library = try! device.makeLibrary(source: shader, options: nil)
        let function = library.makeFunction(name:"k")!
        cps = try! device.makeComputePipelineState(function: function)
        
        super.init()
        view.delegate = self
        view.device = device
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        if let drawable = view.currentDrawable,
           let commandBuffer = commandQueue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, index: 0)
            let groups = MTLSize(width: Int(view.frame.width)/4, height: Int(view.frame.height)/4, depth: 1)
            let threads = MTLSize(width: 8, height: 8,depth: 1)
            commandEncoder.dispatchThreadgroups(groups,threadsPerThreadgroup: threads)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
