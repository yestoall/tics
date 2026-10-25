//· Loudness ·
// Cuánto suena un fragmento, para poner el ratón a la altura del pack de teclado. El pico no
// sirve: un clic es casi todo golpe y, con el mismo pico que una tecla, suena mucho más fuerte.
// Lo que se mide es la energía en una ventana de 100 ms, que es lo que el oído suma en un
// sonido corto: un clic de 40 ms y una tecla de 100 ms con la misma energía suenan igual.

import AVFoundation

enum Loudness {
    static let windowMs = 100.0
    /// La raíz de la energía media de la ventana más fuerte, con los canales juntos
    static func of(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        let window = Int(windowMs * buffer.format.sampleRate / 1000)
        guard frames > 0, channels > 0, window > 0 else { return 0 }

        func energy(_ i: Int) -> Float {
            var sum: Float = 0
            for channel in 0..<channels { sum += data[channel][i] * data[channel][i] }
            return sum / Float(channels)
        }
        var sum: Float = 0
        var loudest: Float = 0
        for i in 0..<frames {
            sum += energy(i)
            if i >= window { sum -= energy(i - window) }
            loudest = max(loudest, sum)
        }
        // Siempre entre la ventana entera: un sonido más corto que ella cuenta como más flojo
        return (loudest / Float(window)).squareRoot()
    }

    /// Lo que suena una tecla típica del pack: la mediana, para que no manden las raras
    static func typical(of buffers: [AVAudioPCMBuffer]) -> Float {
        let values = buffers.map(of).sorted()
        return values.isEmpty ? 0 : values[values.count / 2]
    }
}
