
import MetalKit

public class MetalView: NSObject, MTKViewDelegate {
    
    public var device: MTLDevice!
    var queue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var rps: MTLRenderPipelineState!
    var rotation: Float = 0
    
    override public init() {
        super.init()
        device = MTLCreateSystemDefaultDevice()
        queue = device.newCommandQueue()
        createBuffers()
        createPipeline()
    }
     
    func createBuffers() {
        let vertexData = [
            Vertex(pos: [-1.0, -1.0,  1.0, 1.0], col: [1, 1, 1, 1]),
            Vertex(pos: [ 1.0, -1.0,  1.0, 1.0], col: [1, 0, 0, 1]),
            Vertex(pos: [ 1.0,  1.0,  1.0, 1.0], col: [1, 1, 0, 1]),
            Vertex(pos: [-1.0,  1.0,  1.0, 1.0], col: [0, 1, 0, 1]),
            Vertex(pos: [-1.0, -1.0, -1.0, 1.0], col: [0, 0, 1, 1]),
            Vertex(pos: [ 1.0, -1.0, -1.0, 1.0], col: [1, 0, 1, 1]),
            Vertex(pos: [ 1.0,  1.0, -1.0, 1.0], col: [0, 0, 0, 1]),
            Vertex(pos: [-1.0,  1.0, -1.0, 1.0], col: [0, 1, 1, 1])]
        
        let indexData: [UInt16] = [0, 1, 2, 2, 3, 0,   // front
                                   1, 5, 6, 6, 2, 1,   // right
                                   3, 2, 6, 6, 7, 3,   // top
                                   4, 5, 1, 1, 0, 4,   // bottom
                                   4, 0, 3, 3, 7, 4,   // left
                                   7, 6, 5, 5, 4, 7]   // back
        
        vertexBuffer = device!.newBuffer(withBytes: vertexData, length: sizeof(Vertex.self) * vertexData.count, options: [])
        indexBuffer = device!.newBuffer(withBytes: indexData, length: sizeof(UInt16.self) * indexData.count , options: [])
        uniformBuffer = device!.newBuffer(withLength: sizeof(matrix_float4x4.self), options: [])
    }
    
    func createPipeline() {
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
    
    func update() {
        let scaled = scalingMatrix(scale: 0.5)
        rotation += 1 / 100 * Float(M_PI) / 4
        let rotatedY = rotationMatrix(angle: rotation, axis: float3(0, 1, 0))
        let rotatedX = rotationMatrix(angle: Float(M_PI) / 4, axis: float3(1, 0, 0))
        let modelMatrix = matrix_multiply(matrix_multiply(rotatedX, rotatedY), scaled)
        let cameraPosition = vector_float3(0, 0, -3)
        let viewMatrix = translationMatrix(position: cameraPosition)
//        let aspect = Float(view.drawableSize.width / view.drawableSize.height)
        let projMatrix = projectionMatrix(near: 0, far: 10, aspect: 1, fovy: 1)
//        let projMatrix = projectionMatrix(0, far: 10, aspect: aspect, fovy: 1)
        let modelViewProjectionMatrix = matrix_multiply(projMatrix, matrix_multiply(viewMatrix, modelMatrix))
        let bufferPointer = uniformBuffer.contents()
        var uniforms = Uniforms(modelViewProjectionMatrix: modelViewProjectionMatrix)
        memcpy(bufferPointer, &uniforms, sizeof(Uniforms.self))
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    public func draw(in view: MTKView) {
        update()
        if let rpd = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            let commandBuffer = queue.commandBuffer()
            let commandEncoder = commandBuffer.renderCommandEncoder(with: rpd)
            commandEncoder.setRenderPipelineState(rps)
            commandEncoder.setFrontFacing(.counterClockwise)
            commandEncoder.setCullMode(.back)
            commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
            commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, at: 1)
            commandEncoder.drawIndexedPrimitives(.triangle, indexCount: indexBuffer.length / sizeof(UInt16.self), indexType: MTLIndexType.uInt16, indexBuffer: indexBuffer, indexBufferOffset: 0)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
