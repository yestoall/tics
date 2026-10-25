//· PackLoaderTests ·
// Carga de verdad los packs de Resources/SoundPacks y comprueba que suenan todas sus teclas

import AVFoundation
import Foundation
import Testing
@testable import Tics

private let packsFolder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/SoundPacks")

private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

private func bundledPacks() throws -> [SoundPack] {
    try FileManager.default.contentsOfDirectory(at: packsFolder, includingPropertiesForKeys: nil)
        .filter { FileManager.default.fileExists(atPath: $0.appendingPathComponent("config.json").path) }
        .map { SoundPack(id: $0.lastPathComponent, name: $0.lastPathComponent, source: .folder($0)) }
}

@Test func vienenDiezPacks() throws {
    #expect(try bundledPacks().count == 10)
}

@Test(arguments: try bundledPacks())
func elPackCargaYTodasSusTeclasSuenan(pack: SoundPack) throws {
    let loaded = try PackLoader(format: format).load(pack)

    #expect(!loaded.fallbackDown.isEmpty, "sin sonido de reserva al pulsar")
    #expect(!loaded.fallbackUp.isEmpty, "sin sonido de reserva al soltar")

    let config = try SoundPackConfig.read(from: try #require(pack.folder))
    if config.keyDefineType == .single {
        // Cada tecla definida que existe en el Mac tiene su fragmento al pulsar y al soltar
        let expected = config.defines.compactMap { key, define -> UInt16? in
            guard case .segment = define, let code = Int(key) else { return nil }
            return KeyCodes.uiohookToMac[code]
        }
        for code in expected {
            #expect(loaded.down[code]?.isEmpty == false, "falta la tecla 0x\(String(code, radix: 16)) al pulsar")
            #expect(loaded.up[code]?.isEmpty == false, "falta la tecla 0x\(String(code, radix: 16)) al soltar")
        }
    }

    // Todos los fragmentos están en el formato del motor y tienen audio
    let all = loaded.down.values.flatMap { $0 } + loaded.up.values.flatMap { $0 } + loaded.fallbackDown
    for buffer in all {
        #expect(buffer.format == format)
        #expect(buffer.frameLength > 0)
    }
}

@Test func lasVariantesMultiSeCarganTodas() throws {
    let pack = SoundPack(id: "holy-pandas", name: "Holy Panda", source: .folder(packsFolder.appendingPathComponent("holy-pandas")))
    let loaded = try PackLoader(format: format).load(pack)
    // «GENERIC_R{0-4}.mp3»: cinco variantes para las teclas sin sonido propio
    #expect(loaded.fallbackDown.count == 5)
}

@Test func lasLetrasDelPcCaenEnSuTeclaDelMac() {
    // A, Z, Return, espacio y Shift izquierdo
    #expect(KeyCodes.uiohookToMac[30] == 0x00)
    #expect(KeyCodes.uiohookToMac[44] == 0x06)
    #expect(KeyCodes.uiohookToMac[28] == 0x24)
    #expect(KeyCodes.uiohookToMac[57] == 0x31)
    #expect(KeyCodes.uiohookToMac[42] == 0x38)
}

//- El sintético -

@Test func elPackSinteticoSeCalculaConTodasSusTeclas() throws {
    let loaded = try PackLoader(format: format).load(.synthetic)
    #expect(loaded.fallbackDown.count == KeySynth.variantCount)
    #expect(loaded.fallbackUp.count == KeySynth.variantCount)
    for key in KeySynth.wideKeys + [KeySynth.space] {
        #expect(loaded.down[key]?.count == KeySynth.wideVariantCount)
        #expect(loaded.up[key]?.count == KeySynth.wideVariantCount)
    }
    // Pulsar suena a lo pedido y soltar, más flojo
    let down = Loudness.typical(of: loaded.fallbackDown)
    let up = Loudness.typical(of: loaded.fallbackUp)
    #expect(abs(down - KeySynth.loudness) < KeySynth.loudness * 0.01)
    #expect(abs(up - KeySynth.loudness * KeySynth.releaseLoudness) < KeySynth.loudness * 0.01)
}

@Test func elSinteticoSaleEnLaListaAunqueNoSeaUnaCarpeta() {
    #expect(SoundPackLibrary.loadAll().contains(.synthetic))
}

@Test func misTicsYaNoSaleEnLaLista() {
    // Salía de los duelos del configurador, que ya no está
    #expect(!SoundPackLibrary.loadAll().contains { $0.id == "my-tics" })
}

@Test @MainActor func quienTeniaMisTicsVuelveAlPackDeSerieYSeBorraLaReceta() throws {
    let defaults = try #require(UserDefaults(suiteName: "TicsTests.misTics"))
    defer { defaults.removePersistentDomain(forName: "TicsTests.misTics") }
    defaults.set(Data([1]), forKey: "myTicsRecipe")
    defaults.set("my-tics", forKey: "selectedPackID")

    #expect(AppState.forgetMyTics(defaults, selectedPackID: "my-tics") == AppState.defaultPackID)
    #expect(defaults.object(forKey: "myTicsRecipe") == nil)
    #expect(defaults.string(forKey: "selectedPackID") == nil)
    // Cualquier otro pack se queda
    #expect(AppState.forgetMyTics(defaults, selectedPackID: "holy-pandas") == "holy-pandas")
}

//- Igualar -

@Test func igualarDejaUnGrupoALaAlturaPedida() throws {
    let folder = packsFolder.appendingPathComponent("holy-pandas")
    let pack = try PackLoader(format: format).load(SoundPack(id: "holy-pandas", name: "Holy Pandas", source: .folder(folder)))
    let target: Float = 0.03 // la de un pack de los de en medio, como el Sintético

    // Lo que suenan sus teclas, contando el sonido de reserva en las que no tienen el suyo: en las
    // anchas, las Holy Pandas solo traen Return y borrar
    for group in KeyGroup.allCases {
        let level = pack.only(group).leveled(to: target).typicalLoudness
        #expect(abs(level - target) < target * 0.05, "\(group)")
    }
}
