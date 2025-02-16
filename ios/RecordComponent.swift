//
//  RecordComponent.swift
//  ScreenRecord
//
//  Created by Matthew Ruiz on 3/30/21.
//

import Foundation
import ReplayKit
import React

@objc(RecordComponent)
class RecordComponent: RCTViewManager {
  let recorder = RPScreenRecorder.shared()
  private var isRecording = false
  let button: UIButton = UIButton()
  var assetWriter: AVAssetWriter!
  var videoInput: AVAssetWriterInput!
  var isWritingStarted: Bool = false
  var fileName: String?
  public static var gfileURL: URL?
  
  override func view() -> UIView! {
    if #available(iOS 12.0, *) {
      button.setup(title: "Record", x: 100, y: 430, width: 220, height: 80, color: UIColor.red)
      button.addTarget(self, action: #selector(RecordComponent.pressed(sender:)), for: .touchUpInside)
      return button
    } else {
      let label = UILabel()
      label.text = "Screen Recording Not Supported"
      return label
    }
  }
  
  @objc func pressed(sender: UIButton!) {
    if (self.isRecording) {
      stopRecording()
    } else {
      startRecording()
    }
  }
  
  @objc func startRecording() {
    guard recorder.isAvailable else {
        print("Recording is not available at this time.")
        return
    }
    fileName = "test_file\(Int.random(in: 10 ..< 1000))"
    let fileURL = URL(fileURLWithPath: filePath(fileName!))
    RecordComponent.gfileURL = fileURL
    assetWriter = try! AVAssetWriter(outputURL: fileURL, fileType: AVFileType.mp4)

    if #available(iOS 11.0, *) {
      let videoOutputSettings: Dictionary<String, Any> = [
        AVVideoCodecKey : AVVideoCodecType.h264,
        AVVideoWidthKey : UIScreen.main.bounds.size.width,
        AVVideoHeightKey : UIScreen.main.bounds.size.height
      ]
      videoInput  = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
      videoInput.expectsMediaDataInRealTime = true
      if let canAddInput = assetWriter?.canAdd(videoInput), canAddInput {
        assetWriter.add(videoInput)
      }
  
      recorder.startCapture(handler: { (sample, bufferType, error) in
        if CMSampleBufferDataIsReady(sample) {
          if self.assetWriter.status == AVAssetWriter.Status.unknown {
            self.isRecording = true
            self.assetWriter.startWriting()
            self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sample))
          } else if self.assetWriter.status == AVAssetWriter.Status.writing {
            if (bufferType == .video) {
              if self.videoInput.isReadyForMoreMediaData {
                self.videoInput.append(sample)
              } else {
                print("not ready for more data")
              }
            } else {
              print("buffer type: \(bufferType.rawValue)")
            }
          }
          
          if self.assetWriter.status == AVAssetWriter.Status.failed {
            print("Error occured, status = \(self.assetWriter.status.rawValue), \(self.assetWriter.error!.localizedDescription) \(String(describing: self.assetWriter.error))")
            return
          }
        }
        
      }) { (error) in
        debugPrint(error as Any)
      }
      self.isRecording = true
    } else {
      // Fallback on earlier versions
    }
  }
  
  @objc func stopRecording() {
    if #available(iOS 11.0, *) {
      RPScreenRecorder.shared().stopCapture { (error) in
        self.assetWriter.finishWriting {
          print(SharedFileSystemRCT.fetchAllReplays())
        }
      }
    }
    self.isRecording = false
  }
  
  func filePath(_ fileName: String) -> String
  {
    createReplaysFolder()
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0] as String
    let filePath : String = "\(documentsDirectory)/Replays/\(fileName).mp4"
    return filePath
  }
  
  func createReplaysFolder()
  {
     let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
     if let documentDirectoryPath = documentDirectoryPath {
        // create the custom folder path
        let replayDirectoryPath = documentDirectoryPath.appending("/Replays")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: replayDirectoryPath) {
          do {
            try fileManager.createDirectory(atPath: replayDirectoryPath, withIntermediateDirectories: false, attributes: nil)
            print("Created DIR")
          } catch {
            print("Error creating Replays folder in documents dir: \(error)")
          }
       }
     }
  }
}

extension UIButton {
    func setup(title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: UIColor){
        frame = CGRect(x: x, y: y, width: width, height: height)
        backgroundColor = color
        setTitle(title , for: .normal)
        }
    }
