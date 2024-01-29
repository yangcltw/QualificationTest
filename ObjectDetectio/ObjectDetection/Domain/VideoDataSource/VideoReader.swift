//
//  VideoReader.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//
import AVFoundation
import Foundation
import UIKit

protocol VideoReaderDelegate: DataSourceProtocolDelegate {
    func videoCapture(from source: VideoReader, didCaptureVideoFrame: Any)
}

class VideoReader: DataSourceProtocol {
    static let VideoReaderURLKey = "VideoReaderURLKey"
    static let VideoReaderAssetKey = "VideoReaderAssetKey"
    var previewLayer: CALayer?
    var delegate: DataSourceProtocolDelegate?
    var reader: AVAssetReader!
    var readerOutput: AVAssetReaderTrackOutput!
    let queue = DispatchQueue(label: "net.machinethink.reader-queue")
    
    func setUp(with option: [String : Any], completion: @escaping (Bool) -> Void) {
        var urlString = ""
        var asset: AVAsset?
        var track: AVAssetTrack?
        previewLayer = CALayer()
        
        if let url = option[VideoReader.VideoReaderURLKey] as? String {
            urlString = url
            asset = AVAsset(url: URL(fileURLWithPath: urlString))
        } else if let assetFromOptions = option[VideoReader.VideoReaderAssetKey] as? AVAsset {
            asset = assetFromOptions
        } else {
            print("error setUP video reader")
        }
        guard let asset = asset else {
            return;
        }
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            print("Could not initialize reader.")
            DispatchQueue.main.async {
                completion(false)
                return
            }
            return
        }
        if let assetTrack = asset.tracks(withMediaType: .video).first {
            track = assetTrack
            getVideoInfo(from: assetTrack)
        } else {
            print("Could not retrieve the video track.")
            DispatchQueue.main.async {
                completion(false)
                return
            }
        }
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        
        readerOutput = AVAssetReaderTrackOutput(track: track!, outputSettings: outputSettings)
        reader.add(readerOutput)
        DispatchQueue.main.async {
            completion(true)
        }
    }
    
    func start() {
        reader.startReading()
        queue.async {
            var previousPTS = CMTimeMake(value: 0, timescale: 0)
            while self.reader.status == .reading {
                if let sampleBuffer = self.readerOutput.copyNextSampleBuffer(){
                    let currentPTS = self.getPTS(from: sampleBuffer)
                    
                    let diffPTS = CMTimeGetSeconds(currentPTS) - CMTimeGetSeconds(previousPTS)
                    if (diffPTS) > 0 && (diffPTS) < 1 {
                        Thread.sleep(forTimeInterval: diffPTS)
                    }
                    DispatchQueue.main.async {
                        self.delegate?.videoCapture(from: self, didCaptureVideoFrame: sampleBuffer)
                        if let image = self.imageFromSampleBuffer(sampleBuffer) {
                            self.previewLayer?.contents = image.cgImage
                        }
                    }

                    previousPTS = currentPTS
                }
            }
            if self.reader.status == .completed {
                self.delegate?.complete(with: 1)
            } else {
                self.delegate?.complete(with: 0)
            }
        }
    }
    
    func stop() {
        reader.cancelReading()
    }
    
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
        let context = CGContext(data: baseAddress, width: CVPixelBufferGetWidth(imageBuffer!), height: CVPixelBufferGetHeight(imageBuffer!), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        // Create a Quartz image from the pixel data in the bitmap graphics context
        let quartzImage = context!.makeImage()
        
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        // Create an image object from the Quartz image
        let image = UIImage(cgImage: quartzImage!)
        
        return image
    }
    
    private func getVideoInfo(from track: AVAssetTrack) {
        
        let naturalSize = track.naturalSize // Resolution of the video
        let width = naturalSize.width // Width of the video
        let height = naturalSize.height // Height of the video
        let estimatedDataRate = track.estimatedDataRate // Bitrate of the video in bits per second
        let fps = track.nominalFrameRate
        print("video info width: \(width) , height= \(height), fps = \(fps)")
        self.delegate?.adjustVideoContentSize(with: CGSizeMake(width, height))
    }
    
    func getPTS(from sampleBuffer: CMSampleBuffer) -> CMTime {
        let pts = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
        return pts
    }
}
