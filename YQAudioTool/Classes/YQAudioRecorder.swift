//
//  YQAudioRecorder.swift
//  YQAudioTool
//
//  Created by 王叶庆 on 2019/6/14.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import AVFoundation
public protocol YQAudioRecorderDelegate {
    func recorderDidStart(_ recorder: YQAudioRecorder)
    func recorderDidEnd(_ recorder: YQAudioRecorder)
    func recoreder(_ recorder: YQAudioRecorder, peakPower: Float, averagePower: Float)
}
public class YQAudioRecorder: NSObject {
    var recorder: AVAudioRecorder?
    public var fileURL: URL? {
        guard let relativePath = self.relativePath else {return nil}
        return mainURL.appendingPathComponent(relativePath)
    }
    public var mainURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("YQAudioRecorder")
    public var relativePath: String? = "\(UUID().uuidString).wav"
    public var delegate: YQAudioRecorderDelegate?
    public override init() {}
    private var isSessionActive = false
    private var timer: Timer?
    public func start() {
        guard let url = fileURL else {
            print("请指定relativePath")
            return
        }
        if !FileManager.default.fileExists(atPath: mainURL.path) {
            do {
                try FileManager.default.createDirectory(at: mainURL, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                print(error)
            }
        }
        AVAudioSession.sharedInstance().requestRecordPermission { (authorized) in
            DispatchQueue.main.async {
                guard authorized else {
                    print("请先授权")
                    return
                }
                AVAudioSession.active(true) { (success) in
                    guard success else {
                        return
                    }
                    self.isSessionActive = true
                    let settings: [String : Any] = [
                        AVSampleRateKey: NSNumber(value: 16000),//采样率
                        AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),//音频格式
                        AVLinearPCMBitDepthKey: NSNumber(value: 16),//采样位数
                        AVNumberOfChannelsKey: NSNumber(value: 1),//通道数
                        AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.medium.rawValue)
                    ]
                    self.stop()
                    do {
                        let dir = url.deletingLastPathComponent()
                        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                        self.recorder = try AVAudioRecorder(url: url, settings: settings)
                        self.recorder!.isMeteringEnabled = true
                        self.recorder!.delegate = self
                        guard self.recorder!.record() else {
                            print("无法开始录音")
                            return
                        }
                        if #available(iOS 10.0, *) {
                            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: {[weak self] (timer) in
                                guard let self = self else {return}
                                self.scheduleHandler(timer)
                            })
                        } else {
                            self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scheduleHandler(_:)), userInfo: nil, repeats: true)
                        }
                        self.delegate?.recorderDidStart(self)
                    } catch let error {
                        print(error)
                    }
                }

            }
        }
    }
    
    @objc func scheduleHandler(_ sender: Any) {
        guard let recorder = self.recorder else {
            return
        }
        recorder.updateMeters()
        delegate?.recoreder(self, peakPower: recorder.peakPower(forChannel: 0), averagePower: recorder.averagePower(forChannel: 0))
    }
    
    public func stop() {
        guard let recorder = self.recorder else {
            return
        }
        guard recorder.isRecording else {
            return
        }
        recorder.stop()
//        self.recorder = nil
//        didStop()
    }
    
    func didStop() {
        if isSessionActive {
            AVAudioSession.active(false) { (success) in
                guard success else {
                    return
                }
                self.isSessionActive = false
            }
        }
        timer?.invalidate()
        delegate?.recorderDidEnd(self)
    }
}

extension YQAudioRecorder: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        didStop()
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        guard let error = error else {
            print("录音发生未知错误")
            return
        }
        print(error)
        didStop()
    }
}

extension AVAudioSession {
    static func active(_ isActive: Bool, completionHandler:((Bool) ->())?) {
        let session = AVAudioSession.sharedInstance()
        if isActive {
            do {
                try session.setCategory(AVAudioSession.Category.record)
                try session.setActive(true)
                completionHandler?(true)
            } catch let error {
                print(error)
                completionHandler?(false)
            }

        } else {
            do {
                try session.setActive(false)
                completionHandler?(true)
            } catch let error {
                print(error)
                completionHandler?(false)
            }
        }
    }
}
