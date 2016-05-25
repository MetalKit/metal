
import MetalKit

public class MetalView: MTKView {
    
    var vertex_buffer: MTLBuffer!
    var uniform_buffer: MTLBuffer!
    var rps: MTLRenderPipelineState! = nil
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override public init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        createBuffers()
        registerShaders()
    }
    
    override public func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        if let rpd = currentRenderPassDescriptor, drawable = currentDrawable {
            rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1.0)
            let command_buffer = device!.newCommandQueue().commandBuffer()
            let command_encoder = command_buffer.renderCommandEncoderWithDescriptor(rpd)
            command_encoder.setRenderPipelineState(rps)
            command_encoder.setVertexBuffer(vertex_buffer, offset: 0, atIndex: 0)
            command_encoder.setVertexBuffer(uniform_buffer, offset: 0, atIndex: 1)
            command_encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 3, instanceCount: 1)
            command_encoder.endEncoding()
            command_buffer.presentDrawable(drawable)
            command_buffer.commit()
        }
    }
    
    func createBuffers() {
        let vertex_data = [
            Vertex(pos: [-1.0, -1.0, 0.0, 1.0], col: [1, 0, 0, 1]),
            Vertex(pos: [ 1.0, -1.0, 0.0, 1.0], col: [0, 1, 0, 1]),
            Vertex(pos: [ 0.0,  1.0, 0.0, 1.0], col: [0, 0, 1, 1])
        ]
        vertex_buffer = device!.newBufferWithBytes(vertex_data, length: sizeof(Vertex) * 3, options:[])
        uniform_buffer = device!.newBufferWithLength(sizeof(Float) * 16, options: [])
        let bufferPointer = uniform_buffer.contents()
        memcpy(bufferPointer, Matrix().modelMatrix(Matrix()).m, sizeof(Float) * 16)
    }
    
    func registerShaders() {
        let path = NSBundle.mainBundle().pathForResource("Shaders", ofType: "metal")
        let input: String?
        let library: MTLLibrary
        let vert_func: MTLFunction
        let frag_func: MTLFunction
        do {
            input = try String(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
            library = try device!.newLibraryWithSource(input!, options: nil)
            //print(library.functionNames)
            vert_func = library.newFunctionWithName("vertex_func")!
            frag_func = library.newFunctionWithName("fragment_func")!
            let rpld = MTLRenderPipelineDescriptor()
            rpld.vertexFunction = vert_func
            rpld.fragmentFunction = frag_func
            rpld.colorAttachments[0].pixelFormat = .BGRA8Unorm
            rps = try device!.newRenderPipelineStateWithDescriptor(rpld)
        } catch let e {
            Swift.print("\(e)")
        }
    }
}
