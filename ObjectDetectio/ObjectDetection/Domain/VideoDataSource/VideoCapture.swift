import AVFoundation
import CoreVideo
import UIKit

protocol VideoCaptureDelegate: DataSourceProtocolDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CMSampleBuffer)
}

public class VideoCapture: NSObject, DataSourceProtocol {
    var previewLayer: CALayer?
    weak var delegate: DataSourceProtocolDelegate?
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "net.machinethink.camera-queue")
    
    
    func setUp(with option: [String : Any], completion: @escaping (Bool) -> Void) {
        var preset = AVCaptureSession.Preset.medium
        if let sessionPreset = option["sessionPreset"] as? AVCaptureSession.Preset {
            preset = sessionPreset
        }
        queue.async {
            let success = self.setUpCamera(sessionPreset: preset)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    public func start() {
        if !self.captureSession.isRunning {
            queue.async {
                self.captureSession.startRunning()
            }
        }
    }
    
    public func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
   
    // MARK: - Private function
    
    private func setUpCamera(sessionPreset: AVCaptureSession.Preset) -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Error: no video devices available")
            return false
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            return false
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
//        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
//        previewLayer.connection?.videoOrientation = .portrait
//        self.previewLayer = previewLayer
        self.previewLayer = CALayer()
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // We want the buffers to be in portrait orientation otherwise they are
        // rotated by 90 degrees. Need to set this _after_ addOutput()!
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        return true
    }
    
    
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            self.delegate?.videoCapture(from: self, didCaptureVideoFrame: sampleBuffer)
            if let image = UIImage.imageFromSampleBuffer(sampleBuffer) {
                self.previewLayer?.contents = image.cgImage
                self.delegate?.adjustVideoContentSize(with: image.size)
            }
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("dropped frame")
    }
}
