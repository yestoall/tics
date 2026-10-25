//· CurrentSoundsTests ·
// Lo que suena ahora: el pack activo, los packs de origen de los ajustes del teclado, que solo se
// leen del disco cuando hace falta algo que no estaba, y los clics del ratón a la altura del pack

import AVFoundation
import Foundation
import Testing
@testable import Tics

private let packsFolder = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Resources/SoundPacks")

private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

private func pack(_ folder: String) -> SoundPack {
    SoundPack(id: folder, name: folder, source: .folder(packsFolder.appendingPathComponent(folder)))
}

private let packs = [pack("eg-oreo"), pack("holy-pandas"), pack("cherrymx-blue-abs")]
private let keyA: UInt16 = 0x00

/// Lo que suena, con un cargador que apunta qué packs lee del disco
private final class Disk {
    var loaded: [String] = []

    func makeSounds() throws -> CurrentSounds {
        var sounds = CurrentSounds(format: format) { [unowned self] pack in
            loaded.append(pack.id)
            return try PackLoader(format: format).load(pack)
        }
        try sounds.use(pack("eg-oreo"))
        loaded = []
        return sounds
    }
}

@Test func unPackDeOrigenSeLeeUnaVezAunqueCambienSuTonoYSuVolumen() throws {
    let disk = Disk()
    var sounds = try disk.makeSounds()
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: keyA))
    sounds.use(settings, packs: packs)
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: keyA, pitch: 2, volume: 0.5))
    sounds.use(settings, packs: packs)
    #expect(disk.loaded == ["holy-pandas"])
}

@Test func usarMenosDeUnPackNoLoVuelveALeerYUsarMasSi() throws {
    let disk = Disk()
    var sounds = try disk.makeSounds()
    var settings = KeyboardSettings()
    settings[.space].packID = "holy-pandas"
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: keyA))
    sounds.use(settings, packs: packs)
    // Menos: solo la tecla
    settings[.space].packID = nil
    sounds.use(settings, packs: packs)
    #expect(disk.loaded == ["holy-pandas"])
    // Más: otra vez el espacio, que ya se había soltado
    settings[.space].packID = "holy-pandas"
    sounds.use(settings, packs: packs)
    #expect(disk.loaded == ["holy-pandas", "holy-pandas"])
}

@Test func unaTeclaCambiadaSuenaConSuPackDeOrigen() throws {
    let disk = Disk()
    var sounds = try disk.makeSounds()
    let pandas = try PackLoader(format: format).load(pack("holy-pandas"))
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: "holy-pandas", sourceKey: keyA))
    sounds.use(settings, packs: packs)
    let oreo = try PackLoader(format: format).load(pack("eg-oreo"))
    // Lo que dura cada variante: igualar la altura no lo cambia
    func lengths(_ buffers: [AVAudioPCMBuffer]) -> Set<AVAudioFrameCount> { Set(buffers.map(\.frameLength)) }
    try #require(lengths(pandas.sounds(for: keyA, isDown: true)) != lengths(oreo.sounds(for: keyA, isDown: true)))
    let sound = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))
    let pressed = try #require(sound)
    #expect(lengths(pressed.variants) == lengths(pandas.sounds(for: keyA, isDown: true)))
}

@Test func losClicsSeRehacenAlCambiarLosAjustesDelRaton() throws {
    var sounds = try Disk().makeSounds()
    func loudness(_ buffers: [AVAudioPCMBuffer]) -> Float {
        buffers.map { Loudness.of($0) }.reduce(0, +) / Float(max(buffers.count, 1))
    }
    let before = loudness(sounds.clicks(.left, isDown: true))
    var settings = MouseSettings()
    settings[.left].volume = 2
    sounds.mouseSettings = settings
    #expect(abs(loudness(sounds.clicks(.left, isDown: true)) / before - 2) < 0.02)
}
