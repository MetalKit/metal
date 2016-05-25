//
//  ViewController.swift
//  chapter01
//
//  Created by Marius on 1/4/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import Cocoa // contains Metal

class ViewController: NSViewController {

    @IBOutlet weak var label: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let device = MTLCreateSystemDefaultDevice() {
            label.stringValue = "Your GPU name is:\n\(device.name!)"
        } else {
            label.stringValue = "Your GPU does not support Metal!"
        }
    }
}
