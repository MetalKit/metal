
import MetalKit

public class MetalView: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice!
    var queue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var rps: MTLRenderPipelineState!
    
    override public init() {
        super.init()
        createBuffers()
        registerShaders()
    }
    
    func createBuffers() {
        device = MTLCreateSystemDefaultDevice()
        queue = device.newCommandQueue()
        let vertexData = [Vertex(pos: [-1.0, -1.0, 0.0, 1.0], col: [1, 0, 0, 1]),
                          Vertex(pos: [ 1.0, -1.0, 0.0, 1.0], col: [0, 1, 0, 1]),
                          Vertex(pos: [ 0.0,  1.0, 0.0, 1.0], col: [0, 0, 1, 1])
        ]
        vertexBuffer = device!.newBuffer(withBytes: vertexData, length: sizeof(Vertex.self) * 3, options:[])
        uniformBuffer = device!.newBuffer(withLength: sizeof(Float.self) * 16, options: [])
        let bufferPointer = uniformBuffer.contents()
        memcpy(bufferPointer, Matrix().modelMatrix(matrix: Matrix()).m, sizeof(Float.self) * 16)
    }
    
    func registerShaders() {
        let path = Bundle.main.pathForResource("Shaders", ofType: "metal")
        let input: String?
        let library: MTLLibrary
        let vert_func: MTLFunction
        let frag_func: MTLFunction
        do {
            input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
            library = try device!.newLibrary(withSource: input!, options: nil)
            vert_func = library.newFunction(withName: "vertex_func")!
            frag_func = library.newFunction(withName: "fragment_func")!
            let rpld = MTLRenderPipelineDescriptor()
            rpld.vertexFunction = vert_func
            rpld.fragmentFunction = frag_func
            rpld.colorAttachments[0].pixelFormat = .bgra8Unorm
            rps = try device!.newRenderPipelineState(with: rpld)
        } catch let e {
            Swift.print("\(e)")
        }
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        if let rpd = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            let commandBuffer = queue.commandBuffer()
            let commandEncoder = commandBuffer.renderCommandEncoder(with: rpd)
            commandEncoder.setRenderPipelineState(rps)
            commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
            commandEncoder.drawPrimitives(.triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
