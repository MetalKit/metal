
import MetalKit
import ARKit

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

let maxBuffersInFlight: Int = 3
let maxAnchorInstanceCount: Int = 64

class Renderer {
    
    let session: ARSession
    let device: MTLDevice
    var commandQueue: MTLCommandQueue!
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    var renderDestination: RenderDestinationProvider
    var sharedUniformBuffer: MTLBuffer!
    var anchorUniformBuffer: MTLBuffer!
    var debugUniformBuffer: MTLBuffer!
    var imagePlaneVertexBuffer: MTLBuffer!
    var capturedImagePipelineState: MTLRenderPipelineState!
    var capturedImageDepthState: MTLDepthStencilState!
    var anchorPipelineState: MTLRenderPipelineState!
    var anchorDepthState: MTLDepthStencilState!
    var debugPipelineState: MTLRenderPipelineState!
    var debugDepthState: MTLDepthStencilState!
    var capturedImageTextureY: MTLTexture!
    var capturedImageTextureCbCr: MTLTexture!
    var capturedImageTextureCache: CVMetalTextureCache!
    var geometryVertexDescriptor: MTLVertexDescriptor!
    var mesh: MTKMesh!
    var debugMesh: MTKMesh!
    var uniformBufferIndex: Int = 0
    var sharedUniformBufferOffset: Int = 0
    var anchorUniformBufferOffset: Int = 0
    var debugUniformBufferOffset: Int = 0
    var sharedUniformBufferAddress: UnsafeMutableRawPointer!
    var anchorUniformBufferAddress: UnsafeMutableRawPointer!
    var debugUniformBufferAddress: UnsafeMutableRawPointer!
    var debugInstanceCount: Int = 0
    var anchorInstanceCount: Int = 0
    var viewportSize: CGSize = CGSize()
    var viewportSizeDidChange: Bool = false
    
    struct SharedUniforms {
        var projectionMatrix: matrix_float4x4
        var viewMatrix: matrix_float4x4
        var ambientLightColor: vector_float3
        var directionalLightDirection: vector_float3
        var directionalLightColor: vector_float3
        var materialShininess: Float
    }
    
    struct InstanceUniforms {
        var modelMatrix: matrix_float4x4
    }
    
    let alignedSharedUniformSize = (MemoryLayout<SharedUniforms>.size & ~0xFF) + 0x100
    let alignedInstanceUniformSize = ((MemoryLayout<InstanceUniforms>.size * maxAnchorInstanceCount) & ~0xFF) + 0x100
    let planeVertexData: [Float] = [-1, -1,  0,  1,
                                     1, -1,  1,  1,
                                    -1,  1,  0,  0,
                                     1,  1,  1,  0]
    
    init(session: ARSession, metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider) {
        self.session = session
        self.device = device
        self.renderDestination = renderDestination
        setupPipeline()
        setupAssets()
    }
    
    func setupPipeline() {
        renderDestination.depthStencilPixelFormat = .depth32Float_stencil8
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1
        let sharedUniformBufferSize = alignedSharedUniformSize * maxBuffersInFlight
        let anchorUniformBufferSize = alignedInstanceUniformSize * maxBuffersInFlight
        sharedUniformBuffer = device.makeBuffer(length: sharedUniformBufferSize, options: .storageModeShared)
        anchorUniformBuffer = device.makeBuffer(length: anchorUniformBufferSize, options: .storageModeShared)
        debugUniformBuffer = device.makeBuffer(length: anchorUniformBufferSize, options: .storageModeShared)
        let imagePlaneVertexDataCount = planeVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = device.makeBuffer(bytes: planeVertexData, length: imagePlaneVertexDataCount, options: [])
        let defaultLibrary = device.makeDefaultLibrary()!
        let capturedImageVertexFunction = defaultLibrary.makeFunction(name: "capturedImageVertexTransform")!
        let capturedImageFragmentFunction = defaultLibrary.makeFunction(name: "capturedImageFragmentShader")!
        let imagePlaneVertexDescriptor = MTLVertexDescriptor()
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = 0
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = 0
        imagePlaneVertexDescriptor.layouts[0].stride = 16
        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex
        let capturedImagePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        capturedImagePipelineStateDescriptor.label = "MyCapturedImagePipeline"
        capturedImagePipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction
        capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction
        capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        do { try capturedImagePipelineState = device.makeRenderPipelineState(descriptor: capturedImagePipelineStateDescriptor) }
        catch let error { print("Failed to created captured image pipeline state, error \(error)") }
        let capturedImageDepthStateDescriptor = MTLDepthStencilDescriptor()
        capturedImageDepthStateDescriptor.depthCompareFunction = .always
        capturedImageDepthStateDescriptor.isDepthWriteEnabled = false
        capturedImageDepthState = device.makeDepthStencilState(descriptor: capturedImageDepthStateDescriptor)
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        capturedImageTextureCache = textureCache
        let anchorGeometryVertexFunction = defaultLibrary.makeFunction(name: "anchorGeometryVertexTransform")!
        let anchorGeometryFragmentFunction = defaultLibrary.makeFunction(name: "anchorGeometryFragmentLighting")!
        geometryVertexDescriptor = MTLVertexDescriptor()
        geometryVertexDescriptor.attributes[0].format = .float3
        geometryVertexDescriptor.attributes[0].offset = 0
        geometryVertexDescriptor.attributes[0].bufferIndex = 0
        geometryVertexDescriptor.attributes[1].format = .float2
        geometryVertexDescriptor.attributes[1].offset = 0
        geometryVertexDescriptor.attributes[1].bufferIndex = 1
        geometryVertexDescriptor.attributes[2].format = .half3
        geometryVertexDescriptor.attributes[2].offset = 8
        geometryVertexDescriptor.attributes[2].bufferIndex = 1
        geometryVertexDescriptor.layouts[0].stride = 12
        geometryVertexDescriptor.layouts[0].stepRate = 1
        geometryVertexDescriptor.layouts[0].stepFunction = .perVertex
        geometryVertexDescriptor.layouts[1].stride = 16
        geometryVertexDescriptor.layouts[1].stepRate = 1
        geometryVertexDescriptor.layouts[1].stepFunction = .perVertex
        let anchorPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        anchorPipelineStateDescriptor.label = "MyAnchorPipeline"
        anchorPipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        anchorPipelineStateDescriptor.vertexFunction = anchorGeometryVertexFunction
        anchorPipelineStateDescriptor.fragmentFunction = anchorGeometryFragmentFunction
        anchorPipelineStateDescriptor.vertexDescriptor = geometryVertexDescriptor
        anchorPipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        anchorPipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        anchorPipelineStateDescriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        do { try anchorPipelineState = device.makeRenderPipelineState(descriptor: anchorPipelineStateDescriptor) }
        catch let error { print("Failed to created anchor geometry pipeline state, error \(error)") }
        let anchorDepthStateDescriptor = MTLDepthStencilDescriptor()
        anchorDepthStateDescriptor.depthCompareFunction = .less
        anchorDepthStateDescriptor.isDepthWriteEnabled = true
        anchorDepthState = device.makeDepthStencilState(descriptor: anchorDepthStateDescriptor)
        let debugGeometryVertexFunction = defaultLibrary.makeFunction(name: "vertexDebugPlane")!
        let debugGeometryFragmentFunction = defaultLibrary.makeFunction(name: "fragmentDebugPlane")!
        anchorPipelineStateDescriptor.vertexFunction =  debugGeometryVertexFunction
        anchorPipelineStateDescriptor.fragmentFunction = debugGeometryFragmentFunction
        do { try debugPipelineState = device.makeRenderPipelineState(descriptor: anchorPipelineStateDescriptor)
        } catch let error { print(error) }
        debugDepthState = device.makeDepthStencilState(descriptor: anchorDepthStateDescriptor)
        commandQueue = device.makeCommandQueue()
    }
    
    func setupAssets() {
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        let vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(geometryVertexDescriptor)
        (vertexDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (vertexDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        (vertexDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        var mdlMesh = MDLMesh(boxWithExtent: vector3(0.075, 0.075, 0.075), segments: vector3(1, 1, 1), inwardNormals: false, geometryType: .triangles, allocator: metalAllocator)
        mdlMesh.vertexDescriptor = vertexDescriptor
        do { try mesh = MTKMesh(mesh: mdlMesh, device: device) }
        catch let error { print("Error creating MetalKit mesh, error \(error)") }
        mdlMesh = MDLMesh(planeWithExtent: vector3(0.1, 0.1, 0.1), segments: vector2(1, 1), geometryType: .triangles, allocator: metalAllocator)
        mdlMesh.vertexDescriptor = vertexDescriptor
        do { try debugMesh = MTKMesh(mesh: mdlMesh, device: device)
        } catch let error { print(error) }
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }
    
    func update() {
        let _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self { strongSelf.inFlightSemaphore.signal() }
            return
        }
        updateBufferStates()
        updateGameState()
        guard let passDescriptor = renderDestination.currentRenderPassDescriptor,
            let drawable = renderDestination.currentDrawable else { return }
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        drawCapturedImage(renderEncoder: renderEncoder)
        drawAnchorGeometry(renderEncoder: renderEncoder)
        drawDebugGeometry(renderEncoder: renderEncoder)
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func updateBufferStates() {
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        sharedUniformBufferOffset = alignedSharedUniformSize * uniformBufferIndex
        anchorUniformBufferOffset = alignedInstanceUniformSize * uniformBufferIndex
        sharedUniformBufferAddress = sharedUniformBuffer.contents().advanced(by: sharedUniformBufferOffset)
        anchorUniformBufferAddress = anchorUniformBuffer.contents().advanced(by: anchorUniformBufferOffset)
        debugUniformBufferOffset = alignedInstanceUniformSize * uniformBufferIndex
        debugUniformBufferAddress = debugUniformBuffer.contents().advanced(by: debugUniformBufferOffset)
    }
    
    func updateGameState() {
        guard let currentFrame = session.currentFrame else { return }
        updateSharedUniforms(frame: currentFrame)
        updateAnchors(frame: currentFrame)
        updateCapturedImageTextures(frame: currentFrame)
        if viewportSizeDidChange {
            viewportSizeDidChange = false
            updateImagePlane(frame: currentFrame)
        }
    }
    
    func updateSharedUniforms(frame: ARFrame) {
        let uniforms = sharedUniformBufferAddress.assumingMemoryBound(to: SharedUniforms.self)
        uniforms.pointee.viewMatrix = simd_inverse(frame.camera.transform)
        uniforms.pointee.projectionMatrix = frame.camera.projectionMatrix(for: .landscapeRight, viewportSize: viewportSize, zNear: 0.001, zFar: 1000)
        var ambientIntensity: Float = 1.0
        if let lightEstimate = frame.lightEstimate {
            ambientIntensity = Float(lightEstimate.ambientIntensity) / 1000.0
        }
        let ambientLightColor: vector_float3 = vector3(0.5, 0.5, 0.5)
        uniforms.pointee.ambientLightColor = ambientLightColor * ambientIntensity
        var directionalLightDirection : vector_float3 = vector3(0.0, 0.0, -1.0)
        directionalLightDirection = simd_normalize(directionalLightDirection)
        uniforms.pointee.directionalLightDirection = directionalLightDirection
        let directionalLightColor: vector_float3 = vector3(0.6, 0.6, 0.6)
        uniforms.pointee.directionalLightColor = directionalLightColor * ambientIntensity
        uniforms.pointee.materialShininess = 30
    }
    
    func updateAnchors(frame: ARFrame) {
        anchorInstanceCount = min(frame.anchors.count, maxAnchorInstanceCount)
        var anchorOffset: Int = 0
        if anchorInstanceCount == maxAnchorInstanceCount {
            anchorOffset = max(frame.anchors.count - maxAnchorInstanceCount, 0)
        }
        let count = frame.anchors.filter{ $0.isKind(of: ARPlaneAnchor.self) }.count
        debugInstanceCount = min(count, maxAnchorInstanceCount - (anchorInstanceCount - count))
        for index in 0..<anchorInstanceCount {
            let anchor = frame.anchors[index + anchorOffset]
            var coordinateSpaceTransform = matrix_identity_float4x4
            coordinateSpaceTransform.columns.2.z = -1.0 // flip Z axis to convert to left handed
            if anchor.isKind(of: ARPlaneAnchor.self) {
                let transform = anchor.transform * rotationMatrix(rotation: float3(0, 0, Float.pi/2))
                let modelMatrix = simd_mul(transform, coordinateSpaceTransform)
                let debugUniforms = debugUniformBufferAddress.assumingMemoryBound(to: InstanceUniforms.self).advanced(by: index)
                debugUniforms.pointee.modelMatrix = modelMatrix
            } else {
                let modelMatrix = simd_mul(anchor.transform, coordinateSpaceTransform)
                let anchorUniforms = anchorUniformBufferAddress.assumingMemoryBound(to: InstanceUniforms.self).advanced(by: index)
                anchorUniforms.pointee.modelMatrix = modelMatrix
            }
        }
    }
    
    func rotationMatrix(rotation: float3) -> float4x4 {
        var matrix: float4x4 = matrix_identity_float4x4
        let x = rotation.x
        let y = rotation.y
        let z = rotation.z
        matrix.columns.0.x = cos(y) * cos(z)
        matrix.columns.0.y = cos(z) * sin(x) * sin(y) - cos(x) * sin(z)
        matrix.columns.0.z = cos(x) * cos(z) * sin(y) + sin(x) * sin(z)
        matrix.columns.1.x = cos(y) * sin(z)
        matrix.columns.1.y = cos(x) * cos(z) + sin(x) * sin(y) * sin(z)
        matrix.columns.1.z = -cos(z) * sin(x) + cos(x) * sin(y) * sin(z)
        matrix.columns.2.x = -sin(y)
        matrix.columns.2.y = cos(y) * sin(x)
        matrix.columns.2.z = cos(x) * cos(y)
        matrix.columns.3.w = 1.0
        return matrix
    }
    
    func updateCapturedImageTextures(frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) { return }
        capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.r8Unorm, planeIndex:0)!
        capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.rg8Unorm, planeIndex:1)!
    }
    
    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
        var mtlTexture: MTLTexture? = nil
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        if status == kCVReturnSuccess { mtlTexture = CVMetalTextureGetTexture(texture!) }
        return mtlTexture
    }
    
    func updateImagePlane(frame: ARFrame) {
        let displayToCameraTransform = frame.displayTransform(for: .landscapeRight, viewportSize: viewportSize).inverted()
        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(planeVertexData[textureCoordIndex]), y: CGFloat(planeVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }
    
    func drawCapturedImage(renderEncoder: MTLRenderCommandEncoder) {
        guard capturedImageTextureY != nil && capturedImageTextureCbCr != nil else { return }
        renderEncoder.pushDebugGroup("DrawCapturedImage")
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(capturedImagePipelineState)
        renderEncoder.setDepthStencilState(capturedImageDepthState)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(capturedImageTextureY, index: 1)
        renderEncoder.setFragmentTexture(capturedImageTextureCbCr, index: 2)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
    }
    
    func drawAnchorGeometry(renderEncoder: MTLRenderCommandEncoder) {
        guard anchorInstanceCount - debugInstanceCount > 0 else { return }
        renderEncoder.pushDebugGroup("DrawAnchors")
        renderEncoder.setCullMode(.back)
        renderEncoder.setRenderPipelineState(anchorPipelineState)
        renderEncoder.setDepthStencilState(anchorDepthState)
        renderEncoder.setVertexBuffer(anchorUniformBuffer, offset: anchorUniformBufferOffset, index: 2)
        renderEncoder.setVertexBuffer(sharedUniformBuffer, offset: sharedUniformBufferOffset, index: 3)
        renderEncoder.setFragmentBuffer(sharedUniformBuffer, offset: sharedUniformBufferOffset, index: 3)
        for bufferIndex in 0..<mesh.vertexBuffers.count {
            let vertexBuffer = mesh.vertexBuffers[bufferIndex]
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index:bufferIndex)
        }
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset, instanceCount: anchorInstanceCount)
        }
        renderEncoder.popDebugGroup()
    }
    
    func drawDebugGeometry(renderEncoder: MTLRenderCommandEncoder) {
        guard debugInstanceCount > 0 else { return }
        renderEncoder.pushDebugGroup("DrawDebugPlanes")
        renderEncoder.setCullMode(.back)
        renderEncoder.setRenderPipelineState(debugPipelineState)
        renderEncoder.setDepthStencilState(debugDepthState)
        renderEncoder.setVertexBuffer(debugUniformBuffer, offset: debugUniformBufferOffset, index: 2)
        renderEncoder.setVertexBuffer(sharedUniformBuffer, offset: sharedUniformBufferOffset, index: 3)
        renderEncoder.setFragmentBuffer(sharedUniformBuffer, offset: sharedUniformBufferOffset, index: 3)
        for bufferIndex in 0..<debugMesh.vertexBuffers.count {
            let vertexBuffer = debugMesh.vertexBuffers[bufferIndex]
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index:bufferIndex)
        }
        for submesh in debugMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset, instanceCount: debugInstanceCount)
        }
        renderEncoder.popDebugGroup()
    }
}
