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
        var sounds = CurrentSounds(format: format, load: { [unowned self] pack in
            loaded.append(pack.id)
            return try PackLoader(format: format).load(pack)
        }, loadCustom: { _ in nil })
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
    // Sin las copias de otro tono, que duran algo más o algo menos
    settings.variesPitch = false
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

//- Variar el tono -

@Test func cadaPulsacionEligeEntreElSonidoYUnaCopiaDeOtroTono() throws {
    var sounds = try Disk().makeSounds()
    let oreo = try PackLoader(format: format).load(pack("eg-oreo"))
    let original = try #require(oreo.sounds(for: keyA, isDown: true).first)
    let pressed = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))
    let variants = try #require(pressed).variants
    #expect(variants.count == 2)
    // La copia, más grave y más larga o más aguda y más corta, en la misma proporción que el tono
    #expect(variants[0].frameLength == original.frameLength)
    let length = Double(variants[1].frameLength) / Double(original.frameLength)
    #expect(PitchVariants.pitches.contains { abs(length - 1 / $0) < 0.01 })
    // También al soltar
    let released = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: false))
    #expect(try #require(released).variants.count == 2)
}

@Test func lasCopiasSonUnasMasGravesYOtrasMasAgudas() throws {
    let oreo = try PackLoader(format: format).load(pack("eg-oreo"))
    let buffers = Array(oreo.allBuffers.prefix(10))
    let expanded = PitchVariants().updated(for: buffers).expanded(buffers)
    let ratios = stride(from: 0, to: expanded.count, by: 2).map {
        Double(expanded[$0 + 1].frameLength) / Double(expanded[$0].frameLength)
    }
    #expect(ratios.contains { $0 > 1 } && ratios.contains { $0 < 1 })
}

@Test func conVariarElTonoApagadoSuenaSoloLaGrabacion() throws {
    var sounds = try Disk().makeSounds()
    var settings = KeyboardSettings()
    settings.variesPitch = false
    sounds.use(settings, packs: packs)
    let oreo = try PackLoader(format: format).load(pack("eg-oreo"))
    let pressed = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))
    let variants = try #require(pressed).variants
    #expect(variants.map(\.frameLength) == oreo.sounds(for: keyA, isDown: true).map(\.frameLength))
}

@Test func cambiarOtroAjusteNoRecalculaLasCopias() throws {
    let disk = Disk()
    var sounds = try disk.makeSounds()
    let first = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))
    let before = try #require(first).variants
    var settings = KeyboardSettings()
    settings[.space].pitch = 1.2
    sounds.use(settings, packs: packs)
    let second = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))
    let after = try #require(second).variants
    #expect(zip(before, after).allSatisfy { $0 === $1 })
}

@Test func losAjustesGuardadosAntesDeVariarElTonoLoLeenEncendido() throws {
    let saved = try JSONDecoder().decode(KeyboardSettings.self, from: Data(#"{"changedKeys":[]}"#.utf8))
    #expect(saved.variesPitch)
    var off = KeyboardSettings()
    off.variesPitch = false
    let reread = try JSONDecoder().decode(KeyboardSettings.self, from: JSONEncoder().encode(off))
    #expect(!reread.variesPitch)
}

//- Sonidos propios -

/// Lo que suena con un sonido propio en la A, guardado en una carpeta propia
private func soundsWithCustomA(tone: Double = 0.5) throws -> (CurrentSounds, CustomSoundStore, CustomSound) {
    let store = makeTestStore()
    let custom = try store.importSound(from: testWav(silence: 0, tone: tone))
    var sounds = CurrentSounds(format: format, load: { try PackLoader(format: format).load($0) }, loadCustom: store.load)
    try sounds.use(pack("eg-oreo"))
    return (sounds, store, custom)
}

@Test func unSonidoPropioSuenaEnteroAlPulsarYNadaAlSoltar() throws {
    var (sounds, store, custom) = try soundsWithCustomA()
    var settings = KeyboardSettings()
    settings.variesPitch = false
    settings.change(ChangedKey(key: KeyChord(keyA), packID: nil, sourceKey: keyA, customSound: custom))
    sounds.use(settings, packs: packs)
    let sound = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))
    let pressed = try #require(sound)
    let copy = try #require(store.load(custom))
    #expect(pressed.variants.map(\.frameLength) == [copy.frameLength])
    // A la altura de las teclas normales de Oreo, aunque el fichero suene mucho más fuerte
    let normal = try PackLoader(format: format).load(pack("eg-oreo")).only(.normal).typicalLoudness
    #expect(abs(Loudness.of(pressed.variants[0]) / normal - 1) < 0.05)
    #expect(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: false)) == nil)
}

@Test func siFaltaLaCopiaLaTeclaSuenaComoEnElPack() throws {
    var (sounds, store, custom) = try soundsWithCustomA()
    try FileManager.default.removeItem(at: store.folder)
    var settings = KeyboardSettings()
    settings.variesPitch = false
    settings.change(ChangedKey(key: KeyChord(keyA), packID: nil, sourceKey: keyA, customSound: custom))
    sounds.use(settings, packs: packs)
    let oreo = try PackLoader(format: format).load(pack("eg-oreo"))
    let sound = sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true))
    let pressed = try #require(sound)
    #expect(pressed.variants.map(\.frameLength) == oreo.sounds(for: keyA, isDown: true).map(\.frameLength))
}

@Test func unSonidoPropioNoSuenaEnLasRepeticiones() throws {
    var (sounds, _, custom) = try soundsWithCustomA()
    var settings = KeyboardSettings()
    settings.change(ChangedKey(key: KeyChord(keyA), packID: nil, sourceKey: keyA, customSound: custom))
    sounds.use(settings, packs: packs)
    #expect(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true)) != nil)
    // Mantenerla pulsada amontonaría el sonido entero hasta 30 veces por segundo
    #expect(sounds.sound(for: KeyEvent(keyCode: keyA, isDown: true, isRepeat: true)) == nil)
    // Las de un pack siguen sonando, más flojo
    #expect(sounds.sound(for: KeyEvent(keyCode: 0x0B, isDown: true, isRepeat: true)) != nil)
}
