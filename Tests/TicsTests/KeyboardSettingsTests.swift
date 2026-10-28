//· KeyboardSettingsTests ·
// Los ajustes del teclado y el pack que suena con ellos, con packs de verdad de Resources/SoundPacks

import AVFoundation
import Foundation
import Testing
@testable import Tics

private let packsFolder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/SoundPacks")

private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

private func load(_ folder: String) throws -> LoadedPack {
    let pack = SoundPack(id: folder, name: folder, source: .folder(packsFolder.appendingPathComponent(folder)))
    return try PackLoader(format: format).load(pack)
}

private let keyA: UInt16 = 0x00
private let keyB: UInt16 = 0x0B
private let keyReturn: UInt16 = 0x24
private let space = KeyGroup.spaceKey

//- De serie -

@Test func deSerieCadaTeclaSuenaComoEnElPackActivo() throws {
    let oreo = try load("eg-oreo")
    let sounds = KeyboardSounds(pack: oreo, settings: KeyboardSettings(), sources: [:])
    for key in [keyA, keyReturn, space] {
        for isDown in [true, false] {
            #expect(sounds.sounds(for: key, isDown: isDown) == oreo.sounds(for: key, isDown: isDown))
        }
    }
}

//- Teclas cambiadas -

/// Los mismos sonidos que `expected`, aunque sean copias a otra altura: mismas variantes y duraciones
private func sameSounds(_ sounds: [AVAudioPCMBuffer], _ expected: [AVAudioPCMBuffer]) -> Bool {
    sounds.map(\.frameLength).sorted() == expected.map(\.frameLength).sorted() && !sounds.isEmpty
}

@Test func unaTeclaCambiadaSuenaConLaTeclaDeOrigenDeSuPack() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["holy-pandas": pandas])

    #expect(sameSounds(sounds.sounds(for: keyA, isDown: true), pandas.sounds(for: space, isDown: true)))
    #expect(sameSounds(sounds.sounds(for: keyA, isDown: false), pandas.sounds(for: space, isDown: false)))
    // Las demás, como en el pack activo
    #expect(sounds.sounds(for: keyReturn, isDown: true) == oreo.sounds(for: keyReturn, isDown: true))
}

@Test func unaTeclaCambiadaSuenaALaAlturaDelPackActivo() throws {
    // Oreo es el más flojo de los packs, y el espacio del Cherry MX Blue suena más de 20 veces más
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "cherrymx-blue-abs", sourceKey: space))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    let level = Loudness.typical(of: sounds.sounds(for: keyA, isDown: true))
    let normal = oreo.only(.normal).typicalLoudness
    #expect(abs(level - normal) < normal * 0.05)
}

@Test func unaTeclaCambiadaSuenaALaAlturaDeSuGrupo() throws {
    // Return con el espacio del Cherry MX Blue: a la altura del Return de Oreo, no de sus normales
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyReturn), packID: "cherrymx-blue-abs", sourceKey: space))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    let enter = oreo.only(.enter).typicalLoudness
    let level = Loudness.typical(of: sounds.sounds(for: keyReturn, isDown: true))
    #expect(abs(level - enter) < enter * 0.05)
}

@Test func conOtroTonoSigueALaAlturaDelPackActivo() throws {
    // Más agudo es más corto, y sin igualar después sonaría más flojo
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    for pitch in [0.25, 4.0] {
        var settings = KeyboardSettings()
        settings.change(ChangedKey(key: KeyChord(keyA), packID: "cherrymx-blue-abs", sourceKey: space, pitch: pitch))
        let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])
        let level = Loudness.typical(of: sounds.sounds(for: keyA, isDown: true))
        let normal = oreo.only(.normal).typicalLoudness
        #expect(abs(level - normal) < normal * 0.05, "tono \(pitch)")
    }
}

@Test func aDosPorUnoUnaTeclaCambiadaSuenaElDoble() throws {
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "cherrymx-blue-abs", sourceKey: space, volume: 2))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    let level = Loudness.typical(of: sounds.sounds(for: keyA, isDown: true))
    let normal = oreo.only(.normal).typicalLoudness
    #expect(abs(level - 2 * normal) < normal * 0.1)
}

@Test func elTonoCambiaLaDuracionEnLaMismaProporcion() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    for pitch in [2.0, 0.5] {
        var settings = KeyboardSettings()
        settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space, pitch: pitch))
        let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["holy-pandas": pandas])
        for isDown in [true, false] {
            let original = pandas.sounds(for: space, isDown: isDown).map { Double($0.frameLength) }.sorted()
            let tuned = sounds.sounds(for: keyA, isDown: isDown).map { Double($0.frameLength) }.sorted()
            #expect(tuned.count == original.count)
            for (tuned, original) in zip(tuned, original) {
                #expect(abs(tuned - original / pitch) < 0.01 * original / pitch, "tono \(pitch)")
            }
        }
    }
}

@Test func siFaltaElPackDeOrigenLaTeclaSuenaComoEnElPackActivo() throws {
    let oreo = try load("eg-oreo")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "user/borrado", sourceKey: space))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: [:])
    #expect(sounds.sounds(for: keyA, isDown: true) == oreo.sounds(for: keyA, isDown: true))
}

//- Grupos de teclas -

/// Si `copy` es `original` subido o bajado, muestra a muestra
private func isScaled(_ copy: AVAudioPCMBuffer, of original: AVAudioPCMBuffer) -> Bool {
    guard copy.frameLength == original.frameLength, let a = copy.floatChannelData?[0],
          let b = original.floatChannelData?[0] else { return false }
    let frames = Int(copy.frameLength)
    let loudest = (0..<frames).max { abs(b[$0]) < abs(b[$1]) } ?? 0
    guard b[loudest] != 0 else { return false }
    let gain = a[loudest] / b[loudest]
    return (0..<frames).allSatisfy { abs(a[$0] - gain * b[$0]) < 1e-4 }
}

@Test func unGrupoCambiaCadaTeclaPorLaSuyaDelPackDeOrigen() throws {
    // El Cherry MX Blue trae cada tecla con su sonido
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    #expect(!isScaled(blue.sounds(for: keyA, isDown: true)[0], of: blue.sounds(for: keyB, isDown: true)[0]))
    var settings = KeyboardSettings()
    settings[.normal].packID = "cherrymx-blue-abs"
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    for key in [keyA, keyB] {
        for isDown in [true, false] {
            let changed = sounds.sounds(for: key, isDown: isDown)
            let own = blue.sounds(for: key, isDown: isDown)
            #expect(changed.count == own.count && zip(changed, own).allSatisfy { isScaled($0, of: $1) })
        }
    }
    // Los otros grupos, como en el pack activo
    #expect(sounds.sounds(for: space, isDown: true) == oreo.sounds(for: space, isDown: true))
    #expect(sounds.sounds(for: keyReturn, isDown: false) == oreo.sounds(for: keyReturn, isDown: false))
}

@Test func unGrupoDelPackSeAjustaSobreLoQueSuenaEnElPackActivo() throws {
    let oreo = try load("eg-oreo")
    var settings = KeyboardSettings()
    settings[.space] = ChangedGroup(packID: nil, pitch: 2, volume: 2)
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: [:])

    let own = oreo.sounds(for: space, isDown: true)
    let tuned = sounds.sounds(for: space, isDown: true)
    let ratio = Loudness.typical(of: tuned) / Loudness.typical(of: own)
    #expect(abs(ratio - 2) < 0.1)
    #expect(abs(Double(tuned[0].frameLength) - Double(own[0].frameLength) / 2) < Double(own[0].frameLength) * 0.01)
    #expect(sounds.sounds(for: keyA, isDown: true) == oreo.sounds(for: keyA, isDown: true))
}

@Test func unGrupoSuenaALaAlturaDelMismoGrupoEnElPackActivo() throws {
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    for volume in [1.0, 2.0] {
        var settings = KeyboardSettings()
        settings[.space] = ChangedGroup(packID: "cherrymx-blue-abs", pitch: 2, volume: volume)
        let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

        let target = Loudness.typical(of: oreo.sounds(for: space, isDown: true)) * Float(volume)
        let level = Loudness.typical(of: sounds.sounds(for: space, isDown: true))
        #expect(abs(level - target) < target * 0.05, "volumen \(volume)")
    }
}

@Test func unaTeclaCambiadaMandaSobreSuGrupo() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings[.normal].packID = "holy-pandas"
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "cherrymx-blue-abs", sourceKey: space))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["holy-pandas": pandas, "cherrymx-blue-abs": blue])

    #expect(sameSounds(sounds.sounds(for: keyA, isDown: true), blue.sounds(for: space, isDown: true)))
    #expect(sameSounds(sounds.sounds(for: keyB, isDown: true), pandas.sounds(for: keyB, isDown: true)))
}

@Test func unaTeclaDelPackSeAjustaSobreLoQueSuenaEnSuGrupo() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    var group = KeyboardSettings()
    group[.normal].packID = "holy-pandas"
    var settings = group
    settings.change(ChangedKey(key: KeyChord(keyA), packID: nil, sourceKey: keyA, pitch: 2, volume: 2))
    let base = KeyboardSounds(pack: oreo, settings: group, sources: ["holy-pandas": pandas])
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["holy-pandas": pandas])

    let own = base.sounds(for: keyA, isDown: true)
    let tuned = sounds.sounds(for: keyA, isDown: true)
    #expect(own.count == pandas.sounds(for: keyA, isDown: true).count)
    let ratio = Loudness.typical(of: tuned) / Loudness.typical(of: own)
    #expect(abs(ratio - 2) < 0.1)
    #expect(abs(Double(tuned[0].frameLength) - Double(own[0].frameLength) / 2) < Double(own[0].frameLength) * 0.01)
}

@Test func siFaltaElPackDeOrigenElGrupoSuenaComoEnElPackActivo() throws {
    let oreo = try load("eg-oreo")
    var settings = KeyboardSettings()
    settings[.wide].packID = "user/borrado"
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: [:])
    #expect(sounds.sounds(for: keyReturn, isDown: true) == oreo.sounds(for: keyReturn, isDown: true))
}

@Test func cambiarUnAjusteNoRehaceLoDemas() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    var settings = KeyboardSettings()
    settings[.normal] = ChangedGroup(packID: "holy-pandas", pitch: 2)
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space, pitch: 0.5))
    settings.change(ChangedKey(key: KeyChord(keyReturn), packID: "holy-pandas", sourceKey: keyA))
    let sources = ["holy-pandas": pandas]
    let before = KeyboardSounds(pack: oreo, settings: settings, sources: sources)
    settings.change(ChangedKey(key: KeyChord(keyReturn), packID: "holy-pandas", sourceKey: keyA, volume: 2))
    let after = before.updated(settings: settings, sources: sources)

    func same(_ key: UInt16) -> Bool {
        zip(before.sounds(for: key, isDown: true), after.sounds(for: key, isDown: true)).allSatisfy { $0 === $1 }
    }
    #expect(same(keyA))
    #expect(same(keyB))
    #expect(!same(keyReturn))
    // Y lo rehecho, como si se hiciera de cero
    let fresh = KeyboardSounds(pack: oreo, settings: settings, sources: sources)
    #expect(Loudness.typical(of: after.sounds(for: keyReturn, isDown: true))
        == Loudness.typical(of: fresh.sounds(for: keyReturn, isDown: true)))
}

@Test func deUnPackDeOrigenSoloSeQuedaLoQueSeUsa() throws {
    let pandas = try load("holy-pandas")
    var settings = KeyboardSettings()
    settings[.space].packID = "holy-pandas"
    settings.change(ChangedKey(key: KeyChord(keyReturn), packID: "holy-pandas", sourceKey: keyA))
    let use = try #require(settings.sources["holy-pandas"])
    #expect(use == SourceUse(groups: [.space], keys: [keyA]))

    // Las Holy Pandas no traen la A: suena el sonido de reserva, que se queda
    let kept = pandas.only(use)
    #expect(Set(kept.down.keys).isSubset(of: [keyA, space]))
    #expect(Set(kept.up.keys).isSubset(of: [keyA, space]))
    #expect(kept.down.count < pandas.down.count)
    for key in [keyA, space] {
        for isDown in [true, false] {
            #expect(kept.sounds(for: key, isDown: isDown) == pandas.sounds(for: key, isDown: isDown))
        }
    }
}

//- Ajustes -

@Test func unGrupoComoElDelPackNoSeGuarda() {
    var settings = KeyboardSettings()
    settings[.space] = ChangedGroup(packID: nil, volume: 2)
    settings[.space].volume = 1
    #expect(settings == KeyboardSettings())
}

@Test func losGruposSeGuardanYSeRecuperanIguales() throws {
    var settings = KeyboardSettings()
    settings[.normal].packID = "holy-pandas"
    settings[.wide] = ChangedGroup(packID: nil, pitch: 0.5, volume: 2)
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "eg-oreo", sourceKey: space))
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(KeyboardSettings.self, from: data) == settings)
}

@Test func unGrupoGuardadoFueraDeRangoSeQuedaEnElTope() throws {
    let json = #"{"changedGroups":{"space":{"packID":"holy-pandas","pitch":0.1,"volume":7}},"changedKeys":[]}"#
    let settings = try JSONDecoder().decode(KeyboardSettings.self, from: Data(json.utf8))
    #expect(settings[KeyGroup.space] == ChangedGroup(packID: "holy-pandas", pitch: 0.25, volume: 3))
}

@Test func cambiarOtraVezUnaTeclaSustituyeLoQueTenia() {
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space))
    settings.change(ChangedKey(key: KeyChord(keyReturn), packID: "eg-oreo", sourceKey: keyReturn))
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "turquoise", sourceKey: keyA))
    #expect(settings.changedKeys == [
        ChangedKey(key: KeyChord(keyA), packID: "turquoise", sourceKey: keyA),
        ChangedKey(key: KeyChord(keyReturn), packID: "eg-oreo", sourceKey: keyReturn),
    ])
    settings.remove(KeyChord(keyA))
    #expect(settings.changedKeys.map(\.key.keyCode) == [keyReturn])
}

@Test func losAjustesDelTecladoSeGuardanYSeRecuperanIguales() throws {
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space))
    settings.change(ChangedKey(key: KeyChord(0x37), packID: KeySynth.packID, sourceKey: keyReturn)) // Cmd
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(KeyboardSettings.self, from: data) == settings)
}

@Test func unaTeclaSinPackTodaviaSigueAlPackActivo() throws {
    // Recién elegida, antes de escoger de qué pack sale: si cambias de pack, suena con el nuevo
    let pandas = try load("holy-pandas")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: nil, sourceKey: keyA))
    let sounds = KeyboardSounds(pack: pandas, settings: settings, sources: [:])
    #expect(settings.sources.isEmpty)
    #expect(sounds.sounds(for: keyA, isDown: true) == pandas.sounds(for: keyA, isDown: true))
}

@Test func loGuardadoFueraDeRangoSeQuedaEnElTope() throws {
    let json = #"{"changedKeys":[{"key":0,"packID":"holy-pandas","sourceKey":49,"pitch":9,"volume":-1}]}"#
    let settings = try JSONDecoder().decode(KeyboardSettings.self, from: Data(json.utf8))
    #expect(settings[KeyChord(keyA)]?.pitch == 4)
    #expect(settings[KeyChord(keyA)]?.volume == 0)
}

@Test func loGuardadoAntesDelTonoYElVolumenSeLeeAUnoPorUno() throws {
    let json = #"{"changedKeys":[{"key":0,"packID":"holy-pandas","sourceKey":49}]}"#
    let settings = try JSONDecoder().decode(KeyboardSettings.self, from: Data(json.utf8))
    #expect(settings[KeyChord(keyA)] == ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space))
    #expect(settings[KeyChord(keyA)]?.pitch == 1)
    #expect(settings[KeyChord(keyA)]?.volume == 1)
}

@Test func unaTeclaDelPackSeAjustaSobreLoQueSuenaEnElPackActivo() throws {
    let pandas = try load("holy-pandas")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: nil, sourceKey: keyA, pitch: 2, volume: 2))
    let sounds = KeyboardSounds(pack: pandas, settings: settings, sources: [:])

    let own = pandas.sounds(for: keyA, isDown: true)
    let tuned = sounds.sounds(for: keyA, isDown: true)
    let ratio = Loudness.typical(of: tuned) / Loudness.typical(of: own)
    #expect(abs(ratio - 2) < 0.1)
    #expect(abs(Double(tuned[0].frameLength) - Double(own[0].frameLength) / 2) < Double(own[0].frameLength) * 0.01)
}

//- Atajos -

private let cmd = CGEventFlags.maskCommand.rawValue
private let shift = CGEventFlags.maskShift.rawValue
private let cmdA = KeyChord(keyCode: keyA, flags: cmd)
private let leftCmd: UInt16 = 0x37

@Test func cmdANoCambiaCmdMayusANiLaASola() throws {
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: cmdA, packID: "cherrymx-blue-abs", sourceKey: space))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    #expect(sameSounds(sounds.sounds(for: cmdA, isDown: true), blue.sounds(for: space, isDown: true)))
    #expect(sounds.sounds(for: KeyChord(keyCode: keyA, flags: cmd | shift), isDown: true) == oreo.sounds(for: keyA, isDown: true))
    #expect(sounds.sounds(for: keyA, isDown: true) == oreo.sounds(for: keyA, isDown: true))
}

@Test func conBloqMayusOFnEncendidosCmdASigueContando() throws {
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: cmdA, packID: "cherrymx-blue-abs", sourceKey: space))
    var sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    let others = CGEventFlags.maskAlphaShift.rawValue | CGEventFlags.maskSecondaryFn.rawValue
        | CGEventFlags.maskNumericPad.rawValue | 0x0000_0008 // el bit del Cmd izquierdo
    let event = KeyEvent(keyCode: keyA, isDown: true, flags: cmd | others)
    #expect(sameSounds(sounds.sound(for: event)?.variants ?? [], blue.sounds(for: space, isDown: true)))
}

@Test func unaModificadoraSolaEsUnaTecla() {
    #expect(!KeyChord(keyCode: leftCmd, flags: cmd | shift).isShortcut)
    #expect(KeyChord(keyCode: leftCmd, flags: cmd) == KeyChord(leftCmd))
}

@Test func unAtajoMandaSobreLaTecla() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: cmdA, packID: "cherrymx-blue-abs", sourceKey: space))
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["holy-pandas": pandas, "cherrymx-blue-abs": blue])

    #expect(sameSounds(sounds.sounds(for: cmdA, isDown: true), blue.sounds(for: space, isDown: true)))
    #expect(sameSounds(sounds.sounds(for: keyA, isDown: true), pandas.sounds(for: space, isDown: true)))
    // Un atajo que no está cambiado suena como su tecla
    #expect(sameSounds(sounds.sounds(for: KeyChord(keyCode: keyA, flags: shift), isDown: true), pandas.sounds(for: space, isDown: true)))
}

@Test func unAtajoDelPackParteDeSuTecla() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: space))
    settings.change(ChangedKey(key: cmdA, packID: nil, sourceKey: keyA, volume: 2))
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["holy-pandas": pandas])

    let key = sounds.sounds(for: keyA, isDown: true)
    let shortcut = sounds.sounds(for: cmdA, isDown: true)
    #expect(sameSounds(shortcut, key))
    #expect(abs(Loudness.typical(of: shortcut) / Loudness.typical(of: key) - 2) < 0.1)
}

@Test func alSoltarAntesElCmdSuenaElSoltarDelAtajo() throws {
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: cmdA, packID: "cherrymx-blue-abs", sourceKey: space))
    var sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    // Pulsar ⌘A, soltar el Cmd y soltar la A
    #expect(sameSounds(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true, flags: cmd))?.variants ?? [], blue.sounds(for: space, isDown: true)))
    #expect(sounds.sound(for: KeyEvent(keyCode: leftCmd, isDown: false))?.variants == oreo.sounds(for: leftCmd, isDown: false))
    let repeated = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true, isRepeat: true))?.variants ?? []
    #expect(sameSounds(repeated, blue.sounds(for: space, isDown: true)))
    #expect(sameSounds(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: false))?.variants ?? [], blue.sounds(for: space, isDown: false)))
    // La siguiente, sin Cmd, ya es la A sola
    #expect(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))?.variants == oreo.sounds(for: keyA, isDown: true))
}

@Test func loPulsadoSeRecuerdaAlCambiarDePack() throws {
    let oreo = try load("eg-oreo")
    let pandas = try load("holy-pandas")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: cmdA, packID: "cherrymx-blue-abs", sourceKey: space))
    var sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])

    // ⌘A abajo mientras cambias de pack: al soltar la A sigue siendo ⌘A
    _ = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true, flags: cmd))
    sounds.changePack(to: pandas, settings: settings, sources: ["cherrymx-blue-abs": blue])
    #expect(sameSounds(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: false))?.variants ?? [], blue.sounds(for: space, isDown: false)))
    // Lo demás ya suena con el pack nuevo
    #expect(sounds.sound(for: KeyEvent(keyCode: keyB, isDown: true))?.variants == pandas.sounds(for: keyB, isDown: true))
}

@Test func unaTeclaSolaSeGuardaComoAntesDeLosAtajos() throws {
    // Así la sigue leyendo un TICS anterior
    let data = try JSONEncoder().encode(KeyChord(keyA))
    #expect(String(decoding: data, as: UTF8.self) == "0")
}

@Test func unAtajoSeGuardaYSeRecuperaIgual() throws {
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyCode: keyA, flags: cmd | shift), packID: "holy-pandas", sourceKey: space))
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "eg-oreo", sourceKey: keyA))
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: data)
    #expect(decoded == settings)
    #expect(decoded.changedKeys.count == 2)
}

@Test func unAtajoSeLlamaConSusSimbolos() {
    #expect(KeyName.of(KeyChord(keyCode: 0x4F, flags: cmd | shift)) == "⇧⌘F18")
}

@Test func elControlSeLlamaCtrlPorqueSuSimboloParecePuntaDeFlecha() {
    let control = CGEventFlags.maskControl.rawValue
    #expect(KeyName.of(KeyChord(keyCode: 0x30, flags: control)) == "CTRL ⇥")
    #expect(KeyName.of(KeyChord(keyCode: keyA, flags: control | cmd)) == "CTRL ⌘A")
    #expect(KeyName.of(KeyChord(0x3B)) == "CTRL de la izquierda")
}

@Test func unaTeclaMantenidaRepiteMasFlojoYElEspacioNo() throws {
    var sounds = KeyboardSounds(pack: try load("eg-oreo"), settings: KeyboardSettings(), sources: [:])
    #expect(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))?.volume == 1)
    #expect(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true, isRepeat: true))?.volume == 0.4)
    #expect(sounds.sound(for: KeyEvent(keyCode: 0x33, isDown: true, isRepeat: true))?.volume == 0.4) // borrar
    // Mantener el espacio suele ser un modo, como mover el lienzo en Figma, no escribir espacios
    #expect(sounds.sound(for: KeyEvent(keyCode: space, isDown: true)) != nil)
    #expect(sounds.sound(for: KeyEvent(keyCode: space, isDown: true, isRepeat: true)) == nil)
}

@Test func returnEIntroVanEnSuGrupoYNoEnElDeLasAnchas() {
    #expect(KeyGroup(keyCode: keyReturn) == .enter)
    #expect(KeyGroup(keyCode: 0x4C) == .enter)
    #expect(KeyGroup(keyCode: 0x33) == .wide)
    #expect(KeyGroup.wide.keys.isDisjoint(with: KeyGroup.enter.keys))
}

@Test func returnSeCambiaSinTocarLasAnchas() throws {
    let oreo = try load("eg-oreo")
    let blue = try load("cherrymx-blue-abs")
    var settings = KeyboardSettings()
    settings[.enter].packID = "cherrymx-blue-abs"
    let sounds = KeyboardSounds(pack: oreo, settings: settings, sources: ["cherrymx-blue-abs": blue])
    // Return suena con el Cherry MX Blue; borrar, con Oreo
    func lengths(_ buffers: [AVAudioPCMBuffer]) -> Set<AVAudioFrameCount> { Set(buffers.map(\.frameLength)) }
    #expect(lengths(sounds.sounds(for: keyReturn, isDown: true)) == lengths(blue.only(.enter).sounds(for: keyReturn, isDown: true)))
    #expect(lengths(sounds.sounds(for: 0x33, isDown: true)) == lengths(oreo.sounds(for: 0x33, isDown: true)))
}
