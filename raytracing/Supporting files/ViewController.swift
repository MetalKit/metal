//
//  ViewController.swift
//
//  Created by Marius Horga on 7/7/18.
//

import MetalKit

class ViewController: NSViewController {

    var renderer: Renderer!
    var mtkView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let mtkView = self.view as? MTKView,
              let defaultDevice = MTLCreateSystemDefaultDevice() else { fatalError() }
        mtkView.device = defaultDevice
        renderer = Renderer(metalKitView: mtkView)
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        mtkView.delegate = renderer
    }
}
