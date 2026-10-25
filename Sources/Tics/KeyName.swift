//· KeyName ·
// Cómo se llama una tecla en los ajustes del teclado. Las que escriben, con lo que escriben en la
// distribución de teclado del Mac (así sale la Ñ de un teclado español); las demás, con los
// símbolos de los menús de macOS.

import Carbon.HIToolbox

enum KeyName {
    /// Un atajo, con los símbolos de sus modificadoras delante, como en los menús: ⌘A
    static func of(_ chord: KeyChord) -> String {
        chord.modifiers.symbols + of(chord.keyCode)
    }

    static func of(_ keyCode: UInt16) -> String {
        if let symbol = symbols[keyCode] { return symbol }
        if let (symbol, isLeft) = sided[keyCode] {
            return isLeft ? String(localized: "\(symbol) de la izquierda") : String(localized: "\(symbol) de la derecha")
        }
        if keyCode == KeyGroup.spaceKey { return String(localized: "Espacio") }
        if let key = keypad[keyCode] { return String(localized: "\(key) del teclado numérico") }
        let number = Int(keyCode)
        return typed(keyCode) ?? String(localized: "Tecla \(number)")
    }

    private static let symbols: [UInt16: String] = [
        0x24: "↩", 0x30: "⇥", 0x33: "⌫", 0x35: "⎋", 0x75: "⌦", 0x4C: "⌤", 0x39: "⇪", 0x3F: "fn",
        0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑", 0x73: "↖", 0x77: "↘", 0x74: "⇞", 0x79: "⇟",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6", 0x62: "F7",
        0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12", 0x69: "F13", 0x6B: "F14",
        0x71: "F15", 0x6A: "F16", 0x40: "F17", 0x4F: "F18", 0x50: "F19", 0x5A: "F20",
    ]

    /// Las modificadoras, que hay a los dos lados y cada una tiene su código
    private static let sided: [UInt16: (symbol: String, isLeft: Bool)] = [
        0x37: ("⌘", true), 0x36: ("⌘", false), 0x38: ("⇧", true), 0x3C: ("⇧", false),
        0x3A: ("⌥", true), 0x3D: ("⌥", false), 0x3B: ("⌃", true), 0x3E: ("⌃", false),
    ]

    /// Escriben lo mismo que las de la fila de números o de signos: se dice de dónde son
    private static let keypad: [UInt16: String] = [
        0x52: "0", 0x53: "1", 0x54: "2", 0x55: "3", 0x56: "4", 0x57: "5", 0x58: "6", 0x59: "7",
        0x5B: "8", 0x5C: "9", 0x41: ".", 0x43: "*", 0x45: "+", 0x4B: "/", 0x4E: "-", 0x51: "=",
        0x47: "⌧",
    ]

    /// Lo que escribe la tecla sola en la distribución de teclado actual, en mayúscula
    private static func typed(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let layout = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layout.withUnsafeBytes { bytes in
            UCKeyTranslate(
                bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress, keyCode,
                UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text.uppercased()
    }
}
