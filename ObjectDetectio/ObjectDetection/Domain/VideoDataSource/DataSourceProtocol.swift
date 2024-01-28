//
//  DataSourceProtocol.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/27.
//

import Foundation
import QuartzCore

protocol DataSourceProtocolDelegate: class {
    func videoCapture(from source: DataSourceProtocol, didCaptureVideoFrame: Any)
    func adjustVideoContentSize(with size: CGSize)
    func complete(with status: Int)
}

protocol DataSourceProtocol {
    var delegate: DataSourceProtocolDelegate? { get set }
    var previewLayer: CALayer? { get set }
    func setUp(with option: [String : Any], completion: @escaping (Bool) -> Void)
    func start()
    func stop()
    
}
