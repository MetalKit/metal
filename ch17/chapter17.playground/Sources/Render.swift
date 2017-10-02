
import MetalKit

public class Render : NSObject, MTKViewDelegate {
  
    weak var view: MTKView!
    let commandQueue: MTLCommandQueue!
    let renderPipelineState: MTLRenderPipelineState!
    let device: MTLDevice!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
  
    struct Vertex {
        var position: float4
        var color: float4
    }
  
    public init?(mtkView: MTKView) {
        view = mtkView
        view.clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1)
        view.colorPixelFormat = .bgra8Unorm
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        try! renderPipelineState = Render.buildRenderPipelineWithDevice(device: device, view: mtkView)
        
        var vertices = [Vertex]()
        vertices.append(Vertex(position: float4(-0.5, -0.5, 0, 1), color: float4(1, 0, 0, 1)))
        vertices.append(Vertex(position: float4( 0.5, -0.5, 0, 1), color: float4(0, 1, 0, 1)))
        vertices.append(Vertex(position: float4( 0.0,  0.5, 0, 1), color: float4(0, 0, 1, 1)))
        
        var indices = [UInt16]()
        indices.append(0)
        indices.append(1)
        indices.append(2)
        
        vertexBuffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<Vertex>.stride * vertices.count, options: [])
        indexBuffer = device.makeBuffer(bytes: indices, length: MemoryLayout<UInt16>.stride * indices.count, options: [])
        
        super.init()
        view.delegate = self
        view.device = device
    }
  
    class func buildRenderPipelineWithDevice(device: MTLDevice, view: MTKView) throws -> MTLRenderPipelineState {
        guard let path = Bundle.main.path(forResource: "Shaders", ofType: "metal") else { fatalError() }
        let input = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
        let library = try device.makeLibrary(source: input, options: nil)
        let vertexFunction = library.makeFunction(name: "vertex_transform")
        let fragmentFunction = library.makeFunction(name: "fragment_lighting")
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = view.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
  
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
  
    public func draw(in view: MTKView) {
        if let commandBuffer = commandQueue.makeCommandBuffer(),
           let renderPassDescriptor = view.currentRenderPassDescriptor,
           let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.setVertexBuffer(vertexBuffer, offset:0, index:0)
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setTriangleFillMode(.lines)
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 3, indexType: .uint16, indexBuffer: indexBuffer,indexBufferOffset: 0)
            renderEncoder.endEncoding()
            commandBuffer.present(view.currentDrawable!)
            commandBuffer.commit()
        }
    }
}
 
