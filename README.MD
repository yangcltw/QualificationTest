
# Clone the sample code from github after getting assignment

- The sample code is using AVCaptureSession to get image from iphone camera，and transfer datat to  AVCaptureVideoDataOutput (https://developer.apple.com/documentation/avfoundation/capture_setup/setting_up_a_capture_session)
	- In beggining, I try to find if it possible to using file as [AVCaptureInput] (https://stackoverflow.com/questions/24335298/can-i-use-avcapturesession-to-read-a-video-from-a-file). However, the assignment has mention we need use AVAssetReader to extract frame as (CVPixelBuffer), I won't keep going to research this apporach. 

- Using predict() function from ViewController after get image buffer to detect object. Show the boundingBoxViews according to VNRecognizedObjectObservation from predict function. 
	- There is one option that using kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix to get camera matrix_float3x3. Just wondering if it will impact the object detection since we need using static image instead of hardware device.


# Requirment Analysis
- Load video from mp4
	- AVAssetReader
- recording video once detect person(s)
- Migrate video and bounding boxes
	- Using ReplayKit to record?
	- Using	AVFoundation by manage CVPixelBuffer and AVAssetWritter
	- how about audio if original video contain??
- save to photos
	- Using photoKit


# Design 
- DataSource interface that can accept different video sources
- DataOutput interface that can accept different managed source and output to mp4

## Attention Need
- audio of output video and AV sync?
- coordinate mapping between source -> Vision -> output


# Task breakdown
## Input Data Source
> The data source can be different type of input

- [x] T1 - Design command interface to input data source
- [x] T2 - move AVCaptureSession to be an implementation
- [x] T3 - Implement input data source by AVAssetReader
	- Found not handling preview window
	- Found the playing speed is not correct
	- Found the size of preview window is not correct

## Record Video if detect person(s)
- [x] T4 - Using ReplayKit to record video
	- [Reference](https://github.com/appcoda/ReplayKitDemo/blob/master/ScreenRecord/ViewController.swift) 
- [x] T4_1 - Using AVAssetWriter to record video
	- [Reference](https://gist.github.com/kylehowells/31c40eea38209d751f4d4b02ba7dbf65) 
- [ ] T5 - Saving to user album

## change to MVVM
- [ ] T6 - change to MVVM

## Record Video using AVFondation



# Retrospective
- Same as every real project : No time to write test!



