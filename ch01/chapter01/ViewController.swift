//
//  ViewController.swift
//  chapter01
//
//  Created by Marius on 1/4/16.
//  Copyright © 2016 Marius Horga. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var label: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        /* The MTLCopyAllDevices() function is only available in macOS.
           For iOS/tvOS devices use MTLCreateSystemDefaultDevice() instead. */
        let devices = MTLCopyAllDevices()
        guard let _ = devices.first else {
            fatalError("Your GPU does not support Metal!")
        }
        label.stringValue = "Your system has the following GPU(s):\n"
        for device in devices {
            label.stringValue += "\(device.name)\n"
        }
    }
}
