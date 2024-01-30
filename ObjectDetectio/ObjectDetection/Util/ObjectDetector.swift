//
//  ObjectDetector.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/30.
//

import Foundation
import Vision

class ObjectDetector {
    
    // MARK: - CoreML and Vision
    var resultClosure: (([VNRecognizedObjectObservation]) -> Void)?
    static let coreMLModel = MobileNetV2_SSDLite()
    
    lazy var visionModel: VNCoreMLModel = {
        do {
            return try VNCoreMLModel(for: ObjectDetector.coreMLModel.model)
        } catch {
            fatalError("Failed to create VNCoreMLModel: \(error)")
        }
    }()
    
    lazy var visionRequest: VNCoreMLRequest = {
        let request = VNCoreMLRequest(model: visionModel, completionHandler: {
            [weak self] request, error in
            self?.processObservations(for: request, error: error)
        })
        
        // NOTE: If you use another crop/scale option, you must also change
        // how the BoundingBoxView objects get scaled when they are drawn.
        // Currently they assume the full input image is used.
        request.imageCropAndScaleOption = .scaleFill
        return request
    }()
    
    func processObservations(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            if let results = request.results as? [VNRecognizedObjectObservation] {
                if let resultClosure = self.resultClosure {
                    resultClosure(results)
                }
            } else {
                if let resultClosure = self.resultClosure {
                    resultClosure([])
                }
            }
        }
    }
    
    func predict(sampleBuffer: CMSampleBuffer, result: @escaping  (([VNRecognizedObjectObservation]) -> Void)) {
        resultClosure = result
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            
            // Get additional info from the camera.
            var options: [VNImageOption : Any] = [:]
            if let cameraIntrinsicMatrix = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
                options[.cameraIntrinsics] = cameraIntrinsicMatrix
            }
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: options)
            do {
                try handler.perform([self.visionRequest])
            } catch {
                print("Failed to perform Vision request: \(error)")
            }
        }
    }
    
    
}
