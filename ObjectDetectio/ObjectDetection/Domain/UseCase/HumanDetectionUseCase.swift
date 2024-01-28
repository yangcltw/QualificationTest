//
//  HumanDetectionUseCase.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//  Copyright © 2024 MachineThink. All rights reserved.
//

import Foundation
import Vision
import UIKit

class HumanDetectionUseCase {
    
    static let shared = HumanDetectionUseCase()
    var timer: Timer?
    var recorder: DataOutputProtocol?
    init() {
        recorder = ReplayKitRecorder()
        // TODO: think if there is better way to do so
        if let viewController = UIApplication.shared.windows.first?.rootViewController {
            (recorder as! ReplayKitRecorder).set(root: viewController)
        }
        
    }
    func detectObject(with predictions: [VNRecognizedObjectObservation]) {
        
        if (predictions.filter({$0.labels[0].identifier ==
            "person"}).count > 0) {
            
            self.startTimer()
            if(!recorder!.isRecording) {
                recorder?.startRecording()
            }
        }
        
    }
    
    // TODO: refine
    func dataSourceInterrupt(with reason: Int) {
        stopTimer()
        if(recorder!.isRecording) {
            recorder?.stopRecording()
        }
        
    }
    
    func startTimer() {
        // Invalidate existing timer if it exists
        timer?.invalidate()
        
        // Start a new timer that fires every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            print("Timer fired!")
            self.stopTimer()
            self.recorder?.stopRecording()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
