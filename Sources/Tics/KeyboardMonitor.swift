//· KeyboardMonitor ·
// Escucha el teclado de todo el sistema con un event tap de solo escucha: ve qué tecla
// se pulsa o se suelta, pero no puede bloquearla ni cambiarla. Nunca guarda lo que se escribe.

import CoreGraphics
import os

/// Una tecla que suena: su código virtual del Mac (kVK_*) y si se pulsa o se suelta
struct KeyEvent: Sendable {
    let keyCode: UInt16
    let isDown: Bool
    /// Las flags del CGEvent tal cual: qué modificadoras había pulsadas (ver KeyChord)
    var flags: UInt64 = 0
    /// Cuándo se pulsó, en ns de CLOCK_UPTIME_RAW (el reloj de CGEvent). 0 si no viene del teclado
    var timestamp: UInt64 = 0
    /// Una de las pulsaciones que repite macOS al mantener la tecla abajo
    var isRepeat = false
}

@MainActor
final class KeyboardMonitor {
    /// Se llama en el hilo principal con cada tecla que debe sonar
    var onKey: (@MainActor (KeyEvent) -> Void)?
    /// Calla las teclas que inyecta Logi Options+: mientras suenan los botones desviados, el
    /// atajo que ejecuta uno de ellos ya ha sonado como botón (`OptionsPlus`)
    var silencesOptionsPlus = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let log = Logger(subsystem: "com.yestoall.tics", category: "KeyboardMonitor")

    var isRunning: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    /// Crea el tap. Devuelve false si macOS no lo permite (falta el permiso)
    @discardableResult
    func start() -> Bool {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return true
        }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("No se pudo crear el event tap")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        log.info("Event tap en marcha")
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
        log.info("Event tap parado")
    }

    //- Eventos -

    fileprivate func handle(_ raw: RawKeyEvent) {
        switch raw.type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS apaga el tap si tarda en responder: se vuelve a encender al momento
            log.warning("macOS apagó el event tap; lo vuelvo a encender")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case _ where silencesOptionsPlus && OptionsPlus.isAgent(pid: raw.sourcePID):
            log.debug("Callo una tecla que inyecta Options+")
        default:
            if let event = raw.keyEvent { onKey?(event) }
        }
    }
}

/// Lo que el callback saca del CGEvent antes de pasarlo al monitor (solo valores simples)
struct RawKeyEvent: Sendable {
    let type: CGEventType
    let keyCode: UInt16
    let isAutorepeat: Bool
    let flags: UInt64
    let timestamp: UInt64
    /// El proceso que lo creó, si lo ha inyectado un programa
    let sourcePID: pid_t

    /// La tecla del globo (🌐) manda su propia pulsación además del cambio de Fn: sonaría dos veces
    private static let globeKey: UInt16 = 0xB3

    /// Cada modificador con su bit en las flags del evento. Son los bits «de dispositivo»
    /// (NX_DEVICE*KEYMASK), que distinguen la tecla izquierda de la derecha
    private static let modifierBits: [UInt16: UInt64] = [
        0x38: 0x0000_0002, // Shift izquierdo
        0x3C: 0x0000_0004, // Shift derecho
        0x3B: 0x0000_0001, // Control izquierdo
        0x3E: 0x0000_2000, // Control derecho
        0x3A: 0x0000_0020, // Option izquierdo
        0x3D: 0x0000_0040, // Option derecho
        0x37: 0x0000_0008, // Cmd izquierdo
        0x36: 0x0000_0010, // Cmd derecho
        0x3F: 0x0080_0000, // Fn
    ]

    /// La tecla que suena con este evento, si suena alguna
    var keyEvent: KeyEvent? {
        switch type {
        case .keyDown, .keyUp:
            // Mantener una tecla pulsada repite el evento: también suena, pero más flojo (KeyboardSounds)
            guard keyCode != Self.globeKey else { return nil }
            return KeyEvent(
                keyCode: keyCode, isDown: type == .keyDown, flags: flags, timestamp: timestamp, isRepeat: isAutorepeat
            )
        case .flagsChanged:
            return modifierEvent
        default:
            return nil
        }
    }

    /// Los modificadores no mandan «pulsar» y «soltar»: mandan un cambio de flags.
    /// Se mira el bit de esa tecla concreta para saber si ha bajado o subido
    private var modifierEvent: KeyEvent? {
        // Bloq Mayús manda «pulsar» al encenderse y «soltar» al apagarse, no al pulsarla y al soltarla
        if keyCode == KeyChord.capsLock {
            let isOn = flags & CGEventFlags.maskAlphaShift.rawValue != 0
            return KeyEvent(keyCode: keyCode, isDown: isOn, flags: flags, timestamp: timestamp)
        }
        guard let bit = Self.modifierBits[keyCode] else { return nil }
        return KeyEvent(keyCode: keyCode, isDown: flags & bit != 0, flags: flags, timestamp: timestamp)
    }
}

/// El callback del tap es una función de C: no puede capturar nada, así que el monitor
/// le llega por `userInfo`. Corre en el run loop principal, por eso puede entrar al MainActor
private func keyboardTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let raw = RawKeyEvent(
            type: type,
            keyCode: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)),
            isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            flags: event.flags.rawValue,
            timestamp: event.timestamp,
            sourcePID: pid_t(truncatingIfNeeded: event.getIntegerValueField(.eventSourceUnixProcessID))
        )
        let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        MainActor.assumeIsolated { monitor.handle(raw) }
    }
    return Unmanaged.passUnretained(event)
}
