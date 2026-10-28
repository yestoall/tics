//· PackLeveling ·
// Sonidos de un pack a la altura de otro: de un pack a otro las teclas cambian hasta 13 veces de
// volumen (ver Loudness), y así se pueden mezclar sonidos de packs distintos. También lo que hace
// falta antes de igualarlos: quedarse con una parte del pack y cambiarle el tono.

import Accelerate
import AVFoundation

extension LoadedPack {
    /// Lo que suena una tecla típica del pack al pulsarla: la altura a la que se ponen el ratón y
    /// los sonidos de otros packs
    var typicalLoudness: Float {
        Loudness.typical(of: down.values.flatMap { $0 } + fallbackDown)
    }

    /// Hasta dónde puede subir una muestra al igualar: más arriba, la salida satura
    static let maxPeak: Float = 0.99

    /// Solo las teclas de un grupo, con lo que suena en cada una. En las normales se queda el
    /// sonido de reserva; las del espacio, Return y las anchas que no tienen el suyo se quedan con él
    func only(_ group: KeyGroup) -> LoadedPack {
        var result = LoadedPack()
        result.down = down.filter { KeyGroup(keyCode: $0.key) == group }
        result.up = up.filter { KeyGroup(keyCode: $0.key) == group }
        switch group {
        case .normal:
            result.fallbackDown = fallbackDown
            result.fallbackUp = fallbackUp
        case .space, .enter, .wide:
            for key in group.keys where result.down[key] == nil {
                result.down[key] = fallbackDown
                result.up[key] = fallbackUp
            }
        }
        return result
    }

    /// Solo lo que se usa de un pack de origen, y el sonido de reserva, que es lo que suena en las
    /// teclas que no tienen el suyo
    func only(_ use: SourceUse) -> LoadedPack {
        func isUsed(_ key: UInt16) -> Bool { use.keys.contains(key) || use.groups.contains(KeyGroup(keyCode: key)) }
        var result = self
        result.down = down.filter { isUsed($0.key) }
        result.up = up.filter { isUsed($0.key) }
        return result
    }

    /// Una copia con todos sus sonidos remuestreados (ver `PackLoader.pitched`)
    func pitched(by pitch: Double) -> LoadedPack {
        guard pitch != 1 else { return self }
        return mapBuffers { (try? PackLoader.pitched($0, by: pitch)) ?? $0 }
    }

    /// Una copia con todos sus sonidos a la vez subidos o bajados, para que al pulsar suenen a
    /// `target` (en la escala de Loudness). Si sus picos no dejan, se quedan algo por debajo antes
    /// que saturar. Así se mantiene lo que suenan unas teclas frente a otras
    func leveled(to target: Float) -> LoadedPack {
        // Medido como `typicalLoudness`: después, es `target`
        let presses = down.values.flatMap { $0 } + fallbackDown
        let releases = up.values.flatMap { $0 } + fallbackUp
        let gain = Self.gain(presses: presses, releases: releases, to: target) ?? 1
        return mapBuffers { Self.copy($0, gain: gain) }
    }

    //- Ayudas -

    /// Una copia con `transform` en cada sonido. Un mismo sonido puede estar en varias teclas: se
    /// transforma una vez
    private func mapBuffers(_ transform: (AVAudioPCMBuffer) -> AVAudioPCMBuffer) -> LoadedPack {
        var copies: [ObjectIdentifier: AVAudioPCMBuffer] = [:]
        func mapped(_ list: [AVAudioPCMBuffer]) -> [AVAudioPCMBuffer] {
            list.map { buffer in
                if let copy = copies[ObjectIdentifier(buffer)] { return copy }
                let copy = transform(buffer)
                copies[ObjectIdentifier(buffer)] = copy
                return copy
            }
        }
        var result = LoadedPack()
        result.down = down.mapValues(mapped)
        result.up = up.mapValues(mapped)
        result.fallbackDown = mapped(fallbackDown)
        result.fallbackUp = mapped(fallbackUp)
        return result
    }

    /// Lo que hay que multiplicar para que las pulsaciones suenen a `target` sin que ningún pico
    /// pase de `maxPeak`; nil si no suenan
    private static func gain(presses: [AVAudioPCMBuffer], releases: [AVAudioPCMBuffer], to target: Float) -> Float? {
        let loudness = Loudness.typical(of: presses)
        let peak = (presses + releases).map(peak).max() ?? 0
        guard loudness > 0, peak > 0 else { return nil }
        return min(target / loudness, maxPeak / peak)
    }

    private static func peak(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        var peak: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            var channelPeak: Float = 0
            vDSP_maxmgv(data[channel], 1, &channelPeak, vDSP_Length(buffer.frameLength))
            peak = max(peak, channelPeak)
        }
        return peak
    }

    private static func copy(_ buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
        guard let output = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength),
              let src = buffer.floatChannelData, let dst = output.floatChannelData else { return buffer }
        var gain = gain
        for channel in 0..<Int(buffer.format.channelCount) {
            vDSP_vsmul(src[channel], 1, &gain, dst[channel], 1, vDSP_Length(buffer.frameLength))
        }
        output.frameLength = buffer.frameLength
        return output
    }
}
