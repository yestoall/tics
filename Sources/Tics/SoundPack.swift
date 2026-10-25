//· SoundPack ·
// Un pack de sonido en formato Mechvibes: una carpeta con config.json y sus audios.
//  - «single»: un solo audio con todas las teclas seguidas; cada tecla es [inicio, duración] en ms
//  - «multi»: un archivo por tecla, con sonido al soltar («14-up») y variantes al azar («R{0-4}»)
// Y uno que no es carpeta: el sintético, que se calcula al cargarlo (KeySynth).

import Foundation

struct SoundPack: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        case folder(URL)
        case synthetic
    }

    let id: String
    let name: String
    let source: Source

    /// nil si el pack no viene de una carpeta
    var folder: URL? {
        if case let .folder(url) = source { url } else { nil }
    }

    static let synthetic = SoundPack(id: KeySynth.packID, name: String(localized: "Sintético"), source: .synthetic)
}

struct SoundPackConfig: Decodable {
    let name: String
    let keyDefineType: KeyDefineType
    let sound: String
    let soundup: String?
    let defines: [String: Define]

    enum KeyDefineType: String, Decodable {
        case single, multi
    }

    enum Define: Decodable {
        case segment(start: Double, duration: Double)
        case file(String)
        case none

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let pair = try? container.decode([Double].self), pair.count == 2 {
                self = .segment(start: pair[0], duration: pair[1])
            } else if let file = try? container.decode(String.self) {
                self = .file(file)
            } else {
                self = .none
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, sound, soundup, defines
        case keyDefineType = "key_define_type"
    }

    static func read(from folder: URL) throws -> SoundPackConfig {
        let data = try Data(contentsOf: folder.appendingPathComponent("config.json"))
        return try JSONDecoder().decode(SoundPackConfig.self, from: data)
    }
}

//- Dónde están los packs -

enum SoundPackLibrary {
    /// Los que vienen con la app
    static var bundledFolder: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("SoundPacks")
    }

    /// El pack por defecto
    static let oreoID = "eg-oreo"

    /// Todos los packs, por nombre
    static func loadAll() -> [SoundPack] {
        var packs: [SoundPack] = [.synthetic]
        if let bundledFolder { packs += scan(bundledFolder) }
        packs.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return packs
    }

    private static func scan(_ root: URL) -> [SoundPack] {
        let folders = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        return folders.compactMap { folder in
            guard let config = try? SoundPackConfig.read(from: folder) else { return nil }
            return SoundPack(id: folder.lastPathComponent, name: config.name, source: .folder(folder))
        }
    }
}
