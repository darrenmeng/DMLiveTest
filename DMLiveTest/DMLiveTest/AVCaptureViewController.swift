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

    
    // MARK: Session Management
    
    //取得權限配置
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    @IBOutlet weak var previewView: AVCapturePreviewView!
    
    //建立一個Queue 確保使用者在確認相機權限後才設定Session
    private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
    
    private var setupResult: SessionSetupResult = .success
    
    var videoDeviceInput: AVCaptureDeviceInput!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // 確認相機權限狀態
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            
            //沒有授權 並發起授權許可請求
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            
            setupResult = .notAuthorized
        }
        
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
             self.configureSessionResult()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func configureSession() {
        
        //如果取得裝置權限不成功就return
        if setupResult != .success {
            return
        }
        
        // 配置 session
        session.beginConfiguration()
        
        /*
         We do not create an AVCaptureMovieFileOutput when setting up the session because the
         AVCaptureMovieFileOutput does not support movie recording with AVCaptureSession.Preset.Photo.
         */
        //指定攝像機採集的分辨率
        session.sessionPreset = .photo
        
        // 確認能使用的攝影機裝置.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            //雙鏡頭是否可用,不然就是單獨廣角鏡頭
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                //後置鏡頭
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                //前置鏡頭
                defaultVideoDevice = frontCameraDevice
            }
            
            //創建裝置輸入源 輸入裝置攝像鏡頭
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            //session設定輸入裝置
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    //設置攝像鏡頭方向
                    //根據狀態列的方向
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    //預設為縱向
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    //如果能取得裝態列方向 設置攝像鏡頭方向為statusBar方向
                    if statusBarOrientation != .unknown {
                        if let videoOrientation = AVCaptureVideoOrientation(rawValue: statusBarOrientation.rawValue) {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    
                    //設置相機方向，屏幕變為橫屏，預覽圖像才會更這變為橫屏
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation;
                  //  self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                }
            } else {
                //session無法設定輸入裝置
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            //無法取得攝影機裝置
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add audio input.
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
            }
        } catch {
            print("Could not create audio device input: \(error)")
        }
        
        
        
        // Add photo output.
//        if session.canAddOutput(photoOutput) {
//            session.addOutput(photoOutput)
//
//            photoOutput.isHighResolutionCaptureEnabled = true
//            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
//            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
//            livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
//            depthDataDeliveryMode = photoOutput.isDepthDataDeliverySupported ? .on : .off
//
//        } else {
//            print("Could not add photo output to the session")
//            setupResult = .configurationFailed
//            session.commitConfiguration()
//            return
//        }
        
        session.commitConfiguration()
    }
   
    private func  configureSessionResult() {
        
        switch self.setupResult {
        case .success:
            //self.addObservers()
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            
        case .notAuthorized:
            DispatchQueue.main.async {
                let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                        style: .cancel,
                                                        handler: nil))
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                        style: .`default`,
                                                        handler: { _ in
                                                            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                }))
                
                self.present(alertController, animated: true, completion: nil)
            }
            
        case .configurationFailed:
            DispatchQueue.main.async {
                let alertMsg = "Alert message when something goes wrong during capture session configuration"
                let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                        style: .cancel,
                                                        handler: nil))
                
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
}
