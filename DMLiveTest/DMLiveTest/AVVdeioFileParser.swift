//
//  AVVdeioFileParser.swift
//  DMLiveTest
//
//  Created by darrenChiang on 2018/4/18.
//  Copyright © 2018年 darrenChiang. All rights reserved.
//

import UIKit
import Foundation

typealias VideoPacket = Array<UInt8>

class AVVdeioFileParser: NSObject {
    let bufferCap: Int = 480 * 640
    //let bufferCap: Int = 512 * 1024
    //let bufferCap: Int = 1024 * 512
    var streamBuffer = Array<UInt8>()
    
    var fileStream: InputStream?
    
    let startCode: [UInt8] = [0,0,0,1]
    
    func openVideoFile(_ fileURL: URL) {
        streamBuffer = [UInt8]()
        fileStream = InputStream(url: fileURL)
        fileStream?.open()
    }
    
    func getPacket() -> VideoPacket? {
        
        if streamBuffer.count == 0 && readStremData() == 0{
            return nil
        }
        
        //確認從startCode開始
        if streamBuffer.count < 5 || Array(streamBuffer[0...3]) != startCode {
            return nil
        }
        
        //跳過第一個startCode 所以從4開始
        var startIndex = 4
        
        while true {
            
            while ((startIndex + 3) < streamBuffer.count) {
                
                //一位一位字節順移取4位字節 來找尋下一個NAL startCode
                if Array(streamBuffer[startIndex...startIndex+3]) == startCode {
            
                    let packet = Array(streamBuffer[0..<startIndex])
                    streamBuffer.removeSubrange(0..<startIndex)
                    
                    return packet
                }
                startIndex += 1
            }
            
            if readStremData() == 0 {
                return nil
            }
        }
    }
    
    fileprivate func readStremData() -> Int{
        
        if let stream = fileStream, stream.hasBytesAvailable{
            
            var tempArray = Array<UInt8>(repeating: 0, count: bufferCap)
            let bytes = stream.read(&tempArray, maxLength: bufferCap)
            
            if bytes > 0 {
                streamBuffer.append(contentsOf: Array(tempArray[0..<bytes]))
            }
            
            return bytes
        }
        
        return 0
    }
    
}
