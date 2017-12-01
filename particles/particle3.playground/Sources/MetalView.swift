
import MetalKit

struct Particle {
    var position: float2
    var velocity: float2
}

public class MetalView: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice!
    var queue: MTLCommandQueue!
    var firstState: MTLComputePipelineState!
    var secondState: MTLComputePipelineState!
    var particleBuffer: MTLBuffer!
    let particleCount = 10000
    var particles = [Particle]()
    let side = 1200
    
    override public init() {
        super.init()
        initializeMetal()
        initializeBuffers()
    }
    
    func initializeBuffers() {
        for _ in 0 ..< particleCount {
            let particle = Particle(position: float2(Float(arc4random() %  UInt32(side)), Float(arc4random() % UInt32(side))), velocity: float2((Float(arc4random() %  10) - 5) / 10, (Float(arc4random() %  10) - 5) / 10))
            particles.append(particle)
        }
        let size = particles.count * MemoryLayout<Particle>.size
        particleBuffer = device.makeBuffer(bytes: &particles, length: size, options: [])
    }
    
    func initializeMetal() {
        device = MTLCreateSystemDefaultDevice()
        queue = device.makeCommandQueue()
        guard let path = Bundle.main.path(forResource: "Shaders", ofType: "metal") else { return }
        do {
            let input = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
            let library = try device.makeLibrary(source: input, options: nil)
            guard let firstPass = library.makeFunction(name: "firstPass") else { return }
            firstState = try device.makeComputePipelineState(function: firstPass)
            guard let secondPass = library.makeFunction(name: "secondPass") else { return }
            secondState = try device.makeComputePipelineState(function: secondPass)
        } catch let e { print(e) }
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        if let drawable = view.currentDrawable,
           let commandBuffer = queue.makeCommandBuffer(),
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            // first pass
            commandEncoder.setComputePipelineState(firstState)
            commandEncoder.setTexture(drawable.texture, index: 0)
            let w = firstState.threadExecutionWidth
            let h = firstState.maxTotalThreadsPerThreadgroup / w
            let threadsPerGroup = MTLSizeMake(w, h, 1)
            var threadsPerGrid = MTLSizeMake(side, side, 1)
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            // second pass
            commandEncoder.setComputePipelineState(secondState)
            commandEncoder.setTexture(drawable.texture, index: 0)
            commandEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            threadsPerGrid = MTLSizeMake(particleCount, 1, 1)
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
