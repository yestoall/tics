//· OptionsPlus ·
// Reconoce lo que inyecta Logi Options+. Al pulsar un botón desviado, Options+ ejecuta su función,
// y si es un clic o un atajo (⌘[ para «atrás»), lo inyecta él: los taps de TICS lo oirían, y la
// pulsación sonaría dos veces, como botón y como clic o tecla. Mientras suenan los botones
// desviados, eso se calla. Cada CGEvent dice qué proceso lo creó.

import Darwin

enum OptionsPlus {
    /// El proceso de Options+ que habla con el ratón y ejecuta las funciones
    static let agentName = "logioptionsplus_agent"

    static func isAgent(path: String) -> Bool {
        path.split(separator: "/").last == Substring(agentName)
    }

    /// Lo que se sabe de cada proceso que ha inyectado algo: así no se pregunta su ruta con
    /// cada evento
    @MainActor private static var known: [pid_t: Bool] = [:]

    @MainActor static func isAgent(pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        if let isAgent = known[pid] { return isAgent }
        // Un pid se puede reutilizar: de tanto en tanto se olvida todo
        if known.count > 64 { known = [:] }
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        let isAgent = length > 0 && isAgent(path: String(decoding: buffer.prefix(Int(length)), as: UTF8.self))
        known[pid] = isAgent
        return isAgent
    }
}
