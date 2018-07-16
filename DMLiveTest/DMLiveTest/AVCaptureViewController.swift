//
//  AVCaptureViewController.swift
//  DMLiveTest
//
//  Created by darrenChiang on 2018/2/8.
//  Copyright © 2018年 darrenChiang. All rights reserved.
//

import UIKit
import AVFoundation

class AVCaptureViewController: UIViewController {

    private var avExtractor: AVCaptureExtractor?
    private var avEncoder: AVVdeioEncoder?
    
    @IBOutlet weak var previewView: AVCapturePreviewView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        avExtractor = AVCaptureExtractor(previewLayer: self.previewView.videoPreviewLayer)
        avExtractor?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        avExtractor?.beginSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        avEncoder?.stopEncoder()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue),
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }

            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: action
    @IBAction func videoOutputAction(_ sender: Any) {
        avEncoder = AVVdeioEncoder()
        avExtractor?.configureVideoOutput()
    }
}

extension AVCaptureViewController : AVCaptureExtractorDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        avEncoder?.setupVideoSession(samplebuffer: sampleBuffer)
        avEncoder?.startEncdoer(sampleBuffer: sampleBuffer)
    }    
}


