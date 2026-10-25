//· LanguageTests ·
// El idioma que se elige en el panel y lo que se guarda para que TICS arranque en él

import Testing
@testable import Tics

@Test func unMacEnEspañolSaleEnEspañolSinGuardarNada() {
    #expect(Language.resolve(["es-ES", "en-US"]) == .es)
    #expect(Language.es.override(system: ["es-ES"]) == nil)
    #expect(Language.en.override(system: ["es-ES"]) == ["en"])
}

@Test func unMacEnOtroIdiomaSaleEnInglés() {
    #expect(Language.resolve(["fr-FR"]) == .en)
    #expect(Language.en.override(system: ["fr-FR"]) == nil)
    #expect(Language.es.override(system: ["fr-FR"]) == ["es"])
}

@Test func cadaIdiomaSeLlamaEnSuIdioma() {
    #expect(Language.allCases.map(\.name) == ["Español", "English"])
}
