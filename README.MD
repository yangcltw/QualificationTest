
# System Requirment
- iOS 14 above
- Xcode 15.2
- Please change to your testing bundle id and development team

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

## Record Video if detect person(s) and save to Photos
- [x] T4 - Using ReplayKit to record video
	- [Reference](https://github.com/appcoda/ReplayKitDemo/blob/master/ScreenRecord/ViewController.swift) 
- [x] T4_1 - Using AVAssetWriter to record video
	- [Reference](https://gist.github.com/kylehowells/31c40eea38209d751f4d4b02ba7dbf65) 
	- [result] (https://github.com/yangcltw/QualificationTest/blob/main/T4_1_recording_result.mp4)
- [x] T5 - Saving to user album

> Found alernative soultion to record screen: [FlipBook](https://github.com/bgayman/FlipBook/tree/master)

## Known issues from high to low (for user perspective instead of qualified test)

- Only handle video data
	- Only handle video data so the recorded mp4 is video only without audio data

- UI issues
	- can't pause the app except terminate it
	- no localization

- Video Playing Speed
	- It is slower than original video because I use simple way to control the flow. I'm using delay between two frames. Howerver, this way is not considering the time of processing image. It can using global timer to determinate the frame is need to be display/delay/drop.
	```
	while self.reader.status == .reading {
		if let sampleBuffer = self.readerOutput.copyNextSampleBuffer(){
			let currentPTS = self.getPTS(from: sampleBuffer)
			let diffPTS = CMTimeGetSeconds(currentPTS) - CMTimeGetSeconds(previousPTS)
			if (diffPTS) > 0 && (diffPTS) < 1 {
				Thread.sleep(forTimeInterval: diffPTS)
			}
			DispatchQueue.main.async {
				self.delegate?.videoCapture(from: self, didCaptureVideoFrame: sampleBuffer)
				if let image = self.imageFromSampleBuffer(sampleBuffer) {
					self.previewLayer?.contents = image.cgImage
				}
			}
			previousPTS = currentPTS
		}
	}
	```
- Performance issues
	- There are some delays while recording video. Try to move VideoWriter to thread later

- Not handle iOS life Cycles
	- only implement happy path: open the app -> load the video -> play and record new video -> play complete. App is not handle app enter background and back or some interrupt e.g. incoming call... 

- ReplayKit crashes
	- ReplayKit will crash if add timer to control human detection. Current implementation will clear original recorder and create new one. It is because new record needs new AVAssetWriter. ReplayKit will crash at closure of stopRecording because the last one is been release.

## Refactor
- [x] T6 - Look at current architecture and refine.
	- Current version mix all logic in ViewController
![Current Version](https://github.com/yangcltw/QualificationTest/blob/main/Current_Flow.png)
<br>

	- Better version split out the business logic out of ViewController. The use case keep preview window with orignal resolution so that the recording video could get better resolution according to setting(if need). The ViewCotroller get copy of preview window and scale to display on screen
![Better Version](https://github.com/yangcltw/QualificationTest/blob/main/Better_Flow.png)
<br>

	- The best way in my mind is manipulate pixel buffer directly and record it with same PTS(DTS). 
![Best Version](https://github.com/yangcltw/QualificationTest/blob/main/Best_Flow.png)
<br>

```
func drawRectangleOnPixelBuffer(pixelBuffer: CVPixelBuffer) {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let alphaInfo = CGImageAlphaInfo.premultipliedFirst.rawValue

    CVPixelBufferLockBaseAddress(pixelBuffer, 0)
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                  space: colorSpace,
                                  bitmapInfo: alphaInfo) else {
        return
    }

    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
}
```

- [ ] T7 - Refactor & bug fix
	- [ ] T7_1 TBD item - The recroding timer needed been discuss because for Requirement3, it need to recording 10s video once persion detect. The optional 6, it stop video after 5 sec after last person detected. It conflict if the person only show up 1 second and no more persion detect, the recorded video will be 6 sec ~ 7 sec. So I'm keeping the original implementation that reset 5 sec timer once person detected.
	- [x] T7_2 refactor - Add source selection
	- [x] T7_3 refactor - Bugfix: source from camera can't be recorded. Refactor: code clean up
	- [ ] T7_4 refactor 
		- Change architecture to better one. There are two bugs
		1. The result view can't show on screen
		2. not recorded the video

# Retrospective
- Same as every real project : No time to write test!
- Naming : No time and teams to dicuss the naming
- No code review


