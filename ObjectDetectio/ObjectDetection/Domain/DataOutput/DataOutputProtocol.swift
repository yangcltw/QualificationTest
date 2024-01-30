//
//  DataOutputProtocol.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//

import Foundation

protocol DataOutputProtocol{
    var isRecording: Bool {get}
    func setup(with options: [String : Any])
    func startRecording()
    func stopRecording()
}
