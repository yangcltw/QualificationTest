//
//  DataSourceProtocol.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/27.
//

import Foundation

protocol DataSourceProtocolDelegate: class {
  func videoCapture(from source: DataSourceProtocol, didCaptureVideoFrame: Any)
}

protocol DataSourceProtocol {
    var delegate: DataSourceProtocolDelegate? { get set }
    func setUp(with option: Any)
    func start()
    func stop()
    
}