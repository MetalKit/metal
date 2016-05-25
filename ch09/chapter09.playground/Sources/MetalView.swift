
import MetalKit

public class MetalView: MTKView {
    
    var vertex_buffer: MTLBuffer!
    var uniform_buffer: MTLBuffer!
    var index_buffer: MTLBuffer!
    var dss: MTLDepthStencilState!
    var rps: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var rotation: Float = 0
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        createBuffers()
        createPipeline()
    }
     
    func createBuffers() {
        let vertex_data = [
            Vertex(pos: [-1.0, -1.0,  1.0, 1.0], col: [1, 1, 1, 1]),
            Vertex(pos: [ 1.0, -1.0,  1.0, 1.0], col: [1, 0, 0, 1]),
            Vertex(pos: [ 1.0,  1.0,  1.0, 1.0], col: [1, 1, 0, 1]),
            Vertex(pos: [-1.0,  1.0,  1.0, 1.0], col: [0, 1, 0, 1]),
            Vertex(pos: [-1.0, -1.0, -1.0, 1.0], col: [0, 0, 1, 1]),
            Vertex(pos: [ 1.0, -1.0, -1.0, 1.0], col: [1, 0, 1, 1]),
            Vertex(pos: [ 1.0,  1.0, -1.0, 1.0], col: [0, 0, 0, 1]),
            Vertex(pos: [-1.0,  1.0, -1.0, 1.0], col: [0, 1, 1, 1])
        ]
        let index_data: [UInt16] = [
            0, 1, 2, 2, 3, 0,   // front
            1, 5, 6, 6, 2, 1,   // right
            3, 2, 6, 6, 7, 3,   // top
            4, 5, 1, 1, 0, 4,   // bottom
            4, 0, 3, 3, 7, 4,   // left
            7, 6, 5, 5, 4, 7,   // back
        ]
        vertex_buffer = device!.newBufferWithBytes(vertex_data, length: sizeof(Vertex) * vertex_data.count, options: [])
        index_buffer = device!.newBufferWithBytes(index_data, length: sizeof(UInt16) * index_data.count , options: [])
        uniform_buffer = device!.newBufferWithLength(sizeof(matrix_float4x4), options: [])
    }
    
    func createPipeline() {
        do {
            let path = NSBundle.mainBundle().pathForResource("Shaders", ofType: "metal")
            let input = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
            let library = try device!.newLibraryWithSource(input, options: nil)
            let vert_func = library.newFunctionWithName("vertex_func")!
            let frag_func = library.newFunctionWithName("fragment_func")!
            let rpld = MTLRenderPipelineDescriptor()
            rpld.vertexFunction = vert_func
            rpld.fragmentFunction = frag_func
            rpld.colorAttachments[0].pixelFormat = .BGRA8Unorm
            rps = try device!.newRenderPipelineStateWithDescriptor(rpld)
        } catch let e {
            Swift.print("\(e)")
        }
        commandQueue = device?.newCommandQueue()
    }
    
    func update() {
        let scaled = scalingMatrix(0.5)
        rotation += 1 / 100 * Float(M_PI) / 4
        let rotatedY = rotationMatrix(rotation, float3(0, 1, 0))
        let rotatedX = rotationMatrix(Float(M_PI) / 4, float3(1, 0, 0))
        let modelMatrix = matrix_multiply(matrix_multiply(rotatedX, rotatedY), scaled)
        let cameraPosition = vector_float3(0, 0, -3)
        let viewMatrix = translationMatrix(cameraPosition)
        let aspect = Float(drawableSize.width / drawableSize.height)
        let projMatrix = projectionMatrix(0, far: 10, aspect: aspect, fovy: 1)
        let modelViewProjectionMatrix = matrix_multiply(projMatrix, matrix_multiply(viewMatrix, modelMatrix))
        let bufferPointer = uniform_buffer.contents()
        var uniforms = Uniforms(modelViewProjectionMatrix: modelViewProjectionMatrix)
        memcpy(bufferPointer, &uniforms, sizeof(Uniforms))
    }
    
    override public func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        update()
        if let rpd = currentRenderPassDescriptor, drawable = currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.3, 0.5, 0.5, 1.0)
            let command_buffer = commandQueue.commandBuffer()
            let command_encoder = command_buffer.renderCommandEncoderWithDescriptor(rpd)
            command_encoder.setRenderPipelineState(rps)
            command_encoder.setFrontFacingWinding(.CounterClockwise)
            command_encoder.setCullMode(.Back)
            command_encoder.setVertexBuffer(vertex_buffer, offset: 0, atIndex: 0)
            command_encoder.setVertexBuffer(uniform_buffer, offset: 0, atIndex: 1)
            command_encoder.drawIndexedPrimitives(.Triangle, indexCount: index_buffer.length / sizeof(UInt16), indexType: MTLIndexType.UInt16, indexBuffer: index_buffer, indexBufferOffset: 0)
            command_encoder.endEncoding()
            command_buffer.presentDrawable(drawable)
            command_buffer.commit()
        }
    }
}
