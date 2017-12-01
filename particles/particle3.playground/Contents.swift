
import MetalKit
import PlaygroundSupport

let frame = NSRect(x: 0, y: 0, width: 600, height: 600)
let mView = MetalView()
let view = MTKView(frame: frame, device: mView.device)
view.delegate = mView
PlaygroundPage.current.liveView = view
