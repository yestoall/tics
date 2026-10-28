//· KeyGroup ·
// Las teclas que suenan igual dentro de un pack: las normales, el espacio, Return y las anchas.
// Return iba con las anchas hasta el 2026-10-28: ahora tiene su grupo, para cambiarla como el espacio.

enum KeyGroup: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case normal, space, enter, wide

    static let spaceKey: UInt16 = 0x31
    /// Return y el Intro del teclado numérico
    static let enterKeys: Set<UInt16> = [0x24, 0x4C]
    /// Las teclas anchas del teclado: Return, Intro, borrar, Supr, Tab, las dos Mayúsculas y Bloq
    /// Mayús. Return e Intro suenan con su propio grupo; esto lo usa el pack Sintético (KeySynth)
    static let wideKeys: Set<UInt16> = [0x24, 0x4C, 0x33, 0x75, 0x30, 0x38, 0x3C, 0x39]

    /// Las teclas del grupo de las que el pack puede traer sonido propio (no vale para las normales)
    var keys: Set<UInt16> {
        switch self {
        case .normal: []
        case .space: [Self.spaceKey]
        case .enter: Self.enterKeys
        case .wide: Self.wideKeys.subtracting(Self.enterKeys)
        }
    }

    /// Una tecla para oír cómo suena el grupo: la A, el espacio, Return y borrar
    var sampleKey: UInt16 {
        switch self {
        case .normal: KeyCodes.fallbackKey
        case .space: Self.spaceKey
        case .enter: 0x24
        case .wide: 0x33
        }
    }

    init(keyCode: UInt16) {
        if keyCode == Self.spaceKey {
            self = .space
        } else if Self.enterKeys.contains(keyCode) {
            self = .enter
        } else if Self.wideKeys.contains(keyCode) {
            self = .wide
        } else {
            self = .normal
        }
    }
}
