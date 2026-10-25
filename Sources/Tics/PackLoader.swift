//· PackLoader ·
// Lee un pack de disco y lo deja troceado: uno o varios fragmentos de audio por tecla,
// ya en el formato del motor. Todo el trabajo se hace al cargar, para que al teclear
// solo haya que reproducir.

import AVFoundation

/// Los fragmentos listos para sonar
struct LoadedPack {
    var down: [UInt16: [AVAudioPCMBuffer]] = [:]
    var up: [UInt16: [AVAudioPCMBuffer]] = [:]
    var fallbackDown: [AVAudioPCMBuffer] = []
    var fallbackUp: [AVAudioPCMBuffer] = []

    /// Lo que puede sonar en una tecla: lo suyo o, si no tiene, el sonido de reserva
    func sounds(for keyCode: UInt16, isDown: Bool) -> [AVAudioPCMBuffer] {
        isDown ? down[keyCode] ?? fallbackDown : up[keyCode] ?? fallbackUp
    }
}

enum PackLoaderError: Error {
    case unreadableAudio(String)
}

struct PackLoader {
    let format: AVAudioFormat

    /// Milisegundos de fundido al principio y al final de cada fragmento, para que no chasquee al cortar
    private static let fadeMs = 3.0

    func load(_ pack: SoundPack) throws -> LoadedPack {
        switch pack.source {
        case .synthetic:
            return KeySynth.pack(format: format)
        case let .folder(folder):
            let config = try SoundPackConfig.read(from: folder)
            switch config.keyDefineType {
            case .single: return try loadSingle(config, folder: folder)
            case .multi: return loadMulti(config, folder: folder)
            }
        }
    }

    //- single -

    /// Estos packs no traen sonido de soltar: la primera mitad de cada sonido suena al pulsar y la segunda al soltar
    private func loadSingle(_ config: SoundPackConfig, folder: URL) throws -> LoadedPack {
        let sprite = try readAudio(folder.appendingPathComponent(config.sound))
        var result = LoadedPack()
        for (key, define) in config.defines {
            guard case let .segment(start, duration) = define,
                  let code = Int(key), let macCode = KeyCodes.uiohookToMac[code] else { continue }
            let half = duration / 2
            if let down = slice(sprite, startMs: start, durationMs: half) { result.down[macCode] = [down] }
            if let up = slice(sprite, startMs: start + half, durationMs: half) { result.up[macCode] = [up] }
        }
        result.fallbackDown = result.down[KeyCodes.fallbackKey] ?? []
        result.fallbackUp = result.up[KeyCodes.fallbackKey] ?? []
        return result
    }

    //- multi -

    private func loadMulti(_ config: SoundPackConfig, folder: URL) -> LoadedPack {
        // Varias teclas comparten archivo: cada uno se lee una sola vez
        var cache: [String: AVAudioPCMBuffer] = [:]
        func buffers(for pattern: String) -> [AVAudioPCMBuffer] {
            expandVariants(pattern).compactMap { name in
                if let cached = cache[name] { return cached }
                guard let buffer = try? readAudio(folder.appendingPathComponent(name)) else { return nil }
                Self.fade(buffer)
                cache[name] = buffer
                return buffer
            }
        }

        var result = LoadedPack()
        result.fallbackDown = buffers(for: config.sound)
        if let soundup = config.soundup { result.fallbackUp = buffers(for: soundup) }
        for (key, define) in config.defines {
            guard case let .file(name) = define else { continue }
            let isUp = key.hasSuffix("-up")
            guard let code = Int(isUp ? String(key.dropLast(3)) : key),
                  let macCode = KeyCodes.uiohookToMac[code] else { continue }
            let list = buffers(for: name)
            guard !list.isEmpty else { continue }
            if isUp { result.up[macCode] = list } else { result.down[macCode] = list }
        }
        return result
    }

    /// «GENERIC_R{0-4}.mp3» → GENERIC_R0.mp3 … GENERIC_R4.mp3
    private func expandVariants(_ pattern: String) -> [String] {
        guard let open = pattern.firstIndex(of: "{"),
              let close = pattern.firstIndex(of: "}"), open < close else { return [pattern] }
        let bounds = pattern[pattern.index(after: open)..<close].split(separator: "-").compactMap { Int($0) }
        guard bounds.count == 2, bounds[0] <= bounds[1] else { return [pattern] }
        return (bounds[0]...bounds[1]).map { pattern.replacingCharacters(in: open...close, with: String($0)) }
    }

    //- Audio -

    /// Lee un archivo (ogg, mp3, wav…) y lo pasa al formato del motor: 44,1 kHz, estéreo, float
    private func readAudio(_ url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        guard let source = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)
        ) else { throw PackLoaderError.unreadableAudio(url.lastPathComponent) }
        try file.read(into: source)

        var buffer = source
        if buffer.format.sampleRate != format.sampleRate {
            buffer = try resample(buffer)
        }
        if buffer.format.channelCount == 1 {
            buffer = try monoToStereo(buffer)
        }
        guard buffer.format == format else { throw PackLoaderError.unreadableAudio(url.lastPathComponent) }
        return buffer
    }

    /// Cambia la frecuencia de muestreo y deja los canales como estaban
    private func resample(_ source: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let target = AVAudioFormat(
            standardFormatWithSampleRate: format.sampleRate, channels: source.format.channelCount
        ) else { throw PackLoaderError.unreadableAudio("formato no soportado") }
        return try Self.convert(source, to: target)
    }

    /// La grabación más deprisa (`pitch` > 1: más aguda y más corta) o más despacio, en su mismo
    /// formato: se toma como grabada a otra frecuencia y se vuelve a la suya
    static func pitched(_ buffer: AVAudioPCMBuffer, by pitch: Double) throws -> AVAudioPCMBuffer {
        let channels = buffer.format.channelCount
        guard let relabeled = AVAudioFormat(
            standardFormatWithSampleRate: buffer.format.sampleRate * pitch, channels: channels
        ), let source = AVAudioPCMBuffer(pcmFormat: relabeled, frameCapacity: buffer.frameLength),
              let src = buffer.floatChannelData, let dst = source.floatChannelData else {
            throw PackLoaderError.unreadableAudio("formato no soportado")
        }
        for channel in 0..<Int(channels) {
            dst[channel].update(from: src[channel], count: Int(buffer.frameLength))
        }
        source.frameLength = buffer.frameLength
        let output = try convert(source, to: buffer.format)
        fade(output)
        return output
    }

    private static func convert(_ source: AVAudioPCMBuffer, to target: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: source.format, to: target) else {
            throw PackLoaderError.unreadableAudio("formato no soportado")
        }
        let ratio = target.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(Double(source.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            throw PackLoaderError.unreadableAudio("sin memoria")
        }
        let input = OneShotInput(source)
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if let buffer = input.take() {
                status.pointee = .haveData
                return buffer
            }
            status.pointee = .endOfStream
            return nil
        }
        if let error { throw error }
        return output
    }

    /// Copia el único canal en los dos
    private func monoToStereo(_ source: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: source.frameLength),
              let src = source.floatChannelData, let dst = output.floatChannelData else {
            throw PackLoaderError.unreadableAudio("sin memoria")
        }
        let frames = Int(source.frameLength)
        dst[0].update(from: src[0], count: frames)
        dst[1].update(from: src[0], count: frames)
        output.frameLength = source.frameLength
        return output
    }

    /// Recorta un tramo del audio grande en un fragmento nuevo
    private func slice(_ buffer: AVAudioPCMBuffer, startMs: Double, durationMs: Double) -> AVAudioPCMBuffer? {
        let rate = buffer.format.sampleRate
        let total = Int(buffer.frameLength)
        let start = Int(startMs * rate / 1000)
        let count = min(Int(durationMs * rate / 1000), total - start)
        guard start >= 0, count > 0,
              let output = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: AVAudioFrameCount(count)),
              let src = buffer.floatChannelData, let dst = output.floatChannelData else { return nil }
        for channel in 0..<Int(buffer.format.channelCount) {
            dst[channel].update(from: src[channel] + start, count: count)
        }
        output.frameLength = AVAudioFrameCount(count)
        Self.fade(output)
        return output
    }

    /// Fundido corto de entrada y de salida
    private static func fade(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let length = min(Int(Self.fadeMs * buffer.format.sampleRate / 1000), frames / 2)
        guard length > 0 else { return }
        for channel in 0..<Int(buffer.format.channelCount) {
            for i in 0..<length {
                let gain = Float(i) / Float(length)
                data[channel][i] *= gain
                data[channel][frames - 1 - i] *= gain
            }
        }
    }
}

/// Entrega el audio de origen al convertidor una sola vez. El convertidor lo pide desde
/// un closure @Sendable; esta caja es la forma de pasárselo sin que Swift 6 proteste
private final class OneShotInput: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}
