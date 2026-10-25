//· KeyGroup ·
// Las teclas que suenan igual dentro de un pack: las normales, el espacio y las anchas.

enum KeyGroup: String, CaseIterable, Codable, CodingKeyRepresentable, Sendable {
    case normal, space, wide

    static let spaceKey: UInt16 = 0x31
    /// Return, Intro, borrar, Supr, Tab, las dos Mayúsculas y Bloq Mayús
    static let wideKeys: Set<UInt16> = [0x24, 0x4C, 0x33, 0x75, 0x30, 0x38, 0x3C, 0x39]

    /// Una tecla para oír cómo suena el grupo: la A, el espacio y Return
    var sampleKey: UInt16 {
        switch self {
        case .normal: KeyCodes.fallbackKey
        case .space: Self.spaceKey
        case .wide: 0x24
        }
    }

    init(keyCode: UInt16) {
        if keyCode == Self.spaceKey {
            self = .space
        } else if Self.wideKeys.contains(keyCode) {
            self = .wide
        } else {
            self = .normal
        }
    }
}
