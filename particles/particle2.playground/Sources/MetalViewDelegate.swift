
import MetalKit

public class MetalViewDelegate: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice!
    var queue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var model: MTKMesh!
    var particles: [Particle]!
    var particlesBuffer: MTLBuffer!
    var timer: Float = 0
    
    struct Particle {
        var initialMatrix = matrix_identity_float4x4
        var matrix = matrix_identity_float4x4
        var color = float4()
    }
    
    override public init() {
        super.init()
        initializeMetal()
    }
    
    func initializeBuffers() {
        particles = [Particle](repeatElement(Particle(), count: 1000))
        particlesBuffer = device.makeBuffer(length: particles.count * MemoryLayout<Particle>.stride, options: [])!
        var pointer = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particles.count)
        for _ in particles {
            pointer.pointee.initialMatrix = translate(by: [Float(drand48()) / 10, Float(drand48()) * 10, 0])
            pointer.pointee.color = float4(0.2, 0.6, 0.9, 1)
            pointer = pointer.advanced(by: 1)
        }
        let allocator = MTKMeshBufferAllocator(device: device)
        let sphere = MDLMesh(sphereWithExtent: [0.01, 0.01, 0.01], segments: [8, 8], inwardNormals: false, geometryType: .triangles, allocator: allocator)
        do { model = try MTKMesh(mesh: sphere, device: device) } 
        catch let e { print(e) }
    }
    
    func initializeMetal() {
        device = MTLCreateSystemDefaultDevice()
        queue = device.makeCommandQueue()
        initializeBuffers()
        let library: MTLLibrary
        do {
            let path = Bundle.main.path(forResource: "Shaders", ofType: "metal")
            let source = try String(contentsOfFile: path!, encoding: .utf8)
            library = try device.makeLibrary(source: source, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
            descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(model.vertexDescriptor)
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch let error as NSError {
            fatalError("library error: " + error.description)
        }
    }
    
    func translate(by: float3) -> float4x4 {
        return float4x4(columns: (
            float4( 1,  0,  0,  0),
            float4( 0,  1,  0,  0),
            float4( 0,  0,  1,  0),
            float4( by.x,  by.y,  by.z,  1)
        ))
    }
    
    func update() {
        timer += 0.01
        var pointer = particlesBuffer.contents().bindMemory(to: Particle.self, capacity: particles.count)
        for _ in particles {
            pointer.pointee.matrix = translate(by: [0, -3 * timer, 0]) * pointer.pointee.initialMatrix
            pointer = pointer.advanced(by: 1)
        }
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {  }
    
    public func draw(in view: MTKView) {
        update()
        guard let commandBuffer = queue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let drawable = view.currentDrawable else { fatalError() }
        let submesh = model.submeshes[0]
        commandEncoder.setRenderPipelineState(pipelineState)
        commandEncoder.setVertexBuffer(model.vertexBuffers[0].buffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(particlesBuffer, offset: 0, index: 1)
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: 0, instanceCount: particles.count)
        commandEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
