//
//  Renderer.swift
//
//  Created by Marius Horga on 7/7/18.
//

import MetalKit
import MetalPerformanceShaders

class Renderer: NSObject {
  
  let device: MTLDevice!
  let queue: MTLCommandQueue!
  var rayPipeline: MTLComputePipelineState!
  var shadePipeline: MTLComputePipelineState!
  var shadowPipeline: MTLComputePipelineState!
  var accumulatePipeline: MTLComputePipelineState!
  var copyPipeline: MTLRenderPipelineState!
  
  let maxFramesInFlight = 3
  let alignedUniformsSize = (MemoryLayout<Uniforms>.stride + 255) & ~255
  let rayStride = 48 // shouldn't be hardcoded... if possible
  let intersectionStride = MemoryLayout<MPSIntersectionDistancePrimitiveIndexCoordinates>.stride
  
  var accelerationStructure: MPSTriangleAccelerationStructure!
  var intersector: MPSRayIntersector!
  
  var vertexPositionBuffer: MTLBuffer!
  var vertexNormalBuffer: MTLBuffer!
  var vertexColorBuffer: MTLBuffer!
  var rayBuffer: MTLBuffer!
  var shadowRayBuffer: MTLBuffer!
  var intersectionBuffer: MTLBuffer!
  var uniformBuffer: MTLBuffer!
  var randomBuffer: MTLBuffer!
  var triangleMaskBuffer: MTLBuffer!
  
  var renderTarget: MTLTexture!
  var accumulationTarget: MTLTexture!
  
  var semaphore: DispatchSemaphore!
  var size: CGSize!
  var randomBufferOffset: Int!
  var uniformBufferOffset: Int!
  var uniformBufferIndex: Int = 0
  var frameIndex: uint!
  
  init?(metalKitView: MTKView) {
    metalKitView.colorPixelFormat = .rgba16Float
    metalKitView.sampleCount = 1
    metalKitView.drawableSize = metalKitView.frame.size
    guard let device = metalKitView.device else {
      return nil
    }
    self.device = device
    queue = self.device.makeCommandQueue()
    super.init()
    
    semaphore = DispatchSemaphore.init(value: maxFramesInFlight)
    
    createPipelines(device: self.device, view: metalKitView)
    createScene()
    createBuffers()
    createIntersector()
    mtkView(metalKitView, drawableSizeWillChange: metalKitView.frame.size)
  }
  
  func createPipelines(device: MTLDevice, view: MTKView) {
    guard let library = device.makeDefaultLibrary() else {
      return
    }
    
    let computeDescriptor = MTLComputePipelineDescriptor()
    computeDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
    
    let vertexFunction = library.makeFunction(name: "vertexShader")
    let fragmentFunction = library.makeFunction(name: "fragmentShader")
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.sampleCount = view.sampleCount
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    
    do {
      computeDescriptor.computeFunction = library.makeFunction(name: "rayKernel")
      rayPipeline = try device.makeComputePipelineState(descriptor: computeDescriptor, options: [], reflection: nil)
      computeDescriptor.computeFunction = library.makeFunction(name: "shadeKernel")
      shadePipeline = try device.makeComputePipelineState(descriptor: computeDescriptor, options: [], reflection: nil)
      computeDescriptor.computeFunction = library.makeFunction(name: "shadowKernel")
      shadowPipeline = try device.makeComputePipelineState(descriptor: computeDescriptor, options: [], reflection: nil)
      computeDescriptor.computeFunction = library.makeFunction(name: "accumulateKernel")
      accumulatePipeline = try device.makeComputePipelineState(descriptor: computeDescriptor, options: [], reflection: nil)
      
      copyPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error {
      print(error.localizedDescription)
    }
  }
  
  func createScene() {
    // light source
    var transform = translate(tx: 0, ty: 1, tz: 0) * scale(sx: 0.5, sy: 1.98, sz: 0.5)
    createCube(faceMask: .positiveY, color: float3(1), transform: transform, inwardNormals: true, triangleMask: TRIANGLE_MASK_LIGHT)
    // top, bottom and back walls
    transform = translate(tx: 0, ty: 1, tz: 0) * scale(sx: 2, sy: 2, sz: 2)
    createCube(faceMask: [.negativeY, .positiveY, .negativeZ], color: float3(0.725, 0.71, 0.68), transform: transform, inwardNormals: true, triangleMask: TRIANGLE_MASK_GEOMETRY)
    // left wall
    createCube(faceMask: .negativeX, color: float3(0.63, 0.065, 0.05), transform: transform, inwardNormals: true, triangleMask: TRIANGLE_MASK_GEOMETRY)
    // right wall
    createCube(faceMask: .positiveX, color: float3(0.14, 0.45, 0.091), transform: transform, inwardNormals: true, triangleMask: TRIANGLE_MASK_GEOMETRY)
    // short box
    transform = translate(tx: 0.3275, ty: 0.3, tz: 0.3725) * rotate(radians: -0.3, axis: float3(0.0, 1.0, 0.0)) * scale(sx: 0.6, sy: 0.6, sz: 0.6)
    createCube(faceMask: .all, color: float3(0.725, 0.71, 0.68), transform: transform, inwardNormals: false, triangleMask: TRIANGLE_MASK_GEOMETRY)
    // tall box
    transform = translate(tx: -0.335, ty: 0.6, tz: -0.29) * rotate(radians: 0.3, axis: float3(0.0, 1.0, 0.0)) * scale(sx: 0.6, sy: 1.2, sz: 0.6)
    createCube(faceMask: .all, color: float3(0.725, 0.71, 0.68), transform: transform, inwardNormals: false, triangleMask: TRIANGLE_MASK_GEOMETRY)
  }
  
  func createBuffers() {
    let uniformBufferSize = alignedUniformsSize * maxFramesInFlight
    uniformBuffer = device.makeBuffer(length: uniformBufferSize, options: .storageModeManaged)
    randomBuffer = device.makeBuffer(length: 256 * MemoryLayout<float2>.stride * maxFramesInFlight, options: .storageModeManaged)
    
    vertexPositionBuffer = device.makeBuffer(bytes: &vertices, length: vertices.count * MemoryLayout<float3>.stride, options: .storageModeManaged)
    vertexColorBuffer = device.makeBuffer(bytes: &colors, length: colors.count * MemoryLayout<float3>.stride, options: .storageModeManaged)
    vertexNormalBuffer = device.makeBuffer(bytes: &normals, length: normals.count * MemoryLayout<float3>.stride, options: .storageModeManaged)
    triangleMaskBuffer = device.makeBuffer(bytes: &masks, length: masks.count * MemoryLayout<uint>.stride, options: .storageModeManaged)
    
    vertexPositionBuffer?.didModifyRange(0..<(vertexPositionBuffer?.length)!)
    vertexColorBuffer?.didModifyRange(0..<(vertexColorBuffer?.length)!)
    vertexNormalBuffer?.didModifyRange(0..<(vertexNormalBuffer?.length)!)
    triangleMaskBuffer?.didModifyRange(0..<(triangleMaskBuffer?.length)!)
  }
  
  func createIntersector() {
    intersector = MPSRayIntersector(device: device)
    intersector?.rayDataType = .originMaskDirectionMaxDistance
    intersector?.rayStride = rayStride
    intersector?.rayMaskOptions = .primitive
    
    accelerationStructure = MPSTriangleAccelerationStructure(device: device)
    accelerationStructure?.vertexBuffer = vertexPositionBuffer
    accelerationStructure?.maskBuffer = triangleMaskBuffer
    accelerationStructure?.triangleCount = vertices.count / 3
    accelerationStructure?.rebuild()
  }
  
  func updateUniforms() {
    uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
    let pointer = uniformBuffer!.contents().advanced(by: uniformBufferOffset)
    let uniforms = pointer.bindMemory(to: Uniforms.self, capacity: 1)
    uniforms.pointee.camera.position = float3(0.0, 1.0, 3.38)
    uniforms.pointee.camera.forward = float3(0.0, 0.0, -1.0)
    uniforms.pointee.camera.right = float3(1.0, 0.0, 0.0)
    uniforms.pointee.camera.up = float3(0.0, 1.0, 0.0)
    uniforms.pointee.light.position = float3(0.0, 1.98, 0.0)
    uniforms.pointee.light.forward = float3(0.0, -1.0, 0.0)
    uniforms.pointee.light.right = float3(0.25, 0.0, 0.0)
    uniforms.pointee.light.up = float3(0.0, 0.0, 0.25)
    uniforms.pointee.light.color = float3(4.0, 4.0, 4.0)
    
    let fieldOfView = 45.0 * (Float.pi / 180.0)
    let aspectRatio = Float(size.width) / Float(size.height)
    let imagePlaneHeight = tanf(fieldOfView / 2.0)
    let imagePlaneWidth = aspectRatio * imagePlaneHeight
    
    uniforms.pointee.camera.right *= imagePlaneWidth
    uniforms.pointee.camera.up *= imagePlaneHeight
    uniforms.pointee.width = uint(size.width)
    uniforms.pointee.height = uint(size.height)
    uniforms.pointee.blocksWide = (uniforms.pointee.width + 15) / 16
    uniforms.pointee.frameIndex = frameIndex
    frameIndex += 1
    uniformBuffer?.didModifyRange(uniformBufferOffset..<(uniformBufferOffset + alignedUniformsSize))
    randomBufferOffset = 256 * MemoryLayout<float2>.stride * uniformBufferIndex
    let p = randomBuffer!.contents().advanced(by: randomBufferOffset)
    var random = p.bindMemory(to: float2.self, capacity: 1)
    for _ in 0..<256 {
      random.pointee = float2(Float(drand48()), Float(drand48()) )
      random = random.advanced(by: 1)
    }
    randomBuffer?.didModifyRange(randomBufferOffset..<(randomBufferOffset + 256 * MemoryLayout<float2>.stride))
    uniformBufferIndex = (uniformBufferIndex + 1) % maxFramesInFlight
  }
}

extension Renderer: MTKViewDelegate {
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    self.size = size
    let rayCount = Int(size.width * size.height)
    rayBuffer = device.makeBuffer(length: rayStride * rayCount,  options: .storageModePrivate)
    shadowRayBuffer = device.makeBuffer(length: rayStride * rayCount, options: .storageModePrivate)
    intersectionBuffer = device.makeBuffer(length: intersectionStride * rayCount, options: .storageModePrivate)
    
    let renderTargetDescriptor = MTLTextureDescriptor()
    renderTargetDescriptor.pixelFormat = .rgba32Float
    renderTargetDescriptor.textureType = .type2D
    renderTargetDescriptor.width = Int(size.width)
    renderTargetDescriptor.height = Int(size.height)
    renderTargetDescriptor.storageMode = .private
    renderTargetDescriptor.usage = [.shaderRead, .shaderWrite]
    renderTarget = device.makeTexture(descriptor: renderTargetDescriptor)
    accumulationTarget = device.makeTexture(descriptor: renderTargetDescriptor)
    frameIndex = 0
  }
  
  func draw(in view: MTKView) {
    semaphore.wait()
    guard let commandBuffer = queue.makeCommandBuffer() else {
      return
    }
    commandBuffer.addCompletedHandler { cb in
      self.semaphore.signal()
    }
    
    updateUniforms()
    
    let width = Int(size.width)
    let height = Int(size.height)
    let threadsPerThreadgroup = MTLSizeMake(8, 8, 1)
    let threadgroups = MTLSizeMake(
      (width + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
      (height + threadsPerThreadgroup.height - 1) / threadsPerThreadgroup.height,
      1)
    
    // 1st compute pipeline - Primary Rays
    var computeEncoder = commandBuffer.makeComputeCommandEncoder()
    computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset, index: 0)
    computeEncoder?.setBuffer(rayBuffer, offset: 0, index: 1)
    computeEncoder?.setBuffer(randomBuffer, offset: randomBufferOffset, index: 2)
    computeEncoder?.setTexture(renderTarget, index: 0)
    computeEncoder?.setComputePipelineState(rayPipeline!)
    computeEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
    computeEncoder?.endEncoding()
    // 2nd and 3rd compute pipelines
    for _ in 0..<3 {
      // Shade pipeline
      intersector?.intersectionDataType = .distancePrimitiveIndexCoordinates
      intersector?.encodeIntersection(commandBuffer: commandBuffer,
                                      intersectionType: .nearest,
                                      rayBuffer: rayBuffer!,
                                      rayBufferOffset: 0,
                                      intersectionBuffer: intersectionBuffer!,
                                      intersectionBufferOffset: 0,
                                      rayCount: width * height,
                                      accelerationStructure: accelerationStructure!)
      computeEncoder = commandBuffer.makeComputeCommandEncoder()
      computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset, index: 0)
      computeEncoder?.setBuffer(rayBuffer, offset: 0, index: 1)
      computeEncoder?.setBuffer(shadowRayBuffer, offset: 0, index: 2)
      computeEncoder?.setBuffer(intersectionBuffer, offset: 0, index: 3)
      computeEncoder?.setBuffer(vertexColorBuffer, offset: 0, index: 4)
      computeEncoder?.setBuffer(vertexNormalBuffer, offset: 0, index: 5)
      computeEncoder?.setBuffer(randomBuffer, offset: randomBufferOffset, index: 6)
      computeEncoder?.setBuffer(triangleMaskBuffer, offset: 0, index: 7)
      computeEncoder?.setTexture(renderTarget, index: 0)
      computeEncoder?.setComputePipelineState(shadePipeline!)
      computeEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
      computeEncoder?.endEncoding()
      // Shadows pipeline
      intersector?.intersectionDataType = .distance
      intersector?.encodeIntersection(commandBuffer: commandBuffer,
                                      intersectionType: .any,
                                      rayBuffer: shadowRayBuffer!,
                                      rayBufferOffset: 0,
                                      intersectionBuffer: intersectionBuffer!,
                                      intersectionBufferOffset: 0,
                                      rayCount: width * height,
                                      accelerationStructure: accelerationStructure!)
      computeEncoder = commandBuffer.makeComputeCommandEncoder()
      computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset, index: 0)
      computeEncoder?.setBuffer(shadowRayBuffer, offset: 0, index: 1)
      computeEncoder?.setBuffer(intersectionBuffer, offset: 0, index: 2)
      computeEncoder?.setTexture(renderTarget, index: 0)
      computeEncoder?.setComputePipelineState(shadowPipeline!)
      computeEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
      computeEncoder?.endEncoding()
    }
    
    // 4th compute pipeline
    computeEncoder = commandBuffer.makeComputeCommandEncoder()
    computeEncoder?.setBuffer(uniformBuffer, offset: uniformBufferOffset, index: 0)
    computeEncoder?.setTexture(renderTarget, index: 0)
    computeEncoder?.setTexture(accumulationTarget, index: 1)
    computeEncoder?.setComputePipelineState(accumulatePipeline!)
    computeEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
    computeEncoder?.endEncoding()
    
    guard let descriptor = view.currentRenderPassDescriptor,
          let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                                  descriptor: descriptor) else {
      return
    }
    renderEncoder.setRenderPipelineState(copyPipeline!)
    renderEncoder.setFragmentTexture(accumulationTarget, index: 0)
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    renderEncoder.endEncoding()
    guard let drawable = view.currentDrawable else {
      return
    }
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}
