//
//  AVVdeioDecoder.swift
//  DMLiveTest
//
//  Created by darrenChiang on 2018/3/31.
//  Copyright © 2018年 darrenChiang. All rights reserved.
//

import UIKit
import VideoToolbox

@objc protocol AVVdieoDecoderDelegate: class {
    //openGL
    func decodeCVImageBufferOutput( decodeOutput sampleBuffer: CVImageBuffer, from decoder: AVVdeioDecoder)
    //AVSampleBufferDisplayLayer
    func decodeCMSampleBufferOutput( decodeOutput sampleBuffer: CMSampleBuffer, from decoder: AVVdeioDecoder)
}

class AVVdeioDecoder: NSObject {
 
    weak var delegate:AVVdieoDecoderDelegate?
    var formatDesc: CMVideoFormatDescription?
    var decompressionSession: VTDecompressionSession?
    private var displayLink:CADisplayLink?
    private let decodeQueue = DispatchQueue(label: "decode queue")
    private var filePath:String!
    private var videoParser:AVVdeioFileParser?
    
    var spsSize: Int = 0
    var ppsSize: Int = 0
    var sps: Array<UInt8>?
    var pps: Array<UInt8>?
    
    override init() {
        super.init()
        settingDisplayLink()
    }
    
    private func settingDisplayLink () {
        //透過CADisplayLink 更新videoFrame
        displayLink = CADisplayLink.init(target: self, selector: #selector(updateVideoFrame))
        //displayLink?.frameInterval = 10
        displayLink?.preferredFramesPerSecond = 60
        //displayLink?.preferredFramesPerSecond = 90
        displayLink?.isPaused = true;
        displayLink?.add(to:RunLoop.current , forMode: RunLoopMode.commonModes)
    }
    
    @objc func updateVideoFrame() {
        decodeQueue.async {
            // let filePath = Bundle.main.path(forResource: "mtv", ofType: "h264")
            let url = URL(fileURLWithPath: self.filePath)
            self.decodeFile(url)
        }
    }
    
    func startDecode(filePath:String) {
        self.filePath = filePath
        videoParser = AVVdeioFileParser()
        videoParser?.openVideoFile(URL(fileURLWithPath: filePath))
        displayLink?.isPaused = false;
    }
    
    func stopDecode() {
        displayLink?.isPaused = true
        displayLink?.invalidate()
        displayLink = nil
        videoParser = nil
    }
    
    func decodeFile(_ fileURL: URL) {
        if var packet = videoParser?.getPacket() {
             self.receiveVideoFrame(&packet)
        }
    }
    
    private var finshDecompressionCallback:VTDecompressionOutputCallback = {(_ decompressionOutputRefCon: UnsafeMutableRawPointer?, _ sourceFrameRefCon: UnsafeMutableRawPointer?, _ status: OSStatus, _ infoFlags: VTDecodeInfoFlags, _ imageBuffer: CVImageBuffer?, _ presentationTimeStamp: CMTime, _ presentationDuration: CMTime)  in
        
        let decoder : AVVdeioDecoder = unsafeBitCast(decompressionOutputRefCon, to: AVVdeioDecoder.self)
        if status == noErr {
            // do something with your resulting CVImageBufferRef that is your decompressed frame
            if let delegate = decoder.delegate {
                decoder.delegate?.decodeCVImageBufferOutput(decodeOutput: imageBuffer! , from: decoder)
            }
        }
    }
    
    private func finshdecompressionCallback(_ decompressionOutputRefCon: UnsafeMutableRawPointer?, _ sourceFrameRefCon: UnsafeMutableRawPointer?, _ status: OSStatus, _ infoFlags: VTDecodeInfoFlags, _ imageBuffer: CVImageBuffer?, _ presentationTimeStamp: CMTime, _ presentationDuration: CMTime) -> Void {
        
//        let streamManager: ViewController = unsafeBitCast(decompressionOutputRefCon, to: ViewController.self)
//
//        if status == noErr {
//            // do something with your resulting CVImageBufferRef that is your decompressed frame
//            streamManager.displayDecodedFrame(imageBuffer);
//        }
    }
    
    func displayDecodedFrame(_ smapleBuffer: CMSampleBuffer?) {
        //diaplay with AVSampleBufferDisplayLayer
        if let delegate = self.delegate {
            delegate.decodeCMSampleBufferOutput(decodeOutput: smapleBuffer!, from: self)
        }
    }

    func receiveVideoFrame(_ videoPacket: inout VideoPacket) {

        // 四個字節的大端length+nalu 去創建CMBlockBufferRef
        //根據AVCC格式 轉換NALU Start Code
        var biglen = CFSwapInt32HostToBig(UInt32(videoPacket.count - 4))
        memcpy(&videoPacket, &biglen, 4)
        
        // uint8 -取出5 第五字節是nalType Ps.取出是10進制
        // &0x1f- 與0x1F相與提取地址數後五位
        // 二進制取後五位bit 轉16進制
        let nalType = videoPacket[4] & 0x1F
        
        switch nalType {
        case 0x05:
            print("Nal type is IDR frame")
            //初始化init videoToolBox
            if initDecompression() {
                decodeVideoPacket(videoPacket)
            }
        case 0x07:
            print("Nal type is SPS")
            spsSize = videoPacket.count - 4
            sps = Array(videoPacket[4..<videoPacket.count])
        case 0x08:
            print("Nal type is PPS")
            ppsSize = videoPacket.count - 4
            pps = Array(videoPacket[4..<videoPacket.count])
            
        default:
            print("Nal type is B/P frame")
            decodeVideoPacket(videoPacket)
            break;
        }
        
        print("Read Nalu size \(videoPacket.count)");
    }
    
    func initDecompression() -> Bool{
        formatDesc = nil
        
        if let spsData = sps, let ppsData = pps {
            let pointerSPS = UnsafePointer<UInt8>(spsData)
            let pointerPPS = UnsafePointer<UInt8>(ppsData)
            
            // SPS,PPS
            let dataParamArray = [pointerSPS, pointerPPS]
            let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(dataParamArray)
            
            // parameter sizes array
            let sizeParamArray = [spsData.count, ppsData.count]
            let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)
            
            //創建CMVideoFormatDesc
            let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, 4, &formatDesc)
            
            if let desc = formatDesc, status == noErr {
                
                if let session = decompressionSession {
                    VTDecompressionSessionInvalidate(session)
                    decompressionSession = nil
                }
                
                var videoSessionM : VTDecompressionSession?
                let decoderParameters = NSMutableDictionary()
                let destinationPixelBufferAttributes = NSMutableDictionary()
                destinationPixelBufferAttributes.setValue(NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32), forKey: kCVPixelBufferPixelFormatTypeKey as String)
                
                var outputCallback = VTDecompressionOutputCallbackRecord()
                outputCallback.decompressionOutputCallback = finshDecompressionCallback
                outputCallback.decompressionOutputRefCon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
                
                let status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                                          desc, decoderParameters,
                                                          destinationPixelBufferAttributes,&outputCallback,
                                                          &videoSessionM)
                
                if(status != noErr) {
                    print("ERROR type:\(status)")
                }
                
                self.decompressionSession = videoSessionM
            }else {
                print("IOS8VT: reset decoder session failed status=\(status)")
            }
        }
        
        return true
    }
    
    func decodeVideoPacket(_ videoPacket: VideoPacket) {
        
        let bufferPointer = UnsafeMutablePointer<UInt8>(mutating: videoPacket)
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,bufferPointer, videoPacket.count,
                                                        kCFAllocatorNull,
                                                        nil, 0, videoPacket.count,
                                                        0, &blockBuffer)
        
        if status != kCMBlockBufferNoErr {
            return
        }
        
        var sampleBuffer: CMSampleBuffer?
        let sampleSizeArray = [videoPacket.count]
        
        //包裝成CMSampleBuffer
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           formatDesc,
                                           1, 0, nil,
                                           1, sampleSizeArray,
                                           &sampleBuffer)
        
        if let buffer = sampleBuffer, let session = decompressionSession, status == kCMBlockBufferNoErr {
            
            let attachments:CFArray? = CMSampleBufferGetSampleAttachmentsArray(buffer, true)
            if let attachmentArray = attachments {
                let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachmentArray, 0), to: CFMutableDictionary.self)
                
                CFDictionarySetValue(dic,
                                     Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                     Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
            }
            
            //直接使用AVSampleBufferDisplayLayer 播放
            self.displayDecodedFrame(buffer)
            
            //diaplay with AVSampleBufferDisplayLayer
//            self.videoLayer?.enqueue(buffer)
//
//            DispatchQueue.main.async(execute: {
//                self.videoLayer?.setNeedsDisplay()
//            })

            
            //videoToolBox decode
            var flagOut = VTDecodeInfoFlags(rawValue: 0)
            var outputBuffer = UnsafeMutablePointer<CVPixelBuffer>.allocate(capacity: 1)
            status = VTDecompressionSessionDecodeFrame(session, buffer,
                                                       [._EnableAsynchronousDecompression],
                                                       &outputBuffer, &flagOut)
            
            if status == noErr {
                print("OK")
            }else if(status == kVTInvalidSessionErr) {
                print("IOS8VT: Invalid session, reset decoder session");
            } else if(status == kVTVideoDecoderBadDataErr) {
                print("IOS8VT: decode failed status=\(status)(Bad data)");
            } else if(status != noErr) {
                print("IOS8VT: decode failed status=\(status)");
            }
        }
    }
}
