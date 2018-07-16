//
//  AVSampleBufferDisplayView.swift
//  DMLiveTest
//
//  Created by darrenChiang on 2018/3/31.
//  Copyright © 2018年 darrenChiang. All rights reserved.
//

import UIKit
import AVFoundation

class AVSampleBufferDisplayView: UIView {

    var displayLayer: AVSampleBufferDisplayLayer {
        guard let layer = layer as? AVSampleBufferDisplayLayer else {
            fatalError("Expected `AVSampleBufferDisplayLayer` type for layer. Check displayLayer.layerClass implementation.")
        }
        
        let _CMTimebasePointer = UnsafeMutablePointer<CMTimebase?>.allocate(capacity: 1)
        let status = CMTimebaseCreateWithMasterClock( kCFAllocatorDefault, CMClockGetHostTimeClock(),  _CMTimebasePointer )
         layer.controlTimebase = _CMTimebasePointer.pointee
        
        if let controlTimeBase = layer.controlTimebase, status == noErr {
            CMTimebaseSetTime(controlTimeBase, kCMTimeZero);
            CMTimebaseSetRate(controlTimeBase, 1.0);
        }
        return layer
    }
    
    var controlTimebase: CMTimebase? {
        get {
            return displayLayer.controlTimebase
        }
        set {
            displayLayer.controlTimebase = newValue
        }
    }

    // MARK: UIView
    override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
}
