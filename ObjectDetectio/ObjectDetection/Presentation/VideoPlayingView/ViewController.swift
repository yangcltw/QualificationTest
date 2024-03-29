import CoreMedia
import ReplayKit
import AVFoundation
import CoreML
import UIKit
import Vision

class ViewController: UIViewController {
    
    
    @IBOutlet var videoPreview: UIView!
    var videoCapture: DataSourceProtocol?
    var currentBuffer: CVPixelBuffer?
    
    let coreMLModel = MobileNetV2_SSDLite()
    
    lazy var visionModel: VNCoreMLModel = {
        do {
            return try VNCoreMLModel(for: coreMLModel.model)
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
    
    let maxBoundingBoxViews = 10
    var boundingBoxViews = [BoundingBoxView]()
    var colors: [String: UIColor] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.backButtonTitle = "Back"
        videoPreview.translatesAutoresizingMaskIntoConstraints = false
        setUpBoundingBoxViews()
        HumanDetectionRecording.shared.set(self.videoPreview, rootViewController: self)
    }
    
    func setUpBoundingBoxViews() {
        for _ in 0..<maxBoundingBoxViews {
            boundingBoxViews.append(BoundingBoxView())
        }
        
        // The label names are stored inside the MLModel's metadata.
        guard let userDefined = coreMLModel.model.modelDescription.metadata[MLModelMetadataKey.creatorDefinedKey] as? [String: String],
              let allLabels = userDefined["classes"] else {
            fatalError("Missing metadata")
        }
        
        let labels = allLabels.components(separatedBy: ",")
        
        // Assign random colors to the classes.
        for label in labels {
            colors[label] = UIColor(red: CGFloat.random(in: 0...1),
                                    green: CGFloat.random(in: 0...1),
                                    blue: CGFloat.random(in: 0...1),
                                    alpha: 1)
        }
    }
    
    func setUpUrl() {
        var url = ""
        if let filePath = Bundle.main.path(forResource: "face", ofType: "mp4") {
            url = filePath
        } else {
            print("File not found")
        }
        videoCapture = VideoReader()
        
        videoCapture?.delegate = self
        let options: [String: Any] = [VideoReader.VideoReaderURLKey: url]
        videoCapture?.setUp(with: options) { success in
            if success {
                if let previewLayer = self.videoCapture?.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer(previewLayer: previewLayer)
                }
                
                // Add the bounding box layers to the UI, on top of the video preview.
                for box in self.boundingBoxViews {
                    box.addToLayer(self.videoPreview.layer)
                }
                
                // Once everything is set up, we can start capturing live video.
                self.videoCapture?.start()
            }
        }
    }
    func setUpPhtos(with asset: AVAsset) {
        videoCapture = VideoReader()
        
        videoCapture?.delegate = self
        let options: [String: Any] = [VideoReader.VideoReaderAssetKey: asset]
        videoCapture?.setUp(with: options) { success in
            if success {
                if let previewLayer = self.videoCapture?.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer(previewLayer: previewLayer)
                }
                
                // Add the bounding box layers to the UI, on top of the video preview.
                for box in self.boundingBoxViews {
                    box.addToLayer(self.videoPreview.layer)
                }
                
                // Once everything is set up, we can start capturing live video.
                self.videoCapture?.start()
            }
        }
    }
    
    // TODO : refine
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture?.delegate = self
        let options: [String: Any] = ["sessionPreset": AVCaptureSession.Preset.hd1280x720]
        videoCapture?.setUp(with: options) { success in
            if success {
                // Add the video preview into the UI.
                if let previewLayer = self.videoCapture?.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer(previewLayer: previewLayer)
                }
                
                // Add the bounding box layers to the UI, on top of the video preview.
                for box in self.boundingBoxViews {
                    box.addToLayer(self.videoPreview.layer)
                }
                // Once everything is set up, we can start capturing live video.
                self.videoCapture?.start()
            }
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture?.previewLayer?.frame = videoPreview.bounds
    }
    func resizePreviewLayer(previewLayer: CALayer?) {
        previewLayer?.frame = videoPreview.bounds
    }
    
    func predict(sampleBuffer: CMSampleBuffer) {
        if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            currentBuffer = pixelBuffer
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
            
            currentBuffer = nil
        }
    }
    
    func processObservations(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            if let results = request.results as? [VNRecognizedObjectObservation] {
                self.show(predictions: results)
                HumanDetectionRecording.shared.detectObject(with: results)
            } else {
                self.show(predictions: [])
            }
        }
    }
    
    func show(predictions: [VNRecognizedObjectObservation]) {
        for i in 0..<boundingBoxViews.count {
            if i < predictions.count {
                let prediction = predictions[i]
                
                /*
                 The predicted bounding box is in normalized image coordinates, with
                 the origin in the lower-left corner.
                 
                 Scale the bounding box to the coordinate system of the video preview,
                 which is as wide as the screen and has a 16:9 aspect ratio. The video
                 preview also may be letterboxed at the top and bottom.
                 
                 Based on code from https://github.com/Willjay90/AppleFaceDetection
                 
                 NOTE: If you use a different .imageCropAndScaleOption, or a different
                 video resolution, then you also need to change the math here!
                 */
                let width = self.videoPreview.bounds.width
                let height = self.videoPreview.bounds.height
                let offsetY = ( self.videoPreview.bounds.height - height) / 2
                
                let scale = CGAffineTransform.identity.scaledBy(x: width, y: height)
                let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -height - offsetY)
                let rect = prediction.boundingBox.applying(scale).applying(transform)
                
                // The labels array is a list of VNClassificationObservation objects,
                // with the highest scoring class first in the list.
                let bestClass = prediction.labels[0].identifier
                let confidence = prediction.labels[0].confidence
                
                // Show the bounding box.
                let label = String(format: "%@ %.1f", bestClass, confidence * 100)
                let color = colors[bestClass] ?? UIColor.red
                boundingBoxViews[i].show(frame: rect, label: label, color: color)
            } else {
                boundingBoxViews[i].hide()
            }
        }
    }
    func adjustVideoContentSize(with size: CGSize) {
        let screenSize = self.view.bounds.size
        let viewSize = size
        let scaleFactorWidth = screenSize.width / viewSize.width
        let scaleFactorHeight = screenSize.height / viewSize.height
        let scaleFactor = min(scaleFactorWidth, scaleFactorHeight)
        self.videoPreview.frame.size = CGSizeMake(size.width*scaleFactor, size.height*scaleFactor)
        self.videoPreview.center = self.view.center
    }
}

extension ViewController: DataSourceProtocolDelegate {
    func complete(with status: Int) {
        HumanDetectionRecording.shared.dataSourceInterrupt(with: status)
    }
    
    func videoCapture(from source: DataSourceProtocol, didCaptureVideoFrame: Any) {
        predict(sampleBuffer: didCaptureVideoFrame as! CMSampleBuffer)
    }
}

extension ViewController: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        dismiss(animated: true)
    }
}
