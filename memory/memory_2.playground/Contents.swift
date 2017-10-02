
import MetalKit

guard let device = MTLCreateSystemDefaultDevice() else { fatalError() }

let count = 2000
let length = count * MemoryLayout< Float >.stride
var myBuffer: MTLBuffer!

//  1. makeBuffer(length:)
//
//myBuffer = device.makeBuffer(length: length, options: [])
//print(myBuffer.contents())

//  2. makeBuffer(bytes:)
//
//var myVector = [Float](repeating: 0, count: count)
//myBuffer = device.makeBuffer(bytes: myVector, length: length, options: [])
//withUnsafePointer(to: &myVector) { print($0) }
//print(myBuffer.contents())

//  3. makeBuffer(bytesNoCopy:)
//
var memory: UnsafeMutableRawPointer? = nil
let alignment = 0x1000
let allocationSize = (length + alignment - 1) & (~(alignment - 1))
posix_memalign(&memory, alignment, allocationSize)
myBuffer = device.makeBuffer(bytesNoCopy: memory!,
                             length: allocationSize,
                             options: [],
                             deallocator: { (pointer: UnsafeMutableRawPointer, _: Int) in
                                 free(pointer)
                             })
print(memory!)
print(myBuffer!.contents())
