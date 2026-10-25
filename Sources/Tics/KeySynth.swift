//· KeySynth ·
// El pack sintético: teclas que no vienen de ningún fichero, calculadas al cargar el pack.
// Un primer intento con tonos puros (como los clics del ratón) sonaba a sintetizador: una tecla
// de verdad es plástico que vibra a la vez en muchas frecuencias juntas, casi todas entre 1 y
// 4 kHz. Así que aquí un golpe de ruido excita una docena de resonancias repartidas en esa zona,
// las agudas se apagan antes que las graves, y debajo queda un golpe grave y una cola de ruido.
// Los números salen de analizar teclas reales de los packs (Holy Panda, Cream, Turquoise).

import AVFoundation

enum KeySynth {
    static let packID = "synth"
    /// Variantes de las teclas normales: cada pulsación elige una al azar
    static let variantCount = 8
    /// Variantes de cada tecla ancha
    static let wideVariantCount = 3
    /// Lo que suena una tecla al pulsar, en la escala de `Loudness`: como un pack de los de en medio
    static let loudness: Float = 0.03
    /// Al soltar, a esta parte de lo que suena al pulsar
    static let releaseLoudness: Float = 0.6

    /// Una tecla: dónde resuena, cuánto le dura y cómo se la golpea
    struct Voice {
        /// Resonancias del plástico: cuántas y entre qué frecuencias, al azar en cada variante
        var modeCount = 12
        var lowHz: Double
        var highHz: Double
        /// Lo que dura cada resonancia (ms hasta caer a un 37 %): la más grave, la más aguda
        var lowModeMs: Double
        var highModeMs: Double
        /// El golpe grave de la carcasa
        var thumpHz: Double
        var thumpMs: Double
        var thumpLevel: Double
        /// Cada golpe que recibe la tecla: cuándo (ms) y cómo de fuerte. Al pulsar, uno flojo al
        /// pasar el punto táctil y el fuerte al tocar fondo
        var strikes: [(ms: Double, level: Double)]
        /// Lo que dura el chasquido de cada golpe
        var burstMs = 0.8
        /// Ruido que sigue moviendo las resonancias después del golpe: la cola irregular
        var tailMs: Double
        var tailLevel: Double
        var durationMs: Double
    }

    static let press = Voice(
        lowHz: 1200, highHz: 3400, lowModeMs: 8, highModeMs: 3,
        thumpHz: 220, thumpMs: 12, thumpLevel: 0.8,
        strikes: [(0, 0.06), (7, 1)],
        tailMs: 20, tailLevel: 0.05, durationMs: 90
    )

    static let release = Voice(
        modeCount: 8, lowHz: 600, highHz: 1900, lowModeMs: 7, highModeMs: 3,
        thumpHz: 110, thumpMs: 12, thumpLevel: 1.2,
        strikes: [(0, 1)],
        tailMs: 12, tailLevel: 0.06, durationMs: 60
    )

    /// Las anchas (Return, borrar, Tab, Mayúsculas, Bloq Mayús…): más graves y con más golpe
    static let widePress = Voice(
        lowHz: 1000, highHz: 2600, lowModeMs: 10, highModeMs: 4,
        thumpHz: 130, thumpMs: 18, thumpLevel: 1.5,
        strikes: [(0, 0.06), (6, 1)],
        tailMs: 25, tailLevel: 0.05, durationMs: 100
    )

    static let wideRelease = Voice(
        modeCount: 8, lowHz: 500, highHz: 1600, lowModeMs: 8, highModeMs: 3,
        thumpHz: 100, thumpMs: 14, thumpLevel: 1.3,
        strikes: [(0, 1)],
        tailMs: 14, tailLevel: 0.06, durationMs: 70
    )

    /// El espacio: largo, con resonancias que duran más y el traqueteo del estabilizador
    static let spacePress = Voice(
        modeCount: 14, lowHz: 1200, highHz: 2600, lowModeMs: 30, highModeMs: 10,
        thumpHz: 130, thumpMs: 25, thumpLevel: 1,
        strikes: [(0, 0.1), (12, 1), (24, 0.25)],
        tailMs: 50, tailLevel: 0.1, durationMs: 220
    )

    static let spaceRelease = Voice(
        modeCount: 10, lowHz: 900, highHz: 2200, lowModeMs: 20, highModeMs: 6,
        thumpHz: 110, thumpMs: 16, thumpLevel: 1.2,
        strikes: [(0, 1), (14, 0.2)],
        tailMs: 30, tailLevel: 0.07, durationMs: 140
    )

    static let wideKeys = Array(KeyGroup.wideKeys)
    static let space = KeyGroup.spaceKey

    static func pack(format: AVAudioFormat) -> LoadedPack {
        var rng = SystemRandomNumberGenerator()
        func variants(_ voice: Voice, count: Int, loudness: Float) -> [AVAudioPCMBuffer] {
            (0..<count).compactMap { _ in render(voice, loudness: loudness, format: format, using: &rng) }
        }
        let releaseTarget = loudness * releaseLoudness

        var result = LoadedPack()
        result.fallbackDown = variants(press, count: variantCount, loudness: loudness)
        result.fallbackUp = variants(release, count: variantCount, loudness: releaseTarget)
        // Todas las anchas comparten sonido: suenan igual en un teclado de verdad
        let wideDown = variants(widePress, count: wideVariantCount, loudness: loudness)
        let wideUp = variants(wideRelease, count: wideVariantCount, loudness: releaseTarget)
        for key in wideKeys {
            result.down[key] = wideDown
            result.up[key] = wideUp
        }
        result.down[space] = variants(spacePress, count: wideVariantCount, loudness: loudness)
        result.up[space] = variants(spaceRelease, count: wideVariantCount, loudness: releaseTarget)
        return result
    }

    //- Cálculo -

    /// Una resonancia: un filtro de dos polos que, golpeado, vibra a su frecuencia y se apaga
    private struct Resonator {
        let b0: Double, a1: Double, a2: Double
        var y1 = 0.0, y2 = 0.0

        init(hz: Double, ms: Double, rate: Double) {
            let r = exp(-1 / (ms * rate / 1000))
            let w = 2 * Double.pi * hz / rate
            a1 = 2 * r * cos(w)
            a2 = -r * r
            // Con esta ganancia de entrada, la resonancia deja pasar su frecuencia a nivel 1
            b0 = (1 - r) * 2 * sin(w)
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + a1 * y1 + a2 * y2
            y2 = y1
            y1 = y
            return y
        }
    }

    static func render(
        _ voice: Voice, loudness: Float, format: AVAudioFormat, using rng: inout some RandomNumberGenerator
    ) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let frames = Int(voice.durationMs * rate / 1000)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let data = buffer.floatChannelData else { return nil }

        // Cada variante, sus propias resonancias: repartidas al azar en la zona, con más o menos nivel
        var modes: [(resonator: Resonator, level: Double)] = (0..<voice.modeCount).map { _ in
            let position = Double.random(in: 0...1, using: &rng)
            let hz = voice.lowHz * pow(voice.highHz / voice.lowHz, position)
            let ms = voice.lowModeMs * pow(voice.highModeMs / voice.lowModeMs, position)
            return (Resonator(hz: hz, ms: ms, rate: rate), Double.random(in: 0.3...1, using: &rng))
        }
        var thump = Resonator(hz: voice.thumpHz * Double.random(in: 0.94...1.06, using: &rng), ms: voice.thumpMs, rate: rate)
        let strikes = voice.strikes.map { (start: $0.ms * Double.random(in: 0.85...1.15, using: &rng), level: $0.level) }
        let mainStrike = strikes.max { $0.level < $1.level }?.start ?? 0

        let fade = Int(3 * rate / 1000)
        var peak: Float = 0
        for i in 0..<frames {
            let ms = Double(i) / rate * 1000
            // Lo que empuja a las resonancias: el chasquido de cada golpe y la cola de ruido
            var push = 0.0
            for strike in strikes where ms >= strike.start {
                push += strike.level * exp(-(ms - strike.start) / voice.burstMs)
            }
            if ms >= mainStrike { push += voice.tailLevel * exp(-(ms - mainStrike) / voice.tailMs) }
            let x = Double.random(in: -1...1, using: &rng) * push

            var value = thump.process(x) * voice.thumpLevel
            for m in modes.indices { value += modes[m].resonator.process(x) * modes[m].level }

            var sample = Float(value)
            if i >= frames - fade { sample *= Float(frames - 1 - i) / Float(fade) }
            peak = max(peak, abs(sample))
            for channel in 0..<Int(format.channelCount) { data[channel][i] = sample }
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        Synth.normalize(buffer, loudness: loudness, peak: peak)
        return buffer
    }
}
