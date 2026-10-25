//· MouseSettings ·
// Los ajustes del ratón: el tono, el volumen y el timbre de cada sonido del ratón, y la vibración
// de los botones en un ratón Logitech que vibre. Solo hay un
// juego, que se guarda en las preferencias cada vez que se mueve un ajuste. De serie, todo suena
// como lo calcula MouseSynth. Pulsar y soltar van juntos: el soltar sigue siendo más flojo y más
// agudo que el pulsar, en la misma proporción.

import SwiftUI

/// Los seis sonidos del ratón que se ajustan por separado
enum MouseSound: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case left, right, extra, diverted, drag, scroll

    /// El botón que lo hace sonar; el arrastre y la rueda no son un botón
    var button: MouseButton? {
        switch self {
        case .left: .left
        case .right: .right
        case .extra: .other
        case .diverted: .diverted
        case .drag, .scroll: nil
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .left: "Clic izquierdo"
        case .right: "Clic derecho"
        case .extra: "Botones extra"
        case .diverted: "Botones de Options+"
        case .drag: "Arrastre"
        case .scroll: "Scroll"
        }
    }
}

/// El efecto con que vibra el ratón al pulsar un botón: cinco de los dieciséis que trae el
/// MX Master 4, los que mejor se notan. `effect` es su id en el ratón (HAPTIC, 0x19B0)
enum Vibration: String, CaseIterable, Codable, Sendable {
    case none, tap, knock, alert, wave, shake

    var effect: UInt8? {
        switch self {
        case .none: nil
        case .tap: 0x00 // sharp_state_change
        case .knock: 0x02 // sharp_collision
        case .alert: 0x06 // angry_alert
        case .wave: 0x09 // wave
        case .shake: 0x0B // mad
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .none: "Ninguna"
        case .tap: "Toque"
        case .knock: "Golpe"
        case .alert: "Alerta"
        case .wave: "Ola"
        case .shake: "Sacudida"
        }
    }
}

/// Lo que se ajusta de un sonido. Tono y volumen multiplican lo de serie; el timbre va de seco
/// (negativo: más chasquido) a hueco (positivo: más cuerpo, y más largo). La vibración solo la usan
/// los botones, al pulsar
struct SoundSettings: Codable, Equatable, Sendable {
    static let pitchRange = 0.25...4.0
    static let volumeRange = 0.0...3.0
    static let timbreRange = -2.0...2.0

    /// Los mismos topes valen para el teclado
    static func clampedPitch(_ pitch: Double) -> Double {
        min(max(pitch, pitchRange.lowerBound), pitchRange.upperBound)
    }

    static func clampedVolume(_ volume: Double) -> Double {
        min(max(volume, volumeRange.lowerBound), volumeRange.upperBound)
    }

    var pitch = 1.0
    var volume = 1.0
    var timbre = 0.0
    var vibration = Vibration.none

    /// Dentro de sus rangos: lo guardado en otra versión puede venir de fuera
    var clamped: SoundSettings {
        SoundSettings(
            pitch: Self.clampedPitch(pitch),
            volume: Self.clampedVolume(volume),
            timbre: min(max(timbre, Self.timbreRange.lowerBound), Self.timbreRange.upperBound),
            vibration: vibration
        )
    }
}

extension SoundSettings {
    /// Lo guardado antes de la vibración no la trae: se lee sin ella. En una extensión, para no
    /// perder el init de todos los campos
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pitch = try container.decode(Double.self, forKey: .pitch)
        volume = try container.decode(Double.self, forKey: .volume)
        timbre = try container.decode(Double.self, forKey: .timbre)
        vibration = try container.decodeIfPresent(Vibration.self, forKey: .vibration) ?? .none
    }
}

struct MouseSettings: Codable, Equatable, Sendable {
    private var sounds: [MouseSound: SoundSettings] = [:]

    subscript(sound: MouseSound) -> SoundSettings {
        get { (sounds[sound] ?? SoundSettings()).clamped }
        set { sounds[sound] = newValue.clamped }
    }
}
