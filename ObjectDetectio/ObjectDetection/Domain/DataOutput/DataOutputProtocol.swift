//
//  DataOutputProtocol.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/28.
//  Copyright © 2024 MachineThink. All rights reserved.
//

import Foundation

protocol DataOutputProtocol{
    var isRecording: Bool {get}
    func startRecording()
    func stopRecording()
}
