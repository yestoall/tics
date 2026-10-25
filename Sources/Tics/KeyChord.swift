//· KeyChord ·
// Una tecla, sola o con modificadoras: lo que cambia una tecla cambiada. Solo cuentan Cmd,
// Opción, Control y Mayúsculas; Bloq Mayús, Fn y el teclado numérico, que macOS también marca en
// las flags, no. Una modificadora sola es una tecla, aunque haya otra pulsada.

import CoreGraphics

/// Las modificadoras de un atajo, con los bits de las flags de CGEvent
struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt64

    static let control = KeyModifiers(rawValue: CGEventFlags.maskControl.rawValue)
    static let option = KeyModifiers(rawValue: CGEventFlags.maskAlternate.rawValue)
    static let shift = KeyModifiers(rawValue: CGEventFlags.maskShift.rawValue)
    static let command = KeyModifiers(rawValue: CGEventFlags.maskCommand.rawValue)

    /// En el orden de los menús de macOS: ⌃⌥⇧⌘
    static let ordered: [(KeyModifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
    static let all = KeyModifiers(ordered.map(\.0))

    /// Las que cuentan de unas flags crudas
    init(flags: UInt64) {
        rawValue = flags & Self.all.rawValue
    }

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    var symbols: String {
        Self.ordered.filter { contains($0.0) }.map(\.1).joined()
    }
}

struct KeyChord: Hashable, Sendable {
    /// kVK_*
    let keyCode: UInt16
    let modifiers: KeyModifiers

    /// Manda «pulsar» al encenderse y «soltar» al apagarse
    static let capsLock: UInt16 = 0x39
    /// Las modificadoras y Bloq Mayús: suenan solas, no forman atajos. Las cuatro, a los dos lados
    /// (Mayúsculas, Control, Opción y Cmd), Fn y Bloq Mayús
    static let modifierKeys: Set<UInt16> = [0x38, 0x3C, 0x3B, 0x3E, 0x3A, 0x3D, 0x37, 0x36, 0x3F, capsLock]

    /// Desde las flags crudas del evento
    init(keyCode: UInt16, flags: UInt64 = 0) {
        self.keyCode = keyCode
        modifiers = Self.modifierKeys.contains(keyCode) ? [] : KeyModifiers(flags: flags)
    }

    init(_ keyCode: UInt16) {
        self.init(keyCode: keyCode)
    }

    var isShortcut: Bool { !modifiers.isEmpty }

    /// La tecla sola
    var plain: KeyChord { KeyChord(keyCode) }
}

extension KeyChord: Codable {
    private enum CodingKeys: String, CodingKey {
        case keyCode, modifiers
    }

    /// Lo guardado antes de los atajos es solo el código de la tecla
    init(from decoder: any Decoder) throws {
        if let keyCode = try? decoder.singleValueContainer().decode(UInt16.self) {
            self.init(keyCode)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modifiers = try container.decodeIfPresent(KeyModifiers.self, forKey: .modifiers) ?? []
        self.init(keyCode: try container.decode(UInt16.self, forKey: .keyCode), flags: modifiers.rawValue)
    }

    /// Una tecla sola, como antes de los atajos: así la sigue leyendo una versión anterior
    func encode(to encoder: any Encoder) throws {
        guard isShortcut else {
            var container = encoder.singleValueContainer()
            try container.encode(keyCode)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers, forKey: .modifiers)
    }
}
