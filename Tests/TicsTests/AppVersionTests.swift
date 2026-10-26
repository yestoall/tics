//· AppVersionTests ·
// El número de la última release de GitHub contra el de la app instalada, para saber si avisar

import Testing
@testable import Tics

@Test func laEtiquetaDeLaReleaseSeLeeConSuV() {
    #expect(AppVersion("v0.1.5")?.description == "0.1.5")
    #expect(AppVersion("0.1.4")?.description == "0.1.4")
}

@Test func seComparaParteAParteNoComoTexto() throws {
    let nueve = try #require(AppVersion("0.1.9"))
    let diez = try #require(AppVersion("0.1.10"))
    #expect(diez > nueve)
    #expect(try #require(AppVersion("1.0")) > diez)
}

@Test func laMismaVersionNoEsNueva() throws {
    let instalada = try #require(AppVersion("0.1.4"))
    #expect(!(try #require(AppVersion("v0.1.4")) > instalada))
    #expect(try #require(AppVersion("0.1.4.0")) == instalada)
    #expect(try #require(AppVersion("0.1.3")) < instalada)
}

@Test func unaEtiquetaQueNoEsUnNumeroNoVale() {
    #expect(AppVersion("beta") == nil)
    #expect(AppVersion("v0.1.") == nil)
    #expect(AppVersion("") == nil)
}
