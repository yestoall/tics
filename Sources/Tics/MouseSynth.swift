//· MouseSynth ·
// Los clics del ratón no vienen de ningún fichero: los calcula Synth al arrancar. Se hacen
// varias variantes de cada uno para que dos clics seguidos no suenen idénticos, y se rehacen
// con cada pack, a su altura, y con cada cambio de los ajustes del ratón. Al arrastrar suenan
// clics más suaves, seguidos, como un trinquete; la rueda, los mismos, algo más flojos.

import AVFoundation

/// Los clics listos para sonar, por botón, y los del arrastre
struct MouseClicks {
    var down: [MouseButton: [AVAudioPCMBuffer]] = [:]
    var up: [MouseButton: [AVAudioPCMBuffer]] = [:]
    var drag: [AVAudioPCMBuffer] = []
    var scroll: [AVAudioPCMBuffer] = []
}

enum MouseSynth {
    /// Cada clic elige una de estas variantes al azar
    static let variantCount = 5
    /// Lo fuerte que suena un clic al lado de una tecla del pack (1 = igual)
    static let loudness: Float = 0.8
    /// Lo mismo para los clics del arrastre: más flojos, porque suenan muchos seguidos
    static let dragLoudness: Float = 0.35
    /// Y para la rueda: los del arrastre, algo más flojos, porque van aún más seguidos
    static let scrollLoudness: Float = dragLoudness * 0.7

    /// Al pulsar: seco y con cuerpo
    static let press = Synth.Hit(
        noiseMs: 0.4, noiseLevel: 0.9,
        pingHz: 3800, pingMs: 2.5, pingLevel: 0.35,
        bodyHz: 260, bodyMs: 6, bodyLevel: 0.25
    )

    /// Al soltar: más flojo y más agudo
    static let release = Synth.Hit(
        noiseMs: 0.3, noiseLevel: 0.55,
        pingHz: 5200, pingMs: 1.8, pingLevel: 0.25,
        bodyHz: 320, bodyMs: 4, bodyLevel: 0.12
    )

    /// Al arrastrar: blando y corto, sin apenas chasquido
    static let dragTick = Synth.Hit(
        noiseMs: 0.2, noiseLevel: 0.2,
        pingHz: 3200, pingMs: 1.6, pingLevel: 0.3,
        bodyHz: 420, bodyMs: 2.5, bodyLevel: 0.1
    )

    /// El botón derecho suena un poco más grave y el central un poco más agudo. Los desviados,
    /// más grave aún que el derecho: así se distinguen de los que llegan a macOS
    static let pitch: [MouseButton: Double] = [.left: 1, .right: 0.9, .other: 1.12, .diverted: 0.75]

    /// `keyLoudness`: lo que suena una tecla típica del pack (`Loudness.typical`)
    static func clicks(format: AVAudioFormat, keyLoudness: Float, settings: MouseSettings = MouseSettings()) -> MouseClicks {
        var rng = SystemRandomNumberGenerator()
        var result = MouseClicks()
        for sound in MouseSound.allCases {
            let tuning = settings[sound]
            func render(_ hit: Synth.Hit, pitch: Double, loudness: Float) -> [AVAudioPCMBuffer] {
                (0..<variantCount).compactMap { _ in
                    Synth.render(
                        hit.withTimbre(tuning.timbre), pitch: pitch * tuning.pitch,
                        loudness: keyLoudness * loudness * Float(tuning.volume), format: format, using: &rng
                    )
                }
            }
            switch sound.button {
            case let button?:
                let pitch = Self.pitch[button] ?? 1
                result.down[button] = render(press, pitch: pitch, loudness: loudness)
                result.up[button] = render(release, pitch: pitch, loudness: loudness)
            case nil where sound == .drag:
                result.drag = render(dragTick, pitch: 1, loudness: dragLoudness)
            case nil:
                result.scroll = render(dragTick, pitch: 1, loudness: scrollLoudness)
            }
        }
        return result
    }
}

extension Synth.Hit {
    /// El timbre: seco (negativo) sube el chasquido y el pitido y quita cuerpo; hueco (positivo),
    /// al revés, y alarga el cuerpo. Cada punto dobla o parte por dos. La sonoridad se iguala
    /// después, así que el timbre no cambia lo fuerte que suena
    func withTimbre(_ timbre: Double) -> Synth.Hit {
        guard timbre != 0 else { return self }
        var hit = self
        hit.noiseLevel *= pow(2, -timbre)
        hit.pingLevel *= pow(2, -timbre)
        hit.bodyLevel *= pow(2, 1.5 * timbre)
        hit.bodyMs *= pow(2, timbre)
        // Que quepa la cola del cuerpo: a las cinco veces su caída ya no se oye
        hit.durationMs = max(hit.durationMs, hit.bodyMs * 5)
        return hit
    }
}
