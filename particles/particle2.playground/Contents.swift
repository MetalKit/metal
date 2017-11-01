
import MetalKit
import PlaygroundSupport

let frame = NSRect(x: 0, y: 0, width: 400, height: 400)
let delegate = MetalViewDelegate()
let view = MTKView(frame: frame, device: delegate.device)
view.clearColor = MTLClearColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1)
view.delegate = delegate
PlaygroundPage.current.liveView = view
