//· PitchVariants ·
// Cada pulsación, un poco distinta: de cada sonido del teclado, una copia algo más grave o algo más
// aguda, una y otra a turnos. Al pulsar se elige entre el sonido y su copia al azar, como entre las
// grabaciones de un pack multi, y la misma tecla deja de sonar idéntica, que es lo que delata una
// grabación. Las copias se calculan al cargar el pack o cambiar los ajustes; al teclear solo se elige.
// Una copia y no dos: en los packs single, con 200 sonidos, dos sumaban 9–14 MB (2026-10-27).

import AVFoundation

struct PitchVariants {
    /// Lo que se aleja el tono de las copias: un 3 %, medio semitono. Con menos no se nota; con más,
    /// empiezan a sonar como teclas distintas
    static let pitches: [Double] = [0.97, 1.03]

    /// La copia de cada sonido. Guarda también el sonido, para no confundirlo con otro que acabe en
    /// la misma dirección de memoria
    private var copies: [ObjectIdentifier: (original: AVAudioPCMBuffer, copy: AVAudioPCMBuffer?)] = [:]

    /// Las de estos sonidos y solo de estos: las que ya tenía no se vuelven a calcular
    func updated(for buffers: [AVAudioPCMBuffer]) -> PitchVariants {
        var result = PitchVariants()
        for buffer in buffers {
            let id = ObjectIdentifier(buffer)
            guard result.copies[id] == nil else { continue }
            if let known = copies[id], known.original === buffer {
                result.copies[id] = known
            } else {
                let pitch = Self.pitches[result.copies.count % Self.pitches.count]
                result.copies[id] = (buffer, try? PackLoader.pitched(buffer, by: pitch))
            }
        }
        return result
    }

    /// Cada sonido con su copia detrás
    func expanded(_ buffers: [AVAudioPCMBuffer]) -> [AVAudioPCMBuffer] {
        buffers.flatMap { buffer in
            [buffer] + [copies[ObjectIdentifier(buffer)]?.copy].compactMap { $0 }
        }
    }
}
