//
//  AVVdeioEncoder.swift
//  DMLiveTest
//
//  Created by darrenChiang on 2018/3/13.
//  Copyright © 2018年 darrenChiang. All rights reserved.
//

import UIKit
import VideoToolbox

class AVVdeioEncoder: NSObject {
    
    fileprivate var NALUHeader: [UInt8] = [0, 0, 0, 1]
    private var h264File:String!
    private var compressionSession :VTCompressionSession?
    private var fileHandle:FileHandle!
    private let vedioSessionQueue = DispatchQueue(label: "session VT")
    private var frame:Int64?
    
    //CMVideoFormatDescriptionRef是一個video數據的描述，如寬度/高度，格式types等
    var formatDescription:CMFormatDescription? = nil {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, oldValue) else {
                return
            }
            setFormatDescription(video: formatDescription)
        }
    }
    
    override init() {
        super.init()
        // init filehandle
        let documentDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        h264File = documentDir[0] + "/live.h264"
        print("path:\(h264File)")
        
        do {
            try? FileManager.default.removeItem(atPath: h264File)
            if FileManager.default.createFile(atPath: h264File, contents: nil, attributes: nil) {
                try fileHandle = FileHandle(forWritingTo: NSURL(string: h264File)! as URL)
            }
        } catch let error as NSError {
            print(error)
        }
        
        frame = 0
        
        //setupVideoSession()
    }
    
     func setupVideoSession(samplebuffer: CMSampleBuffer) {
        vedioSessionQueue.async {
            guard let pixelbuffer = CMSampleBufferGetImageBuffer(samplebuffer) else {
                return
            }
            
            if self.compressionSession == nil {
                
//                let width = CVPixelBufferGetWidth(pixelbuffer)
//                let height = CVPixelBufferGetHeight(pixelbuffer)
                let width = 480
                let height = 640
                print("width: \(width), height: \(height)")
                
                VTCompressionSessionCreate(kCFAllocatorDefault,
                                           Int32(width),
                                           Int32(height),
                                           kCMVideoCodecType_H264,
                                           nil, nil, nil,
                                           self.finshCompressionCallback,
                                           UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                                           &self.compressionSession)
                
                guard let session = self.compressionSession else {
                    return
                }
                
                
                // set profile to Main
                VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel)
                // 設置實時編碼
                VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, true as CFTypeRef)
                // 設置期望幀數，每秒多少幀
                VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, 10 as CFTypeRef)
                //設置碼率，碼率越高，則畫面越清晰，碼率高有利於還原原始畫面,但是也不利於傳輸
                //一个像素如果有alfa通道的话应该是4个字节，没有alfa通道是3个字节，后面乘以8是因为每个字节有8位。
                VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, width * height * 3 * 4 * 8 as CFTypeRef)
                //設置碼率的限制
                //VTSessionSetProperty(session, kVTCompressionPropertyKey_DataRateLimits, width * height * 3 * 4 as CFTypeRef)
                VTSessionSetProperty(session, kVTCompressionPropertyKey_DataRateLimits, [width * height * 3 * 4, 1] as CFArray)
                //設置關鍵幀間隔
                VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, 10 as CFTypeRef)
                //VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, NSNumber(value: 10.0))
                //設置結束，準備編碼
                VTCompressionSessionPrepareToEncodeFrames(session)
            }
        }
    }

    private var finshCompressionCallback:VTCompressionOutputCallback = {(outputCallbackRefCon: UnsafeMutableRawPointer?,
                                             sourceFrameRefCon: UnsafeMutableRawPointer?,
                                             status: OSStatus,
                                             infoFlags: VTEncodeInfoFlags,
                                             sampleBuffer: CMSampleBuffer?) in
        
        guard status == noErr else {
            print("error: \(status)")
            return
        }
        
        if infoFlags == .frameDropped {
            print("frame dropped")
            return
        }
        
        guard let sampleBuffer = sampleBuffer else {
            print("sampleBuffer is nil")
            return
        }
        
        if CMSampleBufferDataIsReady(sampleBuffer) != true {
            print("sampleBuffer data is not ready")
            return
        }
        
            let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
            let extensions = CMFormatDescriptionGetExtensions(desc!)
            print("extensions: \(extensions!)")
        
            let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
            print("sample count: \(sampleCount)")
        
            let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)!
            var length: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(dataBuffer, 0, nil, &length, &dataPointer)
            print("length: \(length), dataPointer: \(dataPointer!)")
        
        // let vc: ViewController = Unmanaged.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
        
        let encoder:AVVdeioEncoder = unsafeBitCast(outputCallbackRefCon, to: AVVdeioEncoder.self)
        
        // 透過Attachments裡包含幀圖像的一些屬性去判斷幀
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true) {
            print("attachments: \(attachments)")
            
            let rawDic: UnsafeRawPointer = CFArrayGetValueAtIndex(attachments, 0)
            let dic: CFDictionary = Unmanaged.fromOpaque(rawDic).takeUnretainedValue()
            
            //判斷是否是IDR frame
            let keyFrame = !CFDictionaryContainsKey(dic, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
            
            if keyFrame {
                print("IDR frame")
                //如果是IDR frame，需要重新查找SPS/PPS，開始一個新的序列，獲取CMFormatDescriptionRef
                encoder.formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
            }
            
            // handle frame data
            encoder.setFrameData(buffer: sampleBuffer)
        }
    }
    
    private func setFormatDescription(video formatDescription:CMFormatDescription?) {
        
        // 取得SPS
        var spsSize: Int = 0
        var spsCount: Int = 0
        var nalHeaderLength: Int32 = 0
        var sps: UnsafePointer<UInt8>?
        
        if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription!,
                                                              0,
                                                              &sps,
                                                              &spsSize,
                                                              &spsCount,
                                                              &nalHeaderLength) == noErr {
            print("sps: \(String(describing: sps)), spsSize: \(spsSize), spsCount: \(spsCount), NAL header length: \(nalHeaderLength)")
        }
            // 取得PPS
            var ppsSize: Int = 0
            var ppsCount: Int = 0
            var pps: UnsafePointer<UInt8>?
            
            if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription!,
                                                                  1,
                                                                  &pps,
                                                                  &ppsSize,
                                                                  &ppsCount,
                                                                  &nalHeaderLength) == noErr {
                print("pps: \(String(describing: pps)), ppsSize: \(ppsSize), ppsCount: \(ppsCount), NAL header length: \(nalHeaderLength)")
        }
                let spsData: NSData = NSData(bytes: sps, length: spsSize)
                let ppsData: NSData = NSData(bytes: pps, length: ppsSize)
                
                // save sps/pps to file
                encodeData(data: spsData)
                encodeData(data: ppsData)
    }
    
    private func setFrameData(buffer: CMSampleBuffer) {
        
        guard let dataBuffer = CMSampleBufferGetDataBuffer(buffer) else {
            return
        }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        if CMBlockBufferGetDataPointer(dataBuffer , 0, &lengthAtOffset, &totalLength, &dataPointer) == noErr {
            
           //NALU數據前四個字節不是startcode，而是大端模式的幀長度length
            var bufferOffset: Int = 0
            let AVCCHeaderLength = 4
            
            //獲取NALU數據
            while bufferOffset < (totalLength - AVCCHeaderLength) {
                var NALUnitLength: UInt32 = 0
                //讀取NAL單元長度
                memcpy(&NALUnitLength, dataPointer?.advanced(by: bufferOffset), AVCCHeaderLength)
                
                //大端字節序轉小端字節序 iOS以小端字節序讀取
                NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                let data: NSData = NSData(bytes: dataPointer?.advanced(by: bufferOffset + AVCCHeaderLength), length: Int(NALUnitLength))
                
                encodeData(data: data)
                // 移動到下一個NAL Unit
                bufferOffset += Int(AVCCHeaderLength)
                bufferOffset += Int(NALUnitLength)
            }
        }
    }
    
    func encodeData(data: NSData) {
        guard let fh = fileHandle else {
            return
        }
        //NALU startcode 都是00 00 00 01 或 00 00 01
        let headerData: NSData = NSData(bytes: NALUHeader, length: NALUHeader.count)
        fh.write(headerData as Data)
        fh.write(data as Data)
    }
    
    //MARK : action
    func startEncdoer(sampleBuffer: CMSampleBuffer) {

        guard let image:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        vedioSessionQueue.async {
            
            guard let session:VTCompressionSession = self.compressionSession else {
                return
            }
            
            
            //取的該偵的時間戳
            let presentationTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            //取的該偵的持續時間
            let frameID = self.frame! + 1
            let timestamp  = CMTimeMake(frameID, 1000)
            let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
            //設置同步異步處理
            var flags:VTEncodeInfoFlags = VTEncodeInfoFlags()
            //開始Encode
            let status = VTCompressionSessionEncodeFrame(session, image, presentationTimestamp , kCMTimeInvalid, nil, nil, &flags)
            if status != noErr {
                //show msg
                 print("error: \(status)")
            }
        }
    }
    
    func stopEncoder() {
        
        guard let compressionSession = compressionSession else {
            return
        }
        //結束編碼
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid)
        VTCompressionSessionInvalidate(compressionSession)
        self.compressionSession = nil
    }
}

extension AVVdeioEncoder {
    enum SessionPar {
        static let frameInterval: Int = 10
        static let bitRate: Int = 302
        static let defaultFooterHeight: CGFloat = 50
    }
}

