//· UpdateChecker ·
// Mira en GitHub si hay una versión de TICS más nueva que la instalada: al arrancar y luego una vez
// al día. Pregunta por la última release de yestoall/tics y compara su número con el de la app. Es
// la única conexión de TICS a internet, y no manda nada más que esa pregunta.

import Foundation
import os

/// Un número de versión como 0.1.4, que se compara parte a parte: 0.1.10 va después de 0.1.9
struct AppVersion: Comparable, CustomStringConvertible {
    let parts: [Int]

    /// Acepta también la etiqueta de la release, con su «v» delante
    init?(_ text: String) {
        let number = text.hasPrefix("v") ? text.dropFirst() : Substring(text)
        let parts = number.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, !parts.contains(nil) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    /// La de la app instalada
    static let current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        .flatMap(AppVersion.init)

    var description: String { parts.map(String.init).joined(separator: ".") }

    // Las partes que faltan cuentan como 0: 0.1 y 0.1.0 son la misma
    private func part(_ index: Int) -> Int { index < parts.count ? parts[index] : 0 }

    static func < (a: AppVersion, b: AppVersion) -> Bool {
        for index in 0..<max(a.parts.count, b.parts.count) where a.part(index) != b.part(index) {
            return a.part(index) < b.part(index)
        }
        return false
    }

    static func == (a: AppVersion, b: AppVersion) -> Bool { !(a < b) && !(b < a) }
}

@MainActor
final class UpdateChecker {
    /// La descarga de la última versión, la misma que enlaza el README
    static let downloadURL = URL(string: "https://github.com/yestoall/tics/releases/latest/download/TICS.dmg")!
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/yestoall/tics/releases/latest")!

    /// Con cada respuesta: la versión nueva, o nil si la instalada ya es la última
    var onResult: ((AppVersion?) -> Void)?

    private var task: Task<Void, Never>?
    // Sin caché ni cookies: no queda nada guardado de la pregunta
    private let session = URLSession(configuration: .ephemeral)
    private let log = Logger(subsystem: "com.yestoall.tics", category: "UpdateChecker")

    func start(current: AppVersion) {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await check(current: current)
                // El reloj de Task.sleep sigue contando con el Mac dormido
                try? await Task.sleep(for: .seconds(24 * 60 * 60))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func check(current: AppVersion) async {
        do {
            let latest = try await latestVersion()
            log.info("Última versión: \(latest.description, privacy: .public); instalada: \(current.description, privacy: .public)")
            guard !Task.isCancelled else { return }
            onResult?(latest > current ? latest : nil)
        } catch {
            // Sin red, se queda como estaba hasta la próxima
            log.error("No se pudo mirar si hay versión nueva: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func latestVersion() async throws -> AppVersion {
        struct Release: Decodable { let tagName: String }
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let version = AppVersion(try decoder.decode(Release.self, from: data).tagName) else {
            throw URLError(.cannotParseResponse)
        }
        return version
    }
}
