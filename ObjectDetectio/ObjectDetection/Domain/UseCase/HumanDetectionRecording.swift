//
//  HumanDetectionUseCase.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//

import Foundation
import Vision
import UIKit

class HumanDetectionRecording {
    
    static let shared = HumanDetectionRecording()
    var timer: Timer?
    var recorder: DataOutputProtocol?
    var recordingView: UIView?
    var rootViewController: UIViewController?
    
    func set(_ recordingView: UIView, rootViewController: UIViewController) {
        self.recordingView = recordingView
        self.rootViewController = rootViewController
    }
    func detectObject(with predictions: [VNRecognizedObjectObservation]) {
        
        if (predictions.filter({$0.labels[0].identifier ==
            "person"}).count > 0) {
            if recorder == nil {
                setupAssetWriterRecorder()
                //setupReplayKitRecorder()
            }
            self.startTimer()
            if(!recorder!.isRecording) {
                recorder?.startRecording()
            }
        }
    }
    
    // TODO: refine
    func dataSourceInterrupt(with reason: Int) {
        self.stopRecording()
    }
    
    // MARK: - Private function
    
    private func setupReplayKitRecorder() {
        recorder = ReplayKitRecorder()
        // TODO: think if there is better way to do so
        
        recorder?.setup(with: [ReplayKitRecorder.optionViewControllerKey : rootViewController])
        
    }
    private  func setupAssetWriterRecorder() {
        // TODO
        guard let recordingView = recordingView else{
            print("setupAssetWriterRecorder fail")
            return
        }
        
        let options = [
            VideoWriter.VideoWriterVideoWidthKey: recordingView.frame.size.width,
            VideoWriter.VideoWriterVideoHeightKey: recordingView.frame.size.height,
            VideoWriter.VideoWriterVideoRecordingViewKey: recordingView
        ] as [String : Any]
        recorder = VideoWriter.init(with: options)
    }
    
    private func startTimer() {
        // Invalidate existing timer if it exists
        timer?.invalidate()
        
        // Start a new timer that fires every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            print("Timer fired!")
            self.stopRecording()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func stopRecording() {
        stopTimer()
        guard let recorder = recorder else {
            return
        }
        if(recorder.isRecording) {
            recorder.stopRecording()
        }
        self.recorder = nil
    }
    
}
