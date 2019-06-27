//
//  YQAudioPlayer.swift
//  YQAudioTool
//
//  Created by 王叶庆 on 2019/6/27.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Foundation
import AVFoundation
public enum YQAudioPlayerStatus {
    case unknow
    case failed
    case readyToPlay
    case didPlayToEnd
    case timeJumped
}
public protocol YQAudioPlayerDelegate: AnyObject {
    func audioPlayer(_ player: YQAudioPlayer, status: YQAudioPlayerStatus)
    func audioPlayer(_ player: YQAudioPlayer, seconds: Double)
}

public class YQAudioPlayer: NSObject {
    public var url: URL? {
        didSet {
            isItemChanged = true
        }
    }
    private var isItemChanged: Bool = true
    private var player: AVPlayer?
    public weak var delegate: YQAudioPlayerDelegate?
    public var currentItemDuration: Double? {
        return self.player?.currentItem?.duration.seconds
    }
    private var didAddObserverItems: Set<AVPlayerItem> = []
    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationHandler(_:)), name: .AVPlayerItemTimeJumped, object: nil)

    }
    public func play() {
        if isItemChanged {
            guard let url = self.url else {
                return
            }
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 6000), queue: nil, using: { [weak self](time) in
                guard let self = self else {return}
                self.delegate?.audioPlayer(self, seconds: time.seconds)
            })
            if let item = player?.currentItem {
                addObserver(for: item)
            }
    
            player?.play()
            isItemChanged = false
        } else {
            guard let item = player?.currentItem else {
                return
            }
            addObserver(for: item)
            player?.play()
        }
    }
    
    public func pause() {
        self.player?.pause()
    }
    
    public func seek(_ seconds: Double) {
        self.player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 6000))
    }
    
    @objc func notificationHandler(_ sender: Notification) {
        switch sender.name {
        case .AVPlayerItemDidPlayToEndTime:
            removeObservers()
            delegate?.audioPlayer(self, status: .didPlayToEnd)
        case .AVPlayerItemTimeJumped:
            delegate?.audioPlayer(self, status: .timeJumped)
        default:
            return
        }
    }
    func addObserver(for item: AVPlayerItem) {
        if !didAddObserverItems.contains(item) {
            item.addObserver(self, forKeyPath: "status", options: .new, context: nil)
        }
        didAddObserverItems.insert(item)
    }
    func removeObservers() {
        for item in didAddObserverItems {
            item.removeObserver(self, forKeyPath: "status")
        }
        didAddObserverItems.removeAll()
    }
    
    deinit {
        removeObservers()
        player = nil
    }
}

extension YQAudioPlayer {
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "status", let item = player?.currentItem else {return}
        switch item.status {
        case .unknown:
            delegate?.audioPlayer(self, status: .unknow)
        case .failed:
            delegate?.audioPlayer(self, status: .failed)
        case .readyToPlay:
            delegate?.audioPlayer(self, status: .readyToPlay)
        @unknown default:
            break
        }
    }
}
