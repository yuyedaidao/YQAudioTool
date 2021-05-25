//
//  YQAudioRecorder.swift
//  Sparrow
//
//  Created by 王叶庆 on 2021/5/24.
//

import Foundation
import AVFoundation
import lame

public protocol YQAudioRecorderDelegate: AnyObject {
    func recorderDidStart(_ recorder: YQAudioRecorder)
    func recorderDidEnd(_ recorder: YQAudioRecorder, fileURL: URL?, error: Error?)
    func recoreder(_ recorder: YQAudioRecorder, peakPower: Float, averagePower: Float)
}

extension YQAudioRecorderDelegate {
    func recorderDidStart(_ recorder: YQAudioRecorder) {}
    func recorderDidEnd(_ recorder: YQAudioRecorder, fileURL: URL?, error: Error?) {}
    func recoreder(_ recorder: YQAudioRecorder, peakPower: Float, averagePower: Float) {}
    
}
public class YQAudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL? {
        guard let relativePath = self.relativePath else {return nil}
        return mainURL.appendingPathComponent(relativePath)
    }
    private var mainURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("YQAudioRecorder")
    private var relativePath: String? = "\(UUID().uuidString).wav"
    
    public weak var delegate: YQAudioRecorderDelegate?
    public var checkMeters: Bool = false
    public override init() {}
    private var timer: Timer?
    private(set) var isMP3Format: Bool = false
    private var isMP3Active: Bool = false
    private var _isRecording: Bool = false
    
    public func start(isMP3Format: Bool = true) {
        guard activeSession() else {
            return
        }
        guard let url = fileURL else {
            #if DEBUG
            print("请指定relativePath")
            #endif
            return
        }
        if !FileManager.default.fileExists(atPath: mainURL.path) {
            do {
                try FileManager.default.createDirectory(at: mainURL, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                #if DEBUG
                print(error)
                #endif
                return
            }
        }
        AVAudioSession.sharedInstance().requestRecordPermission { (authorized) in
            DispatchQueue.main.async {
                guard authorized else {
                    print("请先授权")
                    return
                }
                let sampleRate: Int32 = 44100
                let channels: Int32 = 1 // MARK: 目前转码里是按单声道处理的先不要随意改动这里
                let settings: [String : Any] = [
                    AVSampleRateKey: NSNumber(value: sampleRate),// 采样率
                    AVFormatIDKey: NSNumber(value: kAudioFormatLinearPCM),// 音频格式
                    AVLinearPCMBitDepthKey: NSNumber(value: 16),// 采样位数
                    AVNumberOfChannelsKey: NSNumber(value: channels),// 通道数
                    AVEncoderAudioQualityKey: NSNumber(value: AVAudioQuality.high.rawValue)
                ]
                
                do {
                    let dir = url.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    let recorder = try AVAudioRecorder(url: url, settings: settings)
                    self.recorder = recorder
                    recorder.isMeteringEnabled = self.checkMeters
                    recorder.delegate = self
                    guard recorder.record() else {
                        print("无法开始录音")
                        return
                    }
                    self._isRecording = true
                    self.isMP3Format = isMP3Format
                    if isMP3Format {
                        self.convertRunning(with: url, channels: channels, sampleRate: sampleRate) {[weak self] (url) in
                            guard let self = self else {return}
                            self._isRecording = false
                            self.delegate?.recorderDidEnd(self, fileURL: url, error: nil)
                        }
                    }
                    if self.checkMeters {
                        if #available(iOS 10.0, *) {
                            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: {[weak self] (timer) in
                                guard let self = self else {return}
                                self.scheduleHandler(timer)
                            })
                        } else {
                            self.timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.scheduleHandler(_:)), userInfo: nil, repeats: true)
                        }
                    }
                    self.delegate?.recorderDidStart(self)
                } catch let error {
                    #if DEBUG
                    print(error)
                    #endif
                }
            }
        }
    }
    
    private func convertRunning(with fileURL: URL, channels: Int32, sampleRate: Int32, brate: Int32 =  128, completion: ((URL) -> ())?) {
        isMP3Active = true
        let path = fileURL.path
        let mp3Path = path.replacingOccurrences(of: "wav", with: "mp3")
        do {
            if FileManager.default.fileExists(atPath: mp3Path) {
                try FileManager.default.removeItem(atPath: mp3Path)
            }
        } catch let error {
            #if DEBUG
            print(error)
            #endif
        }
        var total = 0
        var read = 0
        var write: Int32 = 0
        let skip = 4 * 1024
        var pcm: UnsafeMutablePointer<FILE> = fopen(fileURL.path, "rb")
        fseek(pcm, skip, SEEK_CUR) // 掐头
        let mp3: UnsafeMutablePointer<FILE> = fopen(mp3Path, "wb")
        let PCM_SIZE: Int = 8192
        let MP3_SIZE: Int32 = 8192
        let pcmbuffer = UnsafeMutablePointer<Int16>.allocate(capacity: Int(PCM_SIZE*2))
        let mp3buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MP3_SIZE))

        let lame = lame_init()
        lame_set_num_channels(lame, channels)
        lame_set_mode(lame, MONO)
        lame_set_in_samplerate(lame, sampleRate)
        lame_set_brate(lame, brate)
        lame_set_VBR(lame, vbr_off)
        lame_init_params(lame)

        DispatchQueue.global(qos: .default).async {
            while true {
                pcm = fopen(path, "rb")
                fseek(pcm, skip + total, SEEK_CUR)
                read = fread(pcmbuffer, MemoryLayout<Int16>.size, PCM_SIZE, pcm)
                if read != 0 {
                    write = lame_encode_buffer(lame, pcmbuffer, nil, Int32(read), mp3buffer, MP3_SIZE)
                    #if DEBUG
                    if write < 0 {
                        print("write \(write)")
                    }
                    #endif
                    fwrite(mp3buffer, Int(write), 1, mp3)
                    total += read * MemoryLayout<Int16>.size
                    fclose(pcm)
                } else if !self.isMP3Active {
                    write = lame_encode_flush(lame, mp3buffer, MP3_SIZE)
                    fwrite(mp3buffer, Int(write), 1, mp3)
                    break
                } else {
                    fclose(pcm)
                    usleep(50)
                }
            }
            lame_close(lame)
            fclose(mp3)
            fclose(pcm)
            DispatchQueue.main.async {
                completion?(URL(fileURLWithPath: mp3Path))
            }
        }
    }
    
    
    @objc private func scheduleHandler(_ sender: Any) {
        guard let recorder = self.recorder else {
            return
        }
        recorder.updateMeters()
        delegate?.recoreder(self, peakPower: recorder.peakPower(forChannel: 0), averagePower: recorder.averagePower(forChannel: 0))
    }
    
    public var isRecording: Bool {
        return _isRecording
    }
    
    public func stop() {
        guard let recorder = self.recorder else {
            return
        }
        guard recorder.isRecording else {
            return
        }
        recorder.stop()
    }
    
    private func didStop(_ error: Error?) {
        timer?.invalidate()
        if isMP3Format {
            isMP3Active = false
            guard let error = error else {
                return
            }
            _isRecording = false
            delegate?.recorderDidEnd(self, fileURL: fileURL, error: error)
        } else {
            _isRecording = false
            delegate?.recorderDidEnd(self, fileURL: fileURL, error: error)
        }
    }
    
    func activeSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord)
            try session.setActive(true)
            return true
        } catch let error {
            #if DEBUG
            print(error)
            #endif
            return false
        }
    }
}

extension YQAudioRecorder: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        #if DEBUG
        print("successfully \(flag)")
        #endif
        didStop(nil)
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        #if DEBUG
        if let error = error {
            print(error)
        }
        #endif
        didStop(error)
    }
}
