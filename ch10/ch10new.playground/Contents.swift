
import MetalKit
import PlaygroundSupport

guard let device = MTLCreateSystemDefaultDevice(),
      let commandQueue = device.makeCommandQueue() else {
    fatalError("Metal is not supported on this device")
}

let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                 width: 600,
                                                                 height: 600,
                                                                 mipmapped: false)
textureDescriptor.usage = [.shaderWrite, .shaderRead]
guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
    fatalError("Failed to create texture")
}

let shaderSource = """
#include <metal_stdlib>
using namespace metal;

float dist(float2 point, float2 center, float radius)
{
    return length(point - center) - radius;
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    int width = output.get_width();
    int height = output.get_height();
    float2 uv = float2(gid) / float2(width, height);
    uv = uv * 2.0 - 1.0;
    float distToCircle = dist(uv, float2(0), 0.5);
    float distToCircle2 = dist(uv, float2(-0.1, 0.1), 0.5);
    bool inside = distToCircle2 < 0;
    output.write(inside ? float4(0) : float4(1, 0.7, 0, 1) * (1 - distToCircle), gid);
}
"""

guard let library = try? device.makeLibrary(source: shaderSource, options: nil),
      let kernelFunction = library.makeFunction(name: "compute"),
      let computePipelineState = try? device.makeComputePipelineState(function: kernelFunction) else {
    fatalError("Failed to create compute pipeline")
}

guard let commandBuffer = commandQueue.makeCommandBuffer(),
      let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
    fatalError("Failed to create command buffer or compute encoder")
}

let w = computePipelineState.threadExecutionWidth
let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
let threadgroupsPerGrid = MTLSize(width: (texture.width + w - 1) / w,
                                  height: (texture.height + h - 1) / h,
                                  depth: 1)
computeEncoder.setComputePipelineState(computePipelineState)
computeEncoder.setTexture(texture, index: 0)
computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
computeEncoder.endEncoding()
commandBuffer.commit()
commandBuffer.waitUntilCompleted()

class MetalView: MTKView {
    var texture: MTLTexture!
    
    init(frame frameRect: CGRect, device: MTLDevice?, texture: MTLTexture?) {
        self.texture = texture
        super.init(frame: frameRect, device: device)
        self.isPaused = true
        self.enableSetNeedsDisplay = true
        self.drawableSize = CGSize(width: 600, height: 600) // Set the drawable size here
    }
    
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func draw(_ rect: CGRect) {
        guard let drawable = self.currentDrawable else { return }
        if drawable.texture.width != texture.width || drawable.texture.height != texture.height {
            print("Drawable texture size does not match Metal texture size.")
            return
        }
        guard let commandBuffer = device?.makeCommandQueue()?.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        blitEncoder.copy(from: texture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                         to: drawable.texture,
                         destinationSlice: 0,
                         destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

let view = MetalView(frame: CGRect(x: 0, y: 0, width: 600, height: 600), device: device, texture: texture)
PlaygroundPage.current.liveView = view
