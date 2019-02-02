
import MetalKit

public class Renderer: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice!
    var queue: MTLCommandQueue!
    var pipelineState: MTLComputePipelineState!
    var image: MTLTexture!

    override public init() {
        super.init()
        initializeMetal()
    }

    func initializeMetal() {
        device = MTLCreateSystemDefaultDevice()
        queue = device.makeCommandQueue()
        let textureLoader = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: "nature", withExtension: "jpg")!
        guard let file = Bundle.main.path(forResource: "Shaders", ofType: "metal") else { return }
        do {
            let source = try String(contentsOfFile: file, encoding: String.Encoding.utf8)
            let library = try device.makeLibrary(source: source, options: nil)
            guard let function = library.makeFunction(name: "compute") else { return }
            pipelineState = try device.makeComputePipelineState(function: function)
            image = try textureLoader.newTexture(URL: url, options: [:])
        } catch let error {
            print(error.localizedDescription)
        }
    }

    public func draw(in view: MTKView) {
        guard let commandBuffer = queue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
              let drawable = view.currentDrawable else {
            return
        }
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(image, index: 0)
        commandEncoder.setTexture(drawable.texture, index: 1)
        
        var width = pipelineState.threadExecutionWidth
        var height = pipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerGroup = MTLSizeMake(width, height, 1)
        width = Int(view.drawableSize.width)
        height = Int(view.drawableSize.height)
        let threadsPerGrid = MTLSizeMake(width, height, 1)
        commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}
