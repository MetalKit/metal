
import Metal

let devices = MTLCopyAllDevices()

devices[0].name
devices[0].areRasterOrderGroupsSupported
devices[0].isDepth24Stencil8PixelFormatSupported
devices[0].isLowPower
devices[0].maxThreadsPerThreadgroup.depth
devices[0].maxThreadgroupMemoryLength
devices[0].supportsFeatureSet(MTLFeatureSet.macOS_GPUFamily1_v3)
devices[0].supportsFeatureSet(MTLFeatureSet.macOS_ReadWriteTextureTier2)

devices[1].name
devices[1].areRasterOrderGroupsSupported
devices[1].isDepth24Stencil8PixelFormatSupported
devices[1].isLowPower
devices[1].maxThreadsPerThreadgroup.depth
devices[1].maxThreadgroupMemoryLength
devices[1].supportsFeatureSet(MTLFeatureSet.macOS_GPUFamily1_v3)
devices[1].supportsFeatureSet(MTLFeatureSet.macOS_ReadWriteTextureTier2)
