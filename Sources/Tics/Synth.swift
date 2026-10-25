//· Synth ·
// Calcula golpes cortos muestra a muestra, sin ficheros: los clics del ratón (MouseSynth). Un
// golpe es un chasquido de ruido muy corto, un pitido que se apaga enseguida y un golpe grave.
// También pone a la altura pedida lo que calcula KeySynth.

import AVFoundation

enum Synth {
    /// Cuánto se aparta cada variante del golpe de referencia (±)
    static let jitter = 0.06
    /// Tope del pico, para que nada sature aunque se pida muy fuerte
    static let maxPeak: Float = 0.95

    /// Los parámetros de un golpe. Los tiempos son lo que tarda cada parte en caer a un 37 %
    struct Hit {
        var noiseMs: Double
        var noiseLevel: Double
        var pingHz: Double
        var pingMs: Double
        var pingLevel: Double
        var bodyHz: Double
        var bodyMs: Double
        var bodyLevel: Double
        var durationMs = 45.0
    }

    /// Calcula un golpe con un poco de azar en el tono y en el nivel de cada parte, a la
    /// sonoridad pedida (`Loudness`) y sin pasar de `maxPeak`
    static func render(
        _ hit: Hit, pitch: Double, loudness: Float, format: AVAudioFormat,
        using rng: inout some RandomNumberGenerator
    ) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let frames = Int(hit.durationMs * rate / 1000)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let data = buffer.floatChannelData else { return nil }

        func vary(_ value: Double) -> Double { value * Double.random(in: (1 - jitter)...(1 + jitter), using: &rng) }
        let pingHz = vary(hit.pingHz * pitch)
        let bodyHz = vary(hit.bodyHz * pitch)
        let noiseLevel = vary(hit.noiseLevel)
        let pingLevel = vary(hit.pingLevel)
        let bodyLevel = vary(hit.bodyLevel)

        let fade = Int(3 * rate / 1000)
        var peak: Float = 0
        for i in 0..<frames {
            let t = Double(i) / rate
            let ms = t * 1000
            let value = Double.random(in: -1...1, using: &rng) * noiseLevel * exp(-ms / hit.noiseMs)
                + sin(2 * .pi * pingHz * t) * pingLevel * exp(-ms / hit.pingMs)
                + sin(2 * .pi * bodyHz * t) * bodyLevel * exp(-ms / hit.bodyMs)
            // Un fundido final por si queda cola
            var sample = Float(value)
            if i >= frames - fade { sample *= Float(frames - 1 - i) / Float(fade) }
            peak = max(peak, abs(sample))
            for channel in 0..<Int(format.channelCount) { data[channel][i] = sample }
        }
        buffer.frameLength = AVAudioFrameCount(frames)
        normalize(buffer, loudness: loudness, peak: peak)
        return buffer
    }

    /// Pone un sonido a la sonoridad pedida (`Loudness`) sin que su pico pase de `maxPeak`
    static func normalize(_ buffer: AVAudioPCMBuffer, loudness: Float, peak: Float) {
        guard let data = buffer.floatChannelData else { return }
        let measured = Loudness.of(buffer)
        guard measured > 0, peak > 0 else { return }
        let gain = min(loudness / measured, maxPeak / peak)
        for channel in 0..<Int(buffer.format.channelCount) {
            for i in 0..<Int(buffer.frameLength) { data[channel][i] *= gain }
        }
    }
}
