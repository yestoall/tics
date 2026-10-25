//· DivertedButtons ·
// Los botones desviados de un ratón Logitech, a partir de lo que manda por Bluetooth. Options+
// le pide al ratón que esos botones no lleguen a macOS sino que le avise a él; el aviso va por el
// servicio Bluetooth de Logitech, y TICS lo lee como un segundo oyente.
// Habla HID++ 2.0: cada mensaje empieza por el índice de la función del ratón a la que se refiere
// y un byte con el número de la orden y quién pregunta (0 si es un aviso del ratón). Las
// funciones van por número (REPROG_CONTROLS_V4 es la 0x1B04), pero cada modelo las tiene en un
// índice distinto: hay que preguntarlo. Un teclado Logitech trae el mismo servicio y también
// desvía teclas: por eso se pregunta además qué aparato es, y solo suena un ratón. También se
// pregunta por HAPTIC (0x19B0): con ella, el ratón vibra (el MX Master 4).

import Foundation

struct DivertedButtons {
    /// Un botón que baja o sube. `control` es su id de Logitech (0x0053, atrás; 0x0056, adelante…)
    struct Change: Equatable {
        let control: UInt16
        let isDown: Bool
    }

    /// Lo que sale de un mensaje del ratón: los botones que han cambiado y, si toca, la siguiente
    /// pregunta que hay que mandarle
    struct Reply {
        var changes: [Change] = []
        var nextRequest: Data?
    }

    /// Nuestros números de remitente, uno por pregunta: el ratón lo devuelve en la respuesta, que
    /// no repite por qué función se preguntó, y así tampoco se confunde con las de Options+
    private static let reprogAsker: UInt8 = 0x0A
    private static let nameTypeAsker: UInt8 = 0x0B
    private static let hapticAsker: UInt8 = 0x0C

    /// Lo que hay que preguntarle al ratón al empezar: en qué índice tiene REPROG_CONTROLS_V4
    /// (0x1B04), DEVICE_NAME_TYPE (0x0005) y HAPTIC (0x19B0). Es getFeature, la orden 0 de la
    /// función raíz, que siempre está en el 0
    static let requests = [
        message([0x00, reprogAsker, 0x1B, 0x04]),
        message([0x00, nameTypeAsker, 0x00, 0x05]),
        message([0x00, hapticAsker, 0x19, 0xB0]),
    ]

    /// Los aparatos que suenan como ratón, según getDeviceType: ratón, trackpad y trackball
    private static let pointingTypes: Set<UInt8> = [3, 4, 5]

    /// Dónde tiene este ratón la función REPROG_CONTROLS_V4: cambia de un modelo a otro
    private var reprogIndex: UInt8?
    private var nameTypeIndex: UInt8?
    private var hapticIndex: UInt8?
    /// Si es un ratón; nil hasta que conteste
    private var isMouse: Bool?
    /// Los botones desviados que están abajo, según el último aviso
    private var held: [UInt16] = []

    /// Si ya ha contestado a todo y es un ratón: desde ahora, sus botones desviados suenan
    var isReady: Bool { reprogIndex != nil && isMouse == true }

    /// Si el ratón vibra: tiene HAPTIC
    var canVibrate: Bool { hapticIndex != nil && isMouse == true }

    /// El mensaje que lo hace vibrar con ese efecto: la orden 4 de HAPTIC con su id. Nil si no vibra
    func vibration(_ vibration: Vibration) -> Data? {
        guard canVibrate, let hapticIndex, let effect = vibration.effect else { return nil }
        return Self.message([hapticIndex, 0x40 | Self.hapticAsker, effect])
    }

    /// Lo que manda el ratón, tal cual
    mutating func receive(_ data: Data) -> Reply {
        let bytes = [UInt8](data)
        guard bytes.count >= 3 else { return Reply() }
        switch (bytes[0], bytes[1]) {
        // Las respuestas a getFeature: 0 si el ratón no tiene la función
        case (0x00, Self.reprogAsker):
            reprogIndex = bytes[2] == 0 ? nil : bytes[2]
            held = []
        case (0x00, Self.nameTypeAsker):
            nameTypeIndex = bytes[2] == 0 ? nil : bytes[2]
            // Con el índice, ya se puede preguntar qué aparato es: getDeviceType, la orden 2
            if let nameTypeIndex { return Reply(nextRequest: Self.message([nameTypeIndex, 0x20 | Self.nameTypeAsker])) }
        case (0x00, Self.hapticAsker):
            hapticIndex = bytes[2] == 0 ? nil : bytes[2]
        case (nameTypeIndex, 0x20 | Self.nameTypeAsker):
            isMouse = Self.pointingTypes.contains(bytes[2])
        // Orden 0 de REPROG_CONTROLS_V4, de parte del ratón: qué botones desviados están abajo.
        // Detrás manda la 2, con cada pulsar y soltar, para las estadísticas de Options+: se ignora
        case (reprogIndex, 0x00) where isReady:
            return Reply(changes: buttonChanges(bytes))
        default:
            break
        }
        return Reply()
    }

    /// Hasta cuatro botones abajo, de dos bytes cada uno; los huecos van a cero
    private mutating func buttonChanges(_ bytes: [UInt8]) -> [Change] {
        let now = stride(from: 2, to: min(bytes.count, 10) - 1, by: 2)
            .map { UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1]) }
            .filter { $0 != 0 }
        defer { held = now }
        return held.filter { !now.contains($0) }.map { Change(control: $0, isDown: false) }
            + now.filter { !held.contains($0) }.map { Change(control: $0, isDown: true) }
    }

    /// Un mensaje HID++ largo, sin el número de informe ni el del aparato, que por Bluetooth no van:
    /// 18 bytes, el resto a cero
    private static func message(_ bytes: [UInt8]) -> Data {
        Data(bytes + [UInt8](repeating: 0, count: 18 - bytes.count))
    }
}
