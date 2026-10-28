//· TestAudio ·
// Ficheros de audio de prueba, escritos al vuelo, y una carpeta de sonidos propios de usar y tirar:
// los usan los tests de los sonidos propios

import AVFoundation
import Foundation
@testable import Tics

/// Un wav mono a 48 kHz (otro formato que el del motor): `silence` segundos callado y luego `tone`
/// segundos de un tono de 440 Hz
func testWav(silence: Double, tone: Double, name: String = "prueba.wav") throws -> URL {
    let rate = 48_000.0
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(name)")
    let fileFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
    let file = try AVAudioFile(forWriting: url, settings: fileFormat.settings)
    let frames = Int((silence + tone) * rate)
    let buffer = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: AVAudioFrameCount(frames))!
    let quiet = Int(silence * rate)
    for i in 0..<frames {
        buffer.floatChannelData![0][i] = i < quiet ? 0 : 0.5 * Float(sin(2 * .pi * 440 * Double(i - quiet) / rate))
    }
    buffer.frameLength = AVAudioFrameCount(frames)
    try file.write(from: buffer)
    return url
}

/// Un almacén de sonidos propios en su propia carpeta temporal, como la de Application Support
func makeTestStore() -> CustomSoundStore {
    CustomSoundStore(
        folder: FileManager.default.temporaryDirectory.appendingPathComponent("tics-sonidos-\(UUID().uuidString)"),
        format: AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    )
}
