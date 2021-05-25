//
//  ViewController.swift
//  YQAudioTool
//
//  Created by wyqpadding@gmail.com on 06/14/2019.
//  Copyright (c) 2019 wyqpadding@gmail.com. All rights reserved.
//

import UIKit
import YQAudioTool

class ViewController: UIViewController {

    @IBOutlet weak var playButton: UIButton!
    let recorder = YQAudioRecorder()
    let player = YQAudioPlayer()
    var outputURL: URL?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        recorder.delegate = self
    
        print(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask))
    }

    @IBAction func playAction(_ sender: UIButton) {
        if sender.isSelected {
            recorder.stop()
        } else {
            recorder.start(isMP3Format: false)
        }
//        sender.isSelected = !sender.isSelected
    }
    
    @IBAction func playRecord(_ sender: Any) {
        guard let url = outputURL else {
            return
        }
        player.url = url
        player.delegate = self
        player.play()
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(2)) {
            self.player.seek(6)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController: YQAudioRecorderDelegate {
    func recorderDidEnd(_ recorder: YQAudioRecorder, fileURL: URL?, error: Error?) {
        print("结束记录")
        playButton.isSelected = false
        outputURL = fileURL
    }
    
    func recorderDidStart(_ recorder: YQAudioRecorder) {
        print("开始记录")
        playButton.isSelected = true
    }
    
    func recoreder(_ recorder: YQAudioRecorder, peakPower: Float, averagePower: Float) {
        print("peak: \(peakPower) average: \(averagePower)")
    }
}

extension ViewController: YQAudioPlayerDelegate {
    func audioPlayer(_ player: YQAudioPlayer, status: YQAudioPlayerStatus) {
        print(status)
    }
    
    func audioPlayer(_ player: YQAudioPlayer, seconds: Double) {
        print(seconds)
    }
}
