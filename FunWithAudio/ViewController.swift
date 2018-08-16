//
//  ViewController.swift
//  FunWithAudio
//
//  Created by boland on 8/7/18.
//  Copyright © 2018 International Business Machines Corp. All rights reserved.
//

import UIKit
import AVKit

class ViewController: UIViewController {

    @IBOutlet weak var volumeMeterHeight: NSLayoutConstraint!
    @IBOutlet weak var recordButton: UIButton!
    let pauseImageHeight: Float = 26.0
    var engine = AVAudioEngine()
    var distortion = AVAudioUnitDistortion()
    var reverb = AVAudioUnitReverb()
    var audioBuffer = AVAudioPCMBuffer()
    var outputFile = AVAudioFile()
    var delay = AVAudioUnitDelay()
    var updater: CADisplayLink?

    var isRunning: Bool = false
    var currentPosition: AVAudioFramePosition = 0
    var seekFrame: AVAudioFramePosition = 0
    let minDb: Float = -80.0

    
    func initializeAudio() {
        engine.stop()
        engine.reset()
        engine = AVAudioEngine()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default, options: [.mixWithOthers, .defaultToSpeaker])
           // try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
            
            let ioBufferDuration = 128.0 / 44100.0
            
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(ioBufferDuration)
            
        } catch {
            
            assertionFailure("AVAudioSession setup error: \(error)")
        }
        
        //TODO: do the proper saving and routing of the file name and the location
        let fileUrl = createURL(fileName: "/testing.caf")
        print("url name \(fileUrl?.absoluteString)")
        do {
            try outputFile = AVAudioFile(forWriting:  fileUrl!, settings: engine.mainMixerNode.outputFormat(forBus: 0).settings)
        }
        catch {
            print("error on making the save path homeslice \(outputFile)")
        }
        
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        
        //settings for reverb
        reverb.loadFactoryPreset(.mediumChamber)
        reverb.wetDryMix = 40 //0-100 range
        engine.attach(reverb)
        
        delay.delayTime = 0.2 // 0-2 range
        engine.attach(delay)
        
        //settings for distortion
        distortion.loadFactoryPreset(.drumsBitBrush)
        distortion.wetDryMix = 20 //0-100 range
        engine.attach(distortion)
        
        
        engine.connect(input, to: reverb, format: format)
        engine.connect(reverb, to: distortion, format: format)
        engine.connect(distortion, to: delay, format: format)
        engine.connect(delay, to: engine.mainMixerNode, format: format)
        
        do {
             try engine.start()
        } catch {
            print("some sort of issue going on here")
        }
        
    }
    
    func start() {
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        
        mixer.installTap(onBus: 0, bufferSize: 1024, format: format, block:
            { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

                print("writing \(time)")
                do {
                    try self.outputFile.write(from: buffer)
                }
                catch {
                    print(NSString(string: "Write failed"));
                }
        })
    }
    
    func stop() {
            
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeAudio()
        updater = CADisplayLink(target: self, selector: #selector(updateUI))
        updater?.add(to: .current, forMode: .defaultRunLoopMode)
        updater?.isPaused = true
    }
    
    func createURL(fileName: String) -> URL? {
        let paths = FileManager.default.urls(for: .documentDirectory, in:.userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    @objc func updateUI() {
        print("update UI")
//        currentPosition = currentFrame + seekFrame
//        currentPosition = max(currentPosition, 0)
//        currentPosition = min(currentPosition, audioLengthSamples)
//
//        progressBar.progress = Float(currentPosition) / Float(audioLengthSamples)
//        let time = Float(currentPosition) / audioSampleRate
//        countUpLabel.text = formatted(time: time)
//        countDownLabel.text = formatted(time: audioLengthSeconds - time)
//
//        if currentPosition >= audioLengthSamples {
//            player.stop()
//            updater?.isPaused = true
//            playPauseButton.isSelected = false
//            disconnectVolumeTap()
//        }
    }
    
    func connectVolumeTap() {
        let format = engine.mainMixerNode.outputFormat(forBus: 1)
        engine.mainMixerNode.installTap(onBus: 1, bufferSize: 1024, format: format) { buffer, when in
            
            guard let channelData = buffer.floatChannelData,
                let updater = self.updater else {
                    return
            }
            
            let channelDataValue = channelData.pointee
            let channelDataValueArray = stride(from: 0,
                                               to: Int(buffer.frameLength),
                                               by: buffer.stride).map{ channelDataValue[$0] }
            let rms = sqrt(channelDataValueArray.map{ $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)
            let meterLevel = self.scaledPower(power: avgPower)
            
            DispatchQueue.main.async {
                self.volumeMeterHeight.constant = !updater.isPaused ? CGFloat(min((meterLevel * self.pauseImageHeight),
                                                                                  self.pauseImageHeight)) : 0.0
            }
        }
    }
    
    // MARK: IBActions
    
    @IBAction func startButtonWasTriggered() {
        if !isRunning {
            isRunning = true
            start()
            //  connectVolumeTap()
            recordButton.setTitle("Stop", for: .normal)
            
        } else {
            isRunning = false
            stop()
            recordButton.setTitle("Record", for: .normal)
        }
    }
    
    // MARK: Helper Methods
    
    func scaledPower(power: Float) -> Float {
        // 1
        guard power.isFinite else { return 0.0 }
        
        // 2
        if power < minDb {
            return 0.0
        } else if power >= 1.0 {
            return 1.0
        } else {
            // 3
            return (fabs(minDb) - fabs(power)) / fabs(minDb)
        }
    }


}

