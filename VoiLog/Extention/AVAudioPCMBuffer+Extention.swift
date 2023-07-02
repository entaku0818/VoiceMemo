//
//  AVaudio.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2.7.2023.
//

import AVFoundation
import Accelerate

extension AVAudioPCMBuffer {
    var waveFormHeight: CGFloat {
        let samples = floatChannelData!.pointee
        var avgValue: Float = 0
        vDSP_meamgv(samples, 1, &avgValue, UInt(frameLength))
        let meterLevel = CGFloat(avgValue * 1)
        return min(meterLevel * 30, 30)
    }
}
