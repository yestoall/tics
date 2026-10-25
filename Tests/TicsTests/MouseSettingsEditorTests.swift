//· MouseSettingsEditorTests ·
// La edición de los ajustes del ratón: mientras arrastras solo cambia lo que ves, y al soltar se
// guarda, se avisa al audio y suena la muestra. Con unas preferencias de usar y tirar

import Foundation
import Testing
@testable import Tics

/// Un editor con sus preferencias propias, que apunta las muestras, las vibraciones y los avisos
@MainActor
private final class Bench {
    let defaults = UserDefaults(suiteName: "tics-tests-\(UUID().uuidString)")!
    var samples: [MouseSound] = []
    var vibrations: [Vibration] = []
    var notified: [MouseSettings] = []
    private(set) var editor: MouseSettingsEditor!

    init() {
        editor = makeEditor()
    }

    /// Otro editor con las mismas preferencias, como al volver a abrir TICS
    func makeEditor() -> MouseSettingsEditor {
        MouseSettingsEditor(
            defaults: defaults,
            playSample: { [unowned self] in samples.append($0) },
            vibrate: { [unowned self] in vibrations.append($0) },
            settingsDidChange: { [unowned self] in notified.append($0) }
        )
    }
}

@MainActor @Test func moverUnSliderDelRatonNoAvisaHastaSoltarlo() {
    let bench = Bench()
    bench.editor.tune(.left, pitch: 2)
    bench.editor.tune(.left, volume: 0.5)
    bench.editor.tune(.left, timbre: -1)
    #expect(bench.editor.settings[.left] == SoundSettings(pitch: 2, volume: 0.5, timbre: -1))
    #expect(bench.notified.isEmpty && bench.samples.isEmpty)
    bench.editor.tuningDidChange(.left)
    #expect(bench.notified.last?[.left].pitch == 2)
    #expect(bench.samples == [.left])
}

@MainActor @Test func oirLaMuestraNoCambiaNada() {
    let bench = Bench()
    bench.editor.playSample(.scroll)
    #expect(bench.samples == [.scroll])
    #expect(bench.notified.isEmpty)
}

@MainActor @Test func elegirUnaVibracionLaGuardaYElRatonLaHaceUnaVez() {
    let bench = Bench()
    bench.editor.changeVibration(of: .right, to: .knock)
    #expect(bench.editor.settings[.right].vibration == .knock)
    #expect(bench.notified.last?[.right].vibration == .knock)
    #expect(bench.vibrations == [.knock])
    // Quitarla no vibra
    bench.editor.changeVibration(of: .right, to: .none)
    #expect(bench.vibrations == [.knock])
}

@MainActor @Test func restablecerElRatonLoDejaDeSerieYSuenaUnClic() {
    let bench = Bench()
    bench.editor.tune(.drag, volume: 3)
    bench.editor.changeVibration(of: .left, to: .tap)
    bench.editor.reset()
    #expect(bench.editor.settings == MouseSettings())
    #expect(bench.notified.last == MouseSettings())
    #expect(bench.samples.last == .left)
    #expect(bench.makeEditor().settings == MouseSettings())
}

@MainActor @Test func losAjustesDelRatonSeLeenAlVolverAAbrirTics() {
    let bench = Bench()
    bench.editor.tune(.scroll, volume: 2.5)
    bench.editor.tuningDidChange(.scroll)
    bench.editor.changeVibration(of: .extra, to: .wave)
    #expect(bench.makeEditor().settings == bench.editor.settings)
}
