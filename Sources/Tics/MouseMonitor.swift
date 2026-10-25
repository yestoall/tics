//· MouseMonitor ·
// Escucha los botones y la rueda del ratón con otro event tap de solo escucha, aparte del del
// teclado para poder encender uno sin el otro. Con el botón pulsado también mira cuánto se mueve
// el puntero: así distingue un clic de un arrastre, y marca el ritmo de los clics del arrastre.
// No guarda dónde se hace clic. Los botones extra que se queda Logi Options+ no llegan aquí:
// los oye `LogitechMonitor`, por Bluetooth.

import CoreGraphics
import os

enum MouseButton: Sendable, CaseIterable {
    case left, right, other
    /// Los que se queda Logi Options+: no llegan por el tap, los oye `LogitechMonitor`
    case diverted
}

enum MouseEvent: Sendable, Equatable {
    case button(MouseButton, isDown: Bool)
    /// Con el botón pulsado, el puntero ha recorrido lo suficiente para otro clic del arrastre.
    /// Despacio suena más flojo: `volume` va de `DragTracker.slowVolume` a 1
    case dragTick(volume: Float)
    /// La rueda ha avanzado otra muesca
    case scrollTick
}

/// Decide si lo que pasa con el botón pulsado es un clic o un arrastre, y cuándo toca cada
/// clic del arrastre: uno al empezar y otro cada tantos puntos recorridos. Como el trinquete de
/// una rueda, la separación depende de la velocidad: deprisa, un clic cada 40 puntos; despacio,
/// como al mover algo píxel a píxel en un diseño, cada 8, y más flojos. No sabe qué se arrastra
/// (una ventana, un texto, un fichero): solo que se mueve
struct DragTracker {
    /// Lo que hay que mover el puntero con el botón pulsado para que deje de ser un clic
    static let threshold = 6.0
    /// Con el botón un rato abajo ya no es un clic: basta con moverse esto para que sea arrastre,
    /// y así suenan los ajustes finos. Un clic de verdad dura menos y tiembla 1 o 2 puntos
    static let heldThreshold = 2.0
    static let holdDelay: UInt64 = 150_000_000
    /// Cada cuántos puntos recorridos suena un clic: despacio y deprisa. Entre medias, a medio camino
    static let slowSpacing = 8.0
    static let fastSpacing = 40.0
    /// Qué es despacio y qué es deprisa, en puntos por segundo
    static let slowSpeed = 60.0
    static let fastSpeed = 600.0
    /// Lo que suena un clic despacio, frente al 1 de deprisa
    static let slowVolume: Float = 0.8
    /// La velocidad se suaviza con lo último que se ha movido (s), para que un tirón no la dispare
    static let speedSmoothing = 0.1
    /// Como mucho un clic cada tanto (ns), para que deprisa no se vuelva una ráfaga
    static let minTickInterval: UInt64 = 35_000_000

    private var origin: CGPoint?
    private var last: CGPoint?
    private var pressTime: UInt64 = 0
    private var lastMove: UInt64 = 0
    private var speed: Double?
    private var travelled = 0.0
    private var lastTick: UInt64 = 0
    private(set) var isDragging = false

    mutating func press(at point: CGPoint, time: UInt64) {
        origin = point
        last = point
        pressTime = time
        lastMove = time
        speed = nil
        travelled = 0
        isDragging = false
    }

    /// Si con este movimiento toca un clic del arrastre, lo fuerte que suena (de `slowVolume` a 1)
    mutating func move(to point: CGPoint, time: UInt64) -> Float? {
        guard let origin, let last else { return nil }
        let step = hypot(point.x - last.x, point.y - last.y)
        updateSpeed(step: step, time: time)
        self.last = point
        if !isDragging {
            let distance = hypot(point.x - origin.x, point.y - origin.y)
            let isHeld = time &- pressTime >= Self.holdDelay
            guard distance >= (isHeld ? Self.heldThreshold : Self.threshold) else { return nil }
            isDragging = true
            return tick(at: time)
        }
        travelled += step
        guard travelled >= spacing, time &- lastTick >= Self.minTickInterval else { return nil }
        return tick(at: time)
    }

    /// Un arrastre que ya va por la mitad: llega un movimiento con el botón pulsado sin su pulsar,
    /// porque otra app se lo ha quedado (yabai, al mover ventanas con Alt). Suena al momento, en
    /// lugar del clic que no llegó
    mutating func join(at point: CGPoint, time: UInt64) -> Float {
        press(at: point, time: time)
        isDragging = true
        return tick(at: time)
    }

    /// Al soltar el botón. Devuelve si había arrastre
    mutating func release() -> Bool {
        defer {
            origin = nil
            last = nil
            isDragging = false
        }
        return isDragging
    }

    /// De 0 (despacio) a 1 (deprisa)
    private var pace: Double {
        guard let speed else { return 1 }
        return min(max((speed - Self.slowSpeed) / (Self.fastSpeed - Self.slowSpeed), 0), 1)
    }

    private var spacing: Double {
        Self.slowSpacing + (Self.fastSpacing - Self.slowSpacing) * pace
    }

    /// Media que va olvidando lo de antes: lo de hace `speedSmoothing` s ya pesa poco
    private mutating func updateSpeed(step: Double, time: UInt64) {
        let seconds = Double(time &- lastMove) / 1e9
        guard seconds > 0 else { return }
        lastMove = time
        let current = step / seconds
        guard let speed else {
            self.speed = current
            return
        }
        self.speed = speed + (current - speed) * (1 - exp(-seconds / Self.speedSmoothing))
    }

    /// Lo recorrido de más se olvida: si el tope ha frenado los clics, no se acumulan para después
    private mutating func tick(at time: UInt64) -> Float {
        travelled = 0
        lastTick = time
        return Self.slowVolume + (1 - Self.slowVolume) * Float(pace)
    }
}

/// Cuándo suena la rueda: un clic suave cada vez que avanza al menos una línea, como el trinquete
/// de una rueda de verdad. Con el desplazamiento suave (Logi Options+ en las MX), la rueda no manda
/// muescas sino un flujo de eventos, y deprisa varias líneas en cada uno: por eso el tope. El
/// trackpad no suena: no tiene muescas, y se le distingue porque sus eventos traen fase o inercia
struct ScrollTracker {
    /// Como mucho un clic cada tanto (ns), como en el arrastre
    static let minTickInterval: UInt64 = 35_000_000

    private var lastTick: UInt64?

    /// Si con este evento de la rueda toca un clic
    mutating func scroll(lines: Int64, phase: Int64, momentum: Int64, time: UInt64) -> Bool {
        guard phase == 0, momentum == 0, lines > 0 else { return false }
        if let lastTick, time &- lastTick < Self.minTickInterval { return false }
        lastTick = time
        return true
    }
}

/// De lo que trae el tap a lo que suena: los clics, los clics del arrastre y los de la rueda. Lleva
/// la cuenta de qué botón empezó el arrastre, y de los arrastres que empiezan sin su clic
struct MouseEventDecoder {
    /// Un arrastre que empezó sin su pulsar se da por acabado tras esto sin movimientos (ns)
    static let joinedGap: UInt64 = 300_000_000

    private var drag = DragTracker()
    private var scroll = ScrollTracker()
    /// El botón que empezó el arrastre: los demás que se pulsen mientras tanto solo hacen clic
    private var heldButton: MouseButton?
    /// Si el arrastre empezó sin su pulsar (`DragTracker.join`): tampoco llegará su soltar, así
    /// que se da por acabado con el siguiente clic o tras `joinedGap` sin movimientos
    private var isJoined = false
    private var lastDragged: UInt64 = 0

    /// Lo que suena con este evento, si suena algo
    mutating func decode(_ raw: RawMouseEvent) -> MouseEvent? {
        switch raw.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            let button = Self.button(of: raw.type)
            if heldButton == nil || isJoined {
                heldButton = button
                isJoined = false
                drag.press(at: raw.location, time: raw.timestamp)
            }
            return .button(button, isDown: true)
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            defer { lastDragged = raw.timestamp }
            // Sin pulsar previo, o tras un rato quieto en uno así: es un arrastre cuyo clic se quedó otra app
            if heldButton == nil || (isJoined && raw.timestamp &- lastDragged > Self.joinedGap) {
                heldButton = Self.button(of: raw.type)
                isJoined = true
                return .dragTick(volume: drag.join(at: raw.location, time: raw.timestamp))
            }
            return drag.move(to: raw.location, time: raw.timestamp).map { .dragTick(volume: $0) }
        case .scrollWheel:
            let ticks = scroll.scroll(
                lines: raw.scrollLines, phase: raw.scrollPhase, momentum: raw.momentumPhase, time: raw.timestamp
            )
            return ticks ? .scrollTick : nil
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            let button = Self.button(of: raw.type)
            if button == heldButton {
                heldButton = nil
                isJoined = false
                _ = drag.release()
            }
            return .button(button, isDown: false)
        default:
            return nil
        }
    }

    /// Al parar el tap: lo que hubiera pulsado ya no soltará por aquí
    mutating func reset() {
        _ = drag.release()
        heldButton = nil
        isJoined = false
    }

    private static func button(of type: CGEventType) -> MouseButton {
        switch type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged: .left
        case .rightMouseDown, .rightMouseUp, .rightMouseDragged: .right
        default: .other
        }
    }
}

@MainActor
final class MouseMonitor {
    /// Se llama en el hilo principal con cada clic y con cada movimiento de un arrastre
    var onMouse: (@MainActor (MouseEvent) -> Void)?
    /// Calla los clics que inyecta Logi Options+: mientras suenan los botones desviados, el clic
    /// que ejecuta uno de ellos ya ha sonado como botón (`OptionsPlus`). La rueda no: con el
    /// desplazamiento suave, todos sus eventos los inyecta Options+
    var silencesOptionsPlus = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var decoder = MouseEventDecoder()
    private let log = Logger(subsystem: "com.yestoall.tics", category: "MouseMonitor")

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
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .scrollWheel,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: mouseTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("No se pudo crear el event tap del ratón")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        log.info("Event tap del ratón en marcha")
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
        decoder.reset()
        log.info("Event tap del ratón parado")
    }

    //- Eventos -

    fileprivate func handle(_ raw: RawMouseEvent) {
        switch raw.type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            log.warning("macOS apagó el event tap del ratón; lo vuelvo a encender")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case _ where raw.type != .scrollWheel && silencesOptionsPlus && OptionsPlus.isAgent(pid: raw.sourcePID):
            log.debug("Callo un clic que inyecta Options+")
        default:
            if let event = decoder.decode(raw) { onMouse?(event) }
        }
    }
}

/// Lo que el callback saca del CGEvent antes de pasarlo al monitor (solo valores simples)
struct RawMouseEvent: Sendable {
    let type: CGEventType
    let location: CGPoint
    let timestamp: UInt64
    /// El proceso que lo creó, si lo ha inyectado un programa
    let sourcePID: pid_t
    /// De la rueda: líneas que ha avanzado (en vertical y en horizontal) y su fase, que solo trae el trackpad
    var scrollLines: Int64 = 0
    var scrollPhase: Int64 = 0
    var momentumPhase: Int64 = 0
}

/// Igual que el del teclado: función de C sin capturas, con el monitor en `userInfo`
private func mouseTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        var raw = RawMouseEvent(
            type: type, location: event.location, timestamp: event.timestamp,
            sourcePID: pid_t(truncatingIfNeeded: event.getIntegerValueField(.eventSourceUnixProcessID))
        )
        if type == .scrollWheel {
            raw.scrollLines = abs(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
                + abs(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            raw.scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            raw.momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        }
        let monitor = Unmanaged<MouseMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        MainActor.assumeIsolated { monitor.handle(raw) }
    }
    return Unmanaged.passUnretained(event)
}
