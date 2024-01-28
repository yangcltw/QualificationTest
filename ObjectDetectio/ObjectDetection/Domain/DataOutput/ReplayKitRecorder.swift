//
//  ReplayKitRecorder.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//

import Foundation
import ReplayKit

class ReplayKitRecorder: DataOutputProtocol{
    static let optionViewControllerKey = "viewcontroller"
    let recorder = RPScreenRecorder.shared()
    internal var isRecording = false
    var viewController: UIViewController?
    
    func setUp(with options: [String : Any]) {
        self.viewController = options[ReplayKitRecorder.optionViewControllerKey] as? UIViewController
    }
//    func set(root viewController: UIViewController) {
//        self.viewController = viewController
//    }
    func startRecording() {
        guard recorder.isAvailable else {
            print("Recording is not available at this time.")
            return
        }
        recorder.isMicrophoneEnabled = false
        
        recorder.startRecording{ [unowned self] (error) in
            
            guard error == nil else {
                let alert = UIAlertController(title: "Recording Error", message: error?.localizedDescription , preferredStyle: .alert)
                let OKAction = UIAlertAction(title: "OK", style: .default) { (action:UIAlertAction!) in
                        print("Ok button tapped");
                    }
                alert.addAction(OKAction)
                self.viewController?.present(alert, animated: true, completion: nil)

                print("There was an error starting the recording.")
                return
            }
            print("Started Recording Successfully")
            self.isRecording = true
        }
    }
    
    func stopRecording() {
        recorder.stopRecording { [unowned self] (preview, error) in
            print("Stopped recording")
            
            guard preview != nil else {
                print("Preview controller is not available.")
                return
            }
            
            let alert = UIAlertController(title: "Recording Finished", message: "Would you like to edit or delete your recording?", preferredStyle: .alert)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction) in
                self.recorder.discardRecording(handler: { () -> Void in
                    print("Recording suffessfully deleted.")
                })
            })
            
            let editAction = UIAlertAction(title: "Edit", style: .default, handler: { (action: UIAlertAction) -> Void in
                preview?.previewControllerDelegate = self.viewController as! any RPPreviewViewControllerDelegate
                self.viewController?.present(preview!, animated: true, completion: nil)
            })
            
            alert.addAction(editAction)
            alert.addAction(deleteAction)
            self.viewController?.present(alert, animated: true, completion: nil)
            self.isRecording = false
        }
        
    }
    
}

