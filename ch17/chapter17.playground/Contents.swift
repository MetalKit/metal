
import MetalKit
import PlaygroundSupport

let view = MTKView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
let renderer = Render(mtkView: view)
view.delegate = renderer
PlaygroundPage.current.liveView = view
