//
//  VideoSourceSelectionViewController.swift
//  ObjectDetection
//
//  Created by Bart Yang on 2024/1/29.
//  Copyright © 2024 MachineThink. All rights reserved.
//

import Foundation
import UIKit
import PhotosUI

class VideoSourceSelectionViewController: UIViewController, PHPickerViewControllerDelegate {
    
    
    var stackView = UIStackView()
    var cameraSourceButton = UIButton(type: .custom)
    var inAppSourceButton = UIButton(type: .custom)
    var photosSourceButton = UIButton(type: .custom)
    
    init(){
        
        super.init(nibName: nil, bundle: nil)
        stackView = UIStackView(frame: .zero)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 40
        view.addSubview(stackView)
        stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 200).isActive = true
        stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.widthAnchor.constraint(equalToConstant: 200).isActive = true
        stackView.heightAnchor.constraint(equalToConstant: 240).isActive = true
        
        cameraSourceButton.addTarget(self, action: #selector(cameraSourceClick), for: .touchUpInside)
        cameraSourceButton.layer.cornerRadius = 5
        cameraSourceButton.layer.borderWidth = 1
        cameraSourceButton.layer.borderColor = UIColor.darkGray.cgColor
        cameraSourceButton.setTitleColor(.darkGray, for: .normal)
        cameraSourceButton.setTitle("Camera", for: .normal)
        
        inAppSourceButton.addTarget(self, action: #selector(inAppSourceClick), for: .touchUpInside)
        inAppSourceButton.layer.cornerRadius = 5
        inAppSourceButton.layer.borderWidth = 1
        inAppSourceButton.layer.borderColor = UIColor.darkGray.cgColor
        inAppSourceButton.setTitleColor(.darkGray, for: .normal)
        inAppSourceButton.setTitle("In app video", for: .normal)
        
        photosSourceButton.addTarget(self, action: #selector(photosSourceClick), for: .touchUpInside)
        photosSourceButton.layer.cornerRadius = 5
        photosSourceButton.layer.borderWidth = 1
        photosSourceButton.layer.borderColor = UIColor.darkGray.cgColor
        photosSourceButton.setTitleColor(.darkGray, for: .normal)
        photosSourceButton.setTitle("Photos", for: .normal)
        
        stackView.addArrangedSubview(cameraSourceButton)
        stackView.addArrangedSubview(inAppSourceButton)
        stackView.addArrangedSubview(photosSourceButton)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
    }
    
    override func viewDidLoad() {
        //        stackView.frame = self.view.frame
        //        view.addSubview(stackView)
        // Disable Dark Mode for this view controller
        overrideUserInterfaceStyle = .light
        self.view.backgroundColor = .white
    }
    
    // MARK: - Click
    @objc func cameraSourceClick(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController {
            self.navigationController?.pushViewController(vc, animated: true) {
                vc.setUpCamera()
            }
        }
    }
    
    @objc func inAppSourceClick(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController {
            self.navigationController?.pushViewController(vc, animated: true) {
                vc.setUpUrl()
            }
        }
    }
    
    @objc func photosSourceClick(_ sender: UIButton) {
        let photoLibrary = PHPhotoLibrary.shared()
        var configuration = PHPickerConfiguration(photoLibrary: photoLibrary)
        configuration.filter = .videos
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        let identifiers = results.compactMap(\.assetIdentifier)
        guard let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil).firstObject else {
            return
        }
        PHCachingImageManager().requestAVAsset(forVideo: fetchResult , options: nil, resultHandler: {(asset, audioMix, info) -> Void in
            if asset != nil {
                let avasset = asset as! AVURLAsset
                let urlVideo = avasset.url
                DispatchQueue.main.async {
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    if let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController {
                        self.navigationController?.pushViewController(vc, animated: true) {
                            vc.setUpPhtos(with: avasset )
                        }
                    }
                }
            }
        })
    }
    
    
}
