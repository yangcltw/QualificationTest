//
//  Utilities.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//

import Foundation
import UIKit
import CoreMedia

extension UINavigationController {
    
    // push with completion handler
    public func pushViewController(_ viewController: UIViewController, animated: Bool, completion: @escaping () -> Void) {
        pushViewController(viewController, animated: animated)
        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async { completion() }
            return
        }
        coordinator.animate(alongsideTransition: nil) { _ in completion() }
    }
    
    // pop with completion handler
    func popViewController(animated: Bool, completion: @escaping () -> Void) {
        popViewController(animated: animated)
        guard animated, let coordinator = transitionCoordinator else {
            DispatchQueue.main.async { completion() }
            return
        }
        coordinator.animate(alongsideTransition: nil) { _ in completion() }
    }
}

extension UIImage {
    
    static func image(from uiView: UIView) -> UIImage {
        let render = UIGraphicsImageRenderer(size: uiView.bounds.size ?? .zero)
        let image = render.image { (ctx) in
            // Important to capture the presentation layer of the view for animation to be recorded
            uiView.layer.presentation()?.render(in: ctx.cgContext)
        }
        return image
    }
    
    static func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
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
    
    static func pixelBufferFromImage(image: UIImage, pixelBufferPool: CVPixelBufferPool, size: CGSize) -> CVPixelBuffer?
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
