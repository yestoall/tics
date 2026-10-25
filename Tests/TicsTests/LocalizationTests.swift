//· LocalizationTests ·
// Los textos de la app se escriben en español en el código y el catálogo
// (Resources/Localizable.xcstrings) trae cada uno en español y en inglés

import Foundation
import Testing

private let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

private struct Catalog: Decodable {
    struct Entry: Decodable { let localizations: [String: Localization] }
    struct Localization: Decodable { let stringUnit: Unit }
    struct Unit: Decodable { let value: String }
    let strings: [String: Entry]
}

private func catalog() throws -> Catalog {
    let data = try Data(contentsOf: root.appendingPathComponent("Resources/Localizable.xcstrings"))
    return try JSONDecoder().decode(Catalog.self, from: data)
}

/// Los textos de cara al usuario que hay en el código, con cada `\(…)` como `%`
private func sourceTexts() throws -> Set<String> {
    let patterns = [
        #/(?:Text|Button|Toggle|Label|Picker|\.help|\.accessibilityLabel)\("((?:[^"\\]|\\.)*)"/#,
        #/String\(localized: "((?:[^"\\]|\\.)*)"/#,
        #/(?:title|label): "((?:[^"\\]|\\.)*)"/#,
        #/case \.\w+: "((?:[^"\\]|\\.)*)"/#,
        #/isOn \? "((?:[^"\\]|\\.)*)" :/#,
        #/isOn \? "[^"]*" : "((?:[^"\\]|\\.)*)"/#,
    ]
    let folder = root.appendingPathComponent("Sources/Tics")
    var texts: Set<String> = []
    for file in try FileManager.default.contentsOfDirectory(atPath: folder.path) where file.hasSuffix(".swift") {
        let code = try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
        for line in code.split(separator: "\n") where !line.contains("log.") {
            for pattern in patterns {
                for match in line.matches(of: pattern) {
                    texts.insert(String(match.1)
                        .replacing(#/\\\([^)]*\)/#, with: "%")
                        .replacing("\\n", with: "\n"))
                }
            }
        }
    }
    return texts
}

/// La clave con sus `%lld` y `%@` como `%`, para compararla con el código
private func placeholders(_ key: String) -> String {
    key.replacing(#/%(lld|@)/#, with: "%")
}

@Test func cadaTextoDelCodigoEstaEnElCatalogo() throws {
    let keys = Set(try catalog().strings.keys.map(placeholders))
    let missing = try sourceTexts().subtracting(keys)
    #expect(missing.isEmpty, "Sin traducir: \(missing.sorted())")
}

@Test func cadaEntradaTraeEspañolEInglés() throws {
    for (key, entry) in try catalog().strings {
        #expect(entry.localizations["es"]?.stringUnit.value == key, "«\(key)» sin español")
        let english = entry.localizations["en"]?.stringUnit.value ?? ""
        #expect(!english.isEmpty, "«\(key)» sin inglés")
        // Los huecos de \(…) tienen que ser los mismos en los dos idiomas
        #expect(english.matches(of: #/%(lld|@)/#).map(\.0) == key.matches(of: #/%(lld|@)/#).map(\.0), "«\(key)»")
    }
}
