//
//  AVVdeioDisplayViewController.swift
//  DMLiveTest
//
//  Created by darrenChiang on 2018/3/31.
//  Copyright © 2018年 darrenChiang. All rights reserved.
//

import UIKit
import VideoToolbox
import AVFoundation

class AVVdeioDisplayViewController: UIViewController {
    
    var formatDesc: CMVideoFormatDescription?
    var decompressionSession: VTDecompressionSession?
    @IBOutlet var sampleDisplayView: AVSampleBufferDisplayView!
    var videoLayer: AVSampleBufferDisplayLayer?
    
    var decoder:AVVdeioDecoder = AVVdeioDecoder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        decoder.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        decoder.stopDecode()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initView(){
        videoLayer = AVSampleBufferDisplayLayer()
        
        if let layer = videoLayer {
            layer.frame = CGRect(x: 0, y: 400, width: 300, height: 300)
            layer.videoGravity = AVLayerVideoGravity.resizeAspect
            
            let _CMTimebasePointer = UnsafeMutablePointer<CMTimebase?>.allocate(capacity: 1)
            let status = CMTimebaseCreateWithMasterClock( kCFAllocatorDefault, CMClockGetHostTimeClock(),  _CMTimebasePointer )
            layer.controlTimebase = _CMTimebasePointer.pointee
            
            if let controlTimeBase = layer.controlTimebase, status == noErr {
                CMTimebaseSetTime(controlTimeBase, kCMTimeZero);
                CMTimebaseSetRate(controlTimeBase, 1.0);
            }
            
            self.view.layer.addSublayer(layer)
        }
    }
    
    @IBAction func displayh264(_ sender: UIButton) {
        //let filePath = Bundle.main.path(forResource: "mtv", ofType: "h264")
        //let filePath = Bundle.main.path(forResource: "demo", ofType: "h264")
        let filePath = Bundle.main.path(forResource: "abc", ofType: "h264")
        decoder.startDecode(filePath: filePath!)
        
        //NSString *documentsPath = [home stringByAppendingPathComponent:@"Documents"];
    }
    
    
    @IBAction func displaySandoxVideo(_ sender: UIButton) {
        let documentsURL = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        let fooURL = documentsURL.appendingPathComponent("live.h264")
        if FileManager().fileExists(atPath: fooURL.path) {
            decoder.startDecode(filePath: fooURL.path)
        }
        print(FileManager().fileExists(atPath: fooURL.path))
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension AVVdeioDisplayViewController : AVVdieoDecoderDelegate {
    
    func decodeCVImageBufferOutput(decodeOutput sampleBuffer: CVImageBuffer, from decoder: AVVdeioDecoder) {
        
    }
    
    func decodeCMSampleBufferOutput(decodeOutput sampleBuffer: CMSampleBuffer, from decoder: AVVdeioDecoder) {
        self.sampleDisplayView.displayLayer.enqueue(sampleBuffer)
    }
}
