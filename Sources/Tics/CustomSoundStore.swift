//· CustomSoundStore ·
// Los sonidos propios: ficheros de audio tuyos puestos en una tecla cambiada. TICS guarda una copia
// en su carpeta de Application Support, así que la tecla sigue sonando aunque muevas o borres el
// original. Al copiarlo le quita el silencio del principio, que se oiría como si la tecla sonara
// tarde, y se queda con los primeros 2 segundos, con un fundido al final.

import AVFoundation

/// Un sonido propio: su copia en la carpeta de TICS y el nombre del fichero del que salió
struct CustomSound: Codable, Hashable, Sendable {
    /// El nombre de la copia en la carpeta
    let file: String
    /// El del fichero original, para enseñarlo en la fila de la tecla
    let name: String
}

struct CustomSoundStore {
    /// Lo que se queda de un fichero, contando desde que empieza a sonar
    static let maxSeconds = 2.0
    /// Por debajo de esto, el principio cuenta como silencio (unos −40 dB)
    static let silenceLevel: Float = 0.01
    /// El fundido del final
    static let fadeMs = 20.0
    /// Hasta dónde se busca el principio del sonido
    static let maxLeadingSilence = 10.0

    let folder: URL
    let format: AVAudioFormat

    /// La de la app: Application Support, en una carpeta con su identificador, así TICS Dev tiene
    /// la suya
    static var appFolder: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.yestoall.tics")
            .appendingPathComponent("CustomSounds")
    }

    /// Copia un fichero a la carpeta, ya recortado. Si no se puede leer como audio, lanza un error
    /// y no copia nada
    func importSound(from url: URL) throws -> CustomSound {
        let audio = try PackLoader(format: format).toEngineFormat(try readStart(of: url), name: url.lastPathComponent)
        fadeOut(audio)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = "\(UUID().uuidString).caf"
        let copyURL = folder.appendingPathComponent(file)
        do {
            try AVAudioFile(forWriting: copyURL, settings: format.settings).write(from: audio)
        } catch {
            // Que no quede una copia a medias
            try? FileManager.default.removeItem(at: copyURL)
            throw error
        }
        return CustomSound(file: file, name: url.lastPathComponent)
    }

    /// La copia, lista para sonar. Nada si ya no está
    func load(_ sound: CustomSound) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: folder.appendingPathComponent(sound.file)),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil else { return nil }
        return try? PackLoader(format: format).toEngineFormat(buffer, name: sound.name)
    }

    /// Si sigue estando su copia
    func contains(_ sound: CustomSound) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(sound.file).path)
    }

    /// Borra las copias que no están en `used`: las de las teclas que se quitaron o cambiaron de sonido
    func removeAll(except used: Set<CustomSound>) {
        let keep = Set(used.map(\.file))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for file in files where !keep.contains(file) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
        }
    }

    /// Solo lo que se queda del fichero: desde que empieza a sonar, `maxSeconds`. Se lee a trozos de
    /// medio segundo, sin cargarlo entero: una canción de una hora ocuparía más de un giga. Si en
    /// `maxLeadingSilence` no ha sonado nada, se toma desde ahí
    private func readStart(of url: URL) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let source = file.processingFormat
        let chunk = AVAudioFrameCount(source.sampleRate / 2)
        let keep = AVAudioFrameCount(Self.maxSeconds * source.sampleRate)
        let scanLimit = AVAudioFramePosition(Self.maxLeadingSilence * source.sampleRate)
        guard let output = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: keep),
              let piece = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: chunk) else {
            throw PackLoaderError.unreadableAudio(url.lastPathComponent)
        }
        var started = false
        while output.frameLength < keep, file.framePosition < file.length {
            let position = file.framePosition
            try file.read(into: piece, frameCount: chunk)
            guard piece.frameLength > 0 else { break }
            var from = 0
            if !started {
                if let first = firstSound(in: piece) {
                    from = first
                } else if position + AVAudioFramePosition(piece.frameLength) < scanLimit {
                    continue
                }
                started = true
            }
            append(piece, from: from, to: output, upTo: keep)
        }
        // Todo silencio
        guard output.frameLength > 0 else { throw PackLoaderError.unreadableAudio(url.lastPathComponent) }
        return output
    }

    /// La primera muestra que pasa de `silenceLevel` en algún canal
    private func firstSound(in buffer: AVAudioPCMBuffer) -> Int? {
        guard let data = buffer.floatChannelData else { return nil }
        let channels = Int(buffer.format.channelCount)
        return (0..<Int(buffer.frameLength)).first { i in
            (0..<channels).contains { abs(data[$0][i]) > Self.silenceLevel }
        }
    }

    /// Añade a `output` lo de `piece` desde `from`, sin pasar de `limit` muestras
    private func append(_ piece: AVAudioPCMBuffer, from: Int, to output: AVAudioPCMBuffer, upTo limit: AVAudioFrameCount) {
        guard let src = piece.floatChannelData, let dst = output.floatChannelData else { return }
        let count = min(Int(piece.frameLength) - from, Int(limit - output.frameLength))
        guard count > 0 else { return }
        for channel in 0..<Int(piece.format.channelCount) {
            (dst[channel] + Int(output.frameLength)).update(from: src[channel] + from, count: count)
        }
        output.frameLength += AVAudioFrameCount(count)
    }

    /// Un fundido al final, para que no chasquee al cortarlo
    private func fadeOut(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let fade = min(Int(Self.fadeMs * buffer.format.sampleRate / 1000), frames)
        for channel in 0..<Int(buffer.format.channelCount) {
            for i in 0..<fade { data[channel][frames - 1 - i] *= Float(i) / Float(fade) }
        }
    }
}
