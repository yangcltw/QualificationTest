//
//  VideoWriter.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//

import Foundation
import UIKit
import AVFoundation
import CoreGraphics
import Photos

class VideoWriter: DataOutputProtocol {
    static let VideoWriterVideoWidthKey = "VideoWriterVideoWidthKey"
    static let VideoWriterVideoHeightKey = "VideoWriterVideoHeightKey"
    static let VideoWriterVideoRecordingViewKey = "VideoWriterVideoRecordingViewKey"
    var isRecording: Bool
    let assetWriter: AVAssetWriter
    let videoWriterInput: AVAssetWriterInput
    //let audioWriterInput: AVAssetWriterInput
    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    let documentUrl: URL
    let options: [String: Any]
    var displayLink: CADisplayLink?
    var recordingView: UIView
    
    // MARK: - AVAssetWriter
    init?(with options: [String: Any]) {
        self.options = options
        isRecording = false
        recordingView = options[VideoWriter.VideoWriterVideoRecordingViewKey] as! UIView
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first  else {
            print("init fail")
            return nil
        }
        documentUrl = url.appendingPathComponent("recording.mp4")
        let fileManager = FileManager.default
        do {
            try fileManager .removeItem(atPath: documentUrl.path)
        } catch {
            print("Could not clear temp file: \(error)")
        }
        
        guard let _assetWriter = try? AVAssetWriter(outputURL: documentUrl, fileType: AVFileType.mp4) else {return nil}
        self.assetWriter = _assetWriter
        let width = options[VideoWriter.VideoWriterVideoWidthKey] as? CGFloat ?? 1024
        let height = options[VideoWriter.VideoWriterVideoHeightKey] as? CGFloat ?? 768
        let avOutputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: NSNumber(value: Float(width)),
            AVVideoHeightKey: NSNumber(value: Float(height))
        ]
        
        self.videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: avOutputSettings)
        self.videoWriterInput.expectsMediaDataInRealTime = true
        self.assetWriter.add(self.videoWriterInput)
        
        let sourcePixelBufferAttributesDictionary = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(height))
        ]
        
        self.pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: self.videoWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary
        )
        
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMTime.zero)
    }
    
    func setUp(with options: [String : Any]) {
        //self.options = options
    }
    
    func startRecording() {
        isRecording = true
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: RunLoop.main, forMode: .common)

    }
    
    func stopRecording() {
        isRecording = false
        self.displayLink?.invalidate()
        
        self.videoWriterInput.markAsFinished()
        
        self.assetWriter.finishWriting(completionHandler: {
            print("Finished writing video file")
            PHPhotoLibrary.requestAuthorization { status in
                // Return if unauthorized
                guard status == .authorized else {
                    print("Error saving video: unauthorized access")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.documentUrl as URL)
                }) { success, error in
                    if !success {
                        print("Error saving video: \(String(describing: error))")
                    }
                }
            }
            self.isRecording = false
        })
    }
    var previousFrameTime:CFTimeInterval? = nil
    @objc private func tick(_ displayLink: CADisplayLink) {
        let timestamp = self.displayLink?.timestamp
        
        if let previousFrameTime: CFTimeInterval = self.previousFrameTime {
            let render = UIGraphicsImageRenderer(size: recordingView.bounds.size ?? .zero)
            let image = render.image { (ctx) in
                // Important to capture the presentation layer of the view for animation to be recorded
                recordingView.layer.presentation()?.render(in: ctx.cgContext)
            }
            let timeDiff: CFTimeInterval = timestamp! - previousFrameTime
            
            let presentationTime = CMTime(seconds: Double(timeDiff), preferredTimescale: 10000)
            
            if self.addImage(image: image, withPresentationTime: presentationTime) == false {
                print("ERROR: Failed to append frame")
            }
        }
        
        if self.previousFrameTime == nil && timestamp! > 0 {
            self.previousFrameTime = timestamp
        }
        
    }
    // MARK: - Insert Image
    
    /// Appends an image, returning true if successful
    func addImage(image: UIImage, withPresentationTime presentationTime: CMTime, waitIfNeeded: Bool = false) -> Bool {
        guard let pixelBufferPool = self.pixelBufferAdaptor.pixelBufferPool else {
            print("ERROR: pixelBufferPool is nil ")
            return false
        }
        let width = options[VideoWriter.VideoWriterVideoWidthKey] as? CGFloat ?? 1024
        let height = options[VideoWriter.VideoWriterVideoHeightKey] as? CGFloat ?? 768
        guard let pixelBuffer = self.pixelBufferFromImage(
            image: image,
            pixelBufferPool: pixelBufferPool,
            size: CGSizeMake(CGFloat(width), CGFloat(height))
        )
        else {
            print("ERROR: Failed to generate pixelBuffer")
            return false
        }
        
        print("isReadyForMoreMediaData: \(self.videoWriterInput.isReadyForMoreMediaData)")
        
        if waitIfNeeded {
            // Wait until the previous frame has successfully written to continue
            while self.videoWriterInput.isReadyForMoreMediaData == false { }
        }
        
        return self.pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    }
    
    
    // MARK: - Internal Helper
    
    /// - Converts a UIImage to a CVPixelBuffer, returning nil on failure
    /// - Parameters:
    ///   - image: <#image description#>
    ///   - pixelBufferPool: <#pixelBufferPool description#>
    ///   - size: <#size description#>
    /// - Returns: <#description#>
    private func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer?
    {
        guard let cgImage = image.cgImage else { return nil }
        
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
        
        guard status == kCVReturnSuccess else {
            print("ERROR: CVPixelBufferPoolCreatePixelBuffer() failed")
            return nil
        }
        
        guard let pixelBuffer = pixelBufferOut else {
            print("ERROR: pixelBufferOut not populated as expected")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: data,
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        else {
            print("ERROR: unable to create pixel CGContext")
            return nil
        }
        
        context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        let horizontalRatio = size.width / CGFloat(cgImage.width)
        let verticalRatio = size.height / CGFloat(cgImage.height)
        let aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
        //let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
        let newSize = CGSize(
            width: CGFloat(cgImage.width) * aspectRatio,
            height: CGFloat(cgImage.height) * aspectRatio
        )
        
        let x = (newSize.width < size.width) ? (size.width - newSize.width) / 2 : -(newSize.width-size.width) / 2
        let y = (newSize.height < size.height) ? (size.height - newSize.height) / 2 : -(newSize.height-size.height) / 2
        
        context.draw(cgImage, in: CGRect(x:x, y:y, width:newSize.width, height:newSize.height))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        return pixelBuffer
    }
    
    
}
