//· KeyCodes ·
// Los packs de Mechvibes numeran las teclas con los códigos de libuiohook (los del PC).
// Esta tabla los traduce a los códigos virtuales del Mac (kVK_* de Carbon/HIToolbox/Events.h).
// Fuente de los códigos de Mechvibes: src/libs/keycodes.js

enum KeyCodes {
    static let uiohookToMac: [Int: UInt16] = [
        // Escape y teclas de función
        1: 0x35,
        59: 0x7A, 60: 0x78, 61: 0x63, 62: 0x76, 63: 0x60, 64: 0x61, // F1–F6
        65: 0x62, 66: 0x64, 67: 0x65, 68: 0x6D, 87: 0x67, 88: 0x6F, // F7–F12
        91: 0x69, 92: 0x6B, 93: 0x71, // F13–F15

        // Fila de números
        41: 0x32, // `
        2: 0x12, 3: 0x13, 4: 0x14, 5: 0x15, 6: 0x17, // 1–5
        7: 0x16, 8: 0x1A, 9: 0x1C, 10: 0x19, 11: 0x1D, // 6–0
        12: 0x1B, 13: 0x18, 14: 0x33, // - = Borrar

        // Letras
        30: 0x00, 48: 0x0B, 46: 0x08, 32: 0x02, 18: 0x0E, 33: 0x03, 34: 0x05, // A B C D E F G
        35: 0x04, 23: 0x22, 36: 0x26, 37: 0x28, 38: 0x25, 50: 0x2E, 49: 0x2D, // H I J K L M N
        24: 0x1F, 25: 0x23, 16: 0x0C, 19: 0x0F, 31: 0x01, 20: 0x11, 22: 0x20, // O P Q R S T U
        47: 0x09, 17: 0x0D, 45: 0x07, 21: 0x10, 44: 0x06, // V W X Y Z

        // Puntuación, Tab, Bloq Mayús, Return y espacio
        15: 0x30, 58: 0x39,
        26: 0x21, 27: 0x1E, 43: 0x2A, // [ ] \
        39: 0x29, 40: 0x27, 28: 0x24, // ; ' Return
        51: 0x2B, 52: 0x2F, 53: 0x2C, // , . /
        57: 0x31,

        // Bloque de navegación. En Mac, Mechvibes usa el Insert del PC para Fn
        3666: 0x3F, 3667: 0x75, 3655: 0x73, 3663: 0x77, 3657: 0x74, 3665: 0x79, // Fn Supr Inicio Fin RePág AvPág
        57416: 0x7E, 57419: 0x7B, 57421: 0x7C, 57424: 0x7D, // ↑ ← → ↓

        // Modificadores
        42: 0x38, 54: 0x3C, // Shift
        29: 0x3B, 3613: 0x3E, // Control
        56: 0x3A, 3640: 0x3D, // Option
        3675: 0x37, 3676: 0x36, // Cmd

        // Teclado numérico
        69: 0x47, 3637: 0x4B, 55: 0x43, 74: 0x4E, 3597: 0x51, 78: 0x45, 3612: 0x4C, 83: 0x41,
        82: 0x52, 79: 0x53, 80: 0x54, 81: 0x55, 75: 0x56, 76: 0x57, 77: 0x58, 71: 0x59, 72: 0x5B, 73: 0x5C,
    ]

    /// La A: suena en las teclas que un pack «single» no define
    static let fallbackKey: UInt16 = 0x00
}
