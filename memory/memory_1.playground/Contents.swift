
import MetalKit

guard let device = MTLCreateSystemDefaultDevice() else { fatalError() }
guard let queue = device.makeCommandQueue() else { fatalError() }
let count = 1500
var myVector = [Float](repeating: 0, count: count)
var length = count * MemoryLayout<Float>.size
print(length)
guard let outBuffer = device.makeBuffer(bytes: myVector, length: length, options: []) else { fatalError() }
for (index, _) in myVector.enumerated() { myVector[index] = Float(index) }
var inBuffer = device.makeBuffer(bytes: myVector, length: length, options: [])

let path = Bundle.main.path(forResource: "memory", ofType: "metal")
let input = try String(contentsOfFile: path!, encoding: String.Encoding.utf8)
let library = try device.makeLibrary(source: input, options: nil)
let function = library.makeFunction(name: "compute")!
let computePipelineState = try! device.makeComputePipelineState(function: function)

guard let commandBuffer = queue.makeCommandBuffer() else { fatalError() }
guard let encoder = commandBuffer.makeComputeCommandEncoder() else { fatalError() }
encoder.setComputePipelineState(computePipelineState)
encoder.setBuffer(inBuffer, offset: 0, index: 0)
encoder.setBuffer(outBuffer, offset: 0, index: 1)
let size = MTLSize(width: count, height: 1, depth: 1)
encoder.dispatchThreadgroups(size, threadsPerThreadgroup: size)
encoder.endEncoding()
commandBuffer.commit()

let result = outBuffer.contents().bindMemory(to: Float.self, capacity: count)
var data = [Float](repeating:0, count: count)
for i in 0 ..< count { data[i] = result[i] }
data.map { $0 }

import ModelIO

guard let url = Bundle.main.url(forResource: "teapot", withExtension: "obj") else { fatalError() }
let asset = MDLAsset(url: url)
let voxelArray = MDLVoxelArray(asset: asset, divisions: 10, patchRadius: 0)
if let data = voxelArray.voxelIndices() {
    data.withUnsafeBytes { (voxels: UnsafePointer<MDLVoxelIndex>) -> Void in
        let count = data.count / MemoryLayout<MDLVoxelIndex>.size
        var voxelIndex = voxels
        for _ in 0..<count {
            let position = voxelArray.spatialLocation(ofIndex: voxelIndex.pointee)
            print(position)
            voxelIndex = voxelIndex.successor()
        }
    }
}
