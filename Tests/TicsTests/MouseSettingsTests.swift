//· MouseSettingsTests ·
// Los ajustes del ratón: el tono, el volumen y el timbre de cada sonido del ratón, y cómo suenan

import AVFoundation
import Foundation
import Testing
@testable import Tics

//- Ajustes -

@Test func deSerieCadaSonidoSuenaComoHoy() {
    let settings = MouseSettings()
    for sound in MouseSound.allCases {
        #expect(settings[sound] == SoundSettings(pitch: 1, volume: 1, timbre: 0))
    }
}

@Test func losAjustesSeGuardanYSeRecuperanIguales() throws {
    var settings = MouseSettings()
    settings[.right].pitch = 0.6
    settings[.scroll].volume = 2.5
    settings[.drag].timbre = -1.25
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(MouseSettings.self, from: data) == settings)
}

@Test func loQueVieneFueraDeRangoSeQuedaEnElTope() {
    var settings = MouseSettings()
    settings[.left] = SoundSettings(pitch: 9, volume: -1, timbre: 5)
    #expect(settings[.left] == SoundSettings(pitch: 4, volume: 0, timbre: 2))
}

//- Cómo suenan -

private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
/// Un pack flojo: así ningún clic llega al tope del pico y se puede medir lo que suena
private let keyLoudness: Float = 0.01

private func loudness(_ buffers: [AVAudioPCMBuffer]?) -> Float {
    let values = (buffers ?? []).map { Loudness.of($0) }
    return values.reduce(0, +) / Float(max(values.count, 1))
}

@Test func elVolumenMultiplicaLoQueSuenaCadaSonido() {
    var settings = MouseSettings()
    settings[.left].volume = 2
    settings[.drag].volume = 0.5
    let plain = MouseSynth.clicks(format: format, keyLoudness: keyLoudness)
    let tuned = MouseSynth.clicks(format: format, keyLoudness: keyLoudness, settings: settings)
    #expect(abs(loudness(tuned.down[.left]) / loudness(plain.down[.left]) - 2) < 0.02)
    #expect(abs(loudness(tuned.drag) / loudness(plain.drag) - 0.5) < 0.01)
    // Los demás, como estaban
    #expect(abs(loudness(tuned.down[.right]) / loudness(plain.down[.right]) - 1) < 0.01)
}

@Test func elTimbreNoCambiaLoFuerteQueSuena() {
    for timbre in [-2.0, 2.0] {
        var settings = MouseSettings()
        settings[.left].timbre = timbre
        let plain = MouseSynth.clicks(format: format, keyLoudness: keyLoudness)
        let tuned = MouseSynth.clicks(format: format, keyLoudness: keyLoudness, settings: settings)
        #expect(abs(loudness(tuned.down[.left]) / loudness(plain.down[.left]) - 1) < 0.01, "timbre \(timbre)")
    }
}

@Test func elTimbreHuecoAlargaElClicYElSecoNo() {
    var settings = MouseSettings()
    settings[.left].timbre = 2
    settings[.right].timbre = -2
    let clicks = MouseSynth.clicks(format: format, keyLoudness: keyLoudness, settings: settings)
    let plain = MouseSynth.clicks(format: format, keyLoudness: keyLoudness)
    #expect(clicks.down[.left]![0].frameLength > plain.down[.left]![0].frameLength)
    #expect(clicks.down[.right]![0].frameLength == plain.down[.right]![0].frameLength)
}

@Test func laRuedaTieneSusPropiosClicsMasFlojosQueElArrastre() {
    var settings = MouseSettings()
    settings[.drag].volume = 3
    let clicks = MouseSynth.clicks(format: format, keyLoudness: keyLoudness, settings: settings)
    #expect(clicks.scroll.count == MouseSynth.variantCount)
    // A su altura de siempre (el 70 % del arrastre), aunque el arrastre se haya subido
    #expect(abs(loudness(clicks.scroll) - keyLoudness * MouseSynth.dragLoudness * 0.7) < keyLoudness * 0.01)
}

//- Vibración -

@Test func deSerieNingunBotonVibra() {
    let settings = MouseSettings()
    for sound in MouseSound.allCases {
        #expect(settings[sound].vibration == .none)
    }
}

@Test func laVibracionSeGuardaYSeRecupera() throws {
    var settings = MouseSettings()
    settings[.left].vibration = .knock
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(MouseSettings.self, from: data)[.left].vibration == .knock)
}

@Test func losAjustesGuardadosAntesDeLaVibracionSeSiguenLeyendo() throws {
    // Como se guardaban antes de la vibración: sin ese campo
    let old = #"{"sounds":{"right":{"pitch":0.5,"volume":2,"timbre":1}}}"#
    let settings = try JSONDecoder().decode(MouseSettings.self, from: Data(old.utf8))
    #expect(settings[.right] == SoundSettings(pitch: 0.5, volume: 2, timbre: 1))
    #expect(settings[.right].vibration == .none)
}

@Test func cadaVibracionLlevaElIdDeSuEfectoEnElRaton() {
    #expect(Vibration.none.effect == nil)
    #expect(Vibration.allCases.compactMap(\.effect) == [0x00, 0x02, 0x06, 0x09, 0x0B])
}
