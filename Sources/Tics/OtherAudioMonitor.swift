//· OtherAudioMonitor ·
// Qué otras apps tienen abierta la salida de audio. macOS lleva una lista de los procesos que usan
// el audio y avisa cuando cambia, así que no se mira nada cada cierto tiempo, y no pide permisos:
// dice quién tiene la salida abierta, no qué suena. Tenerla abierta no siempre es sonar (una app de
// llamadas puede dejarla abierta en silencio), pero Dia, por ejemplo, la cierra al pausar un vídeo.
// La lista de procesos es de macOS 14.2; en un 14.0 o 14.1 no hace nada.

import AppKit
import CoreAudio
import os

@MainActor
final class OtherAudioMonitor {
    /// Con cada cambio: el nombre de las apps que tienen la salida abierta, sin contar TICS
    var onChange: (([String]) -> Void)?

    private var isRunning = false
    /// Los procesos a los que ya se escucha, para no apuntarse dos veces
    private var watched: Set<AudioObjectID> = []
    private let log = Logger(subsystem: "com.yestoall.tics", category: "OtherAudioMonitor")
    /// El mismo bloque para todo: para dejar de escuchar, macOS pide el que se le dio
    private lazy var listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        MainActor.assumeIsolated { self?.update() }
    }

    static var isAvailable: Bool {
        if #available(macOS 14.2, *) { true } else { false }
    }

    func start() {
        guard #available(macOS 14.2, *), !isRunning else { return }
        isRunning = true
        var address = Self.address(kAudioHardwarePropertyProcessObjectList)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        update()
    }

    func stop() {
        guard #available(macOS 14.2, *), isRunning else { return }
        isRunning = false
        var address = Self.address(kAudioHardwarePropertyProcessObjectList)
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        for process in watched {
            var running = Self.address(kAudioProcessPropertyIsRunning)
            AudioObjectRemovePropertyListenerBlock(process, &running, .main, listener)
        }
        watched = []
    }

    /// Con cada aviso, la lista entera otra vez: son unas pocas decenas de procesos
    private func update() {
        guard #available(macOS 14.2, *), isRunning else { return }
        let processes = Self.processes()
        // A cada proceso nuevo, que avise cuando abra o cierre la salida. Se escucha IsRunning y se
        // lee IsRunningOutput: macOS nunca avisa de IsRunningOutput, y entonces se veía a Dia
        // empezar (abre un proceso nuevo) pero no parar. Los que ya no están se han llevado su escucha
        for process in processes where !watched.contains(process) {
            var running = Self.address(kAudioProcessPropertyIsRunning)
            AudioObjectAddPropertyListenerBlock(process, &running, .main, listener)
        }
        watched = Set(processes)

        let ownPID = getpid()
        var apps: [String] = []
        for process in processes {
            guard let pid: pid_t = Self.value(of: kAudioProcessPropertyPID, in: process), pid != ownPID,
                  let output: UInt32 = Self.value(of: kAudioProcessPropertyIsRunningOutput, in: process),
                  output != 0 else { continue }
            let name = Self.appName(pid: pid)
            if !apps.contains(name) { apps.append(name) }
        }
        log.info("Salida abierta por otras apps: \(apps.joined(separator: ", "), privacy: .public)")
        onChange?(apps)
    }

    @available(macOS 14.2, *)
    private static func processes() -> [AudioObjectID] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &processes) == noErr else { return [] }
        return processes
    }

    private static func value<T>(of selector: AudioObjectPropertySelector, in object: AudioObjectID) -> T? {
        var address = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        let value = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { value.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, value) == noErr else { return nil }
        return value.pointee
    }

    /// El nombre de la app: el sonido de un navegador sale de un ayudante metido dentro de ella
    /// (Dia.app/…/Browser Helper.app), así que vale la .app de más fuera de su ruta
    private static func appName(pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return "pid \(pid)" }
        let path = String(cString: buffer)
        if let range = path.range(of: ".app/") {
            let app = String(path[..<range.lowerBound]) + ".app"
            return FileManager.default.displayName(atPath: app).replacingOccurrences(of: ".app", with: "")
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
        )
    }
}
