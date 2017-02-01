
import MetalKit
import PlaygroundSupport

let frame = NSRect(x: 0, y: 0, width: 300, height: 300)
let delegate = MetalView()
let view = MTKView(frame: frame, device: delegate.device)
view.delegate = delegate
PlaygroundPage.current.liveView = view
