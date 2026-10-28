//· KeyboardSettingsEditorTests ·
// La edición de los ajustes del teclado: elegir teclas y atajos pulsándolos, lo que se calla al
// elegir, los packs, el tono y el volumen, y lo que se guarda. Con eventos de teclado inventados y
// unas preferencias de usar y tirar

import CoreGraphics
import Foundation
import Testing
@testable import Tics

private let keyA: UInt16 = 0x00
private let keyB: UInt16 = 0x0B
private let leftCmd: UInt16 = 0x37
private let leftShift: UInt16 = 0x38
private let cmd = CGEventFlags.maskCommand.rawValue
private let shift = CGEventFlags.maskShift.rawValue
private let cmdA = KeyChord(keyCode: keyA, flags: cmd)

private func down(_ keyCode: UInt16, flags: UInt64 = 0, repeat isRepeat: Bool = false) -> KeyEvent {
    KeyEvent(keyCode: keyCode, isDown: true, flags: flags, isRepeat: isRepeat)
}

private func up(_ keyCode: UInt16, flags: UInt64 = 0) -> KeyEvent {
    KeyEvent(keyCode: keyCode, isDown: false, flags: flags)
}

/// Un editor con sus preferencias propias, que apunta las muestras y los avisos al audio
@MainActor
private final class Bench {
    let defaults: UserDefaults
    let customSounds = makeTestStore()
    var samples: [KeyChord] = []
    var notified: [KeyboardSettings] = []
    private(set) var editor: KeyboardSettingsEditor!

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: "tics-tests-\(UUID().uuidString)")!
        editor = makeEditor()
    }

    /// Otro editor con las mismas preferencias, como al volver a abrir TICS
    func makeEditor() -> KeyboardSettingsEditor {
        KeyboardSettingsEditor(
            defaults: defaults,
            customSounds: customSounds,
            playSample: { [unowned self] in samples.append($0) },
            settingsDidChange: { [unowned self] in notified.append($0) }
        )
    }

    /// Los eventos que suenan de los que se le pasan
    func sounding(_ events: KeyEvent...) -> [KeyEvent] {
        events.filter { editor.letsSound($0) }
    }
}

//- Elegir pulsando -

@MainActor @Test func unaTeclaSeEligeAlPulsarlaYNoSuena() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    #expect(bench.sounding(down(keyA), up(keyA)).isEmpty)
    #expect(bench.editor.settings[KeyChord(keyA)] == ChangedKey(key: KeyChord(keyA), packID: nil, sourceKey: keyA))
    #expect(bench.editor.keyCapture == nil)
}

@MainActor @Test func conLaModificadoraPulsadaSeEligeElAtajoYNadaSuena() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    #expect(bench.sounding(down(leftCmd, flags: cmd), down(keyA, flags: cmd), up(keyA, flags: cmd), up(leftCmd)).isEmpty)
    #expect(bench.editor.settings[cmdA] != nil)
    #expect(bench.editor.settings[KeyChord(keyA)] == nil)
    // Lo que venga después ya suena
    #expect(bench.sounding(down(keyA), up(keyA)).count == 2)
}

@MainActor @Test func unaModificadoraSoltadaSinMasSeEligeSola() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    #expect(bench.sounding(down(leftCmd, flags: cmd), up(leftCmd)).isEmpty)
    #expect(bench.editor.settings[KeyChord(leftCmd)] != nil)
}

@MainActor @Test func conDosModificadorasSeEligeLaPrimeraAlSoltarLasDos() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(leftCmd, flags: cmd), down(leftShift, flags: cmd | shift))
    // Soltar el Mayúsculas no elige: aún puedes pulsar la A
    _ = bench.sounding(up(leftShift, flags: cmd))
    #expect(bench.editor.keyCapture == .newKey)
    _ = bench.sounding(up(leftCmd))
    #expect(bench.editor.settings[KeyChord(leftCmd)] != nil)
    #expect(bench.editor.settings[KeyChord(leftShift)] == nil)
}

@MainActor @Test func unaRepeticionNoEligeNada() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyA, repeat: true))
    #expect(bench.editor.keyCapture == .newKey)
    #expect(bench.editor.settings.changedKeys.isEmpty)
}

@MainActor @Test func bloqMayusSeEligeAlApagarlaYLaSiguienteVezSuena() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    // Bloq Mayús «suelta» al apagarse
    #expect(bench.sounding(up(KeyChord.capsLock)).isEmpty)
    #expect(bench.editor.settings[KeyChord(KeyChord.capsLock)] != nil)
    #expect(bench.sounding(down(KeyChord.capsLock)).count == 1)
}

@MainActor @Test func laTeclaElegidaNoSuenaSiLaMantienes() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    #expect(bench.sounding(down(keyA), down(keyA, repeat: true), down(keyA, repeat: true), up(keyA)).isEmpty)
}

@MainActor @Test func unaTeclaYaCambiadaNoSeVuelveAAnadir() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyA), up(keyA))
    bench.notified = []
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyA), up(keyA))
    #expect(bench.editor.settings.changedKeys.count == 1)
    #expect(bench.notified.isEmpty)
}

@MainActor @Test func pulsarOtraVezElBotonDejaDeEsperar() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    bench.editor.capture(.newKey)
    #expect(bench.editor.keyCapture == nil)
    #expect(bench.sounding(down(keyA)).count == 1)
}

//- La tecla de origen -

/// Un editor con la A cambiada y esperando su tecla de origen en Holy Pandas
@MainActor private func benchWaitingForSource() -> Bench {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyA), up(keyA))
    bench.editor.changePack(of: KeyChord(keyA), to: "holy-pandas")
    return bench
}

@MainActor @Test func alElegirUnPackSeEsperaSuTeclaYSuenaLaMuestra() {
    let bench = benchWaitingForSource()
    #expect(bench.editor.keyCapture == .source(of: KeyChord(keyA)))
    #expect(bench.editor.settings[KeyChord(keyA)]?.packID == "holy-pandas")
    #expect(bench.samples == [KeyChord(keyA)])
}

@MainActor @Test func laTeclaDeOrigenSeEligeSuenaSuMuestraYSeSigueEsperando() {
    let bench = benchWaitingForSource()
    #expect(bench.sounding(down(keyB), down(keyB, repeat: true), up(keyB)).isEmpty)
    #expect(bench.editor.settings[KeyChord(keyA)]?.sourceKey == keyB)
    #expect(bench.samples == [KeyChord(keyA), KeyChord(keyA)])
    // Para probar otra
    #expect(bench.editor.keyCapture == .source(of: KeyChord(keyA)))
}

@MainActor @Test func delPackDevuelveSuTeclaYDejaDeEsperar() {
    let bench = benchWaitingForSource()
    _ = bench.sounding(down(keyB), up(keyB))
    bench.editor.changePack(of: KeyChord(keyA), to: nil)
    #expect(bench.editor.settings[KeyChord(keyA)]?.sourceKey == keyA)
    #expect(bench.editor.keyCapture == nil)
}

@MainActor @Test func quitarLaTeclaQueEsperaSuOrigenDejaDeEsperar() {
    let bench = benchWaitingForSource()
    bench.editor.remove(KeyChord(keyA))
    #expect(bench.editor.settings[KeyChord(keyA)] == nil)
    #expect(bench.editor.keyCapture == nil)
    #expect(bench.sounding(down(keyB)).count == 1)
}

//- La ventana -

@MainActor @Test func conLaVentanaDetrasNoSeEligeYLoPulsadoNoSuenaAlSoltar() {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(leftCmd, flags: cmd))
    bench.editor.stopCapturing()
    #expect(bench.editor.settings.changedKeys.isEmpty)
    #expect(bench.sounding(up(leftCmd)).isEmpty)
    #expect(bench.sounding(down(leftCmd, flags: cmd)).count == 1)
}

@MainActor @Test func alCerrarLaVentanaSeOlvidaLoQueSeCallaba() {
    let bench = benchWaitingForSource()
    _ = bench.sounding(down(keyB))
    bench.editor.endEditing()
    #expect(bench.editor.keyCapture == nil)
    // El soltar de la B, que se eligió con la ventana abierta, ya suena
    #expect(bench.sounding(up(keyB)).count == 1)
}

//- Grupos, tono y volumen -

@MainActor @Test func moverUnSliderNoAvisaHastaSoltarlo() {
    let bench = benchWaitingForSource()
    bench.notified = []
    bench.samples = []
    bench.editor.tune(KeyChord(keyA), pitch: 0.5)
    bench.editor.tune(KeyChord(keyA), volume: 2)
    #expect(bench.editor.settings[KeyChord(keyA)]?.pitch == 0.5)
    #expect(bench.notified.isEmpty)
    bench.editor.tuningDidChange(KeyChord(keyA))
    #expect(bench.notified.last?[KeyChord(keyA)]?.volume == 2)
    #expect(bench.samples == [KeyChord(keyA)])
}

@MainActor @Test func unGrupoCambiaDePackYSuenaUnaDeSusTeclas() {
    let bench = Bench()
    bench.editor.changePack(of: .space, to: "holy-pandas")
    #expect(bench.editor.settings[.space].packID == "holy-pandas")
    #expect(bench.samples == [KeyChord(KeyGroup.space.sampleKey)])
    #expect(bench.notified.count == 1)
    bench.editor.tune(.space, pitch: 2)
    #expect(bench.notified.count == 1)
    bench.editor.tuningDidChange(.space)
    #expect(bench.notified.last?[.space].pitch == 2)
}

@MainActor @Test func restablecerLoDejaTodoComoEnElPackActivoYDejaDeEsperar() {
    let bench = benchWaitingForSource()
    bench.editor.changePack(of: .normal, to: "holy-pandas")
    bench.editor.reset()
    #expect(bench.editor.settings == KeyboardSettings())
    #expect(bench.editor.keyCapture == nil)
    #expect(bench.notified.last == KeyboardSettings())
}

//- Lo guardado -

@MainActor @Test func loGuardadoSeLeeAlVolverAAbrirTics() {
    let bench = benchWaitingForSource()
    _ = bench.sounding(down(keyB), up(keyB))
    bench.editor.changePack(of: .wide, to: "holy-pandas")
    bench.editor.tune(KeyChord(keyA), volume: 1.5)
    bench.editor.tuningDidChange(KeyChord(keyA))
    #expect(bench.makeEditor().settings == bench.editor.settings)
}

//- Sonidos propios -

@MainActor @Test func alPonerUnFicheroEnUnaTeclaSuenaSeGuardaYDejaLaTeclaDeOrigen() throws {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyB), up(keyB))
    bench.editor.changePack(of: KeyChord(keyB), to: "holy-pandas")
    bench.samples = []
    bench.editor.setCustomSound(of: KeyChord(keyB), from: try testWav(silence: 0, tone: 0.5, name: "ding.wav"))
    let changed = try #require(bench.editor.settings[KeyChord(keyB)])
    #expect(changed.customSound?.name.hasSuffix("ding.wav") == true)
    #expect(changed.packID == nil)
    // Ya no espera la tecla del pack de origen, y suena la tecla para oírlo
    #expect(bench.editor.keyCapture == nil)
    #expect(bench.samples == [KeyChord(keyB)])
    #expect(bench.makeEditor().settings[KeyChord(keyB)]?.customSound == changed.customSound)
    #expect(bench.customSounds.contains(try #require(changed.customSound)))
}

@MainActor @Test func unFicheroQueNoSeLeeDejaLaTeclaComoEstabaYLoDice() throws {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyB), up(keyB))
    let before = bench.editor.settings
    let pdf = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-notas.pdf")
    try Data("%PDF".utf8).write(to: pdf)
    bench.editor.setCustomSound(of: KeyChord(keyB), from: pdf)
    #expect(bench.editor.settings == before)
    #expect(bench.editor.unreadableFiles[KeyChord(keyB)] == pdf.lastPathComponent)
    // Se va al cambiar algo de la tecla
    bench.editor.tune(KeyChord(keyB), volume: 2)
    bench.editor.tuningDidChange(KeyChord(keyB))
    #expect(bench.editor.unreadableFiles[KeyChord(keyB)] == nil)
}

@MainActor @Test func laCopiaSeBorraCuandoYaNoLaUsaNingunaTecla() throws {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyB), up(keyB))
    bench.editor.setCustomSound(of: KeyChord(keyB), from: try testWav(silence: 0, tone: 0.5))
    let first = try #require(bench.editor.settings[KeyChord(keyB)]?.customSound)
    // Otro fichero en la misma tecla: el primero sobra
    bench.editor.setCustomSound(of: KeyChord(keyB), from: try testWav(silence: 0, tone: 0.5))
    let second = try #require(bench.editor.settings[KeyChord(keyB)]?.customSound)
    #expect(!bench.customSounds.contains(first))
    // De vuelta a un pack, sobra el segundo
    bench.editor.changePack(of: KeyChord(keyB), to: nil)
    #expect(bench.editor.settings[KeyChord(keyB)]?.customSound == nil)
    #expect(!bench.customSounds.contains(second))
}

@MainActor @Test func siFaltaLaCopiaAlAbrirTicsLaFilaLoSabe() throws {
    let bench = Bench()
    bench.editor.capture(.newKey)
    _ = bench.sounding(down(keyB), up(keyB))
    bench.editor.setCustomSound(of: KeyChord(keyB), from: try testWav(silence: 0, tone: 0.5))
    let sound = try #require(bench.editor.settings[KeyChord(keyB)]?.customSound)
    #expect(bench.editor.missingCopies.isEmpty)
    try FileManager.default.removeItem(at: bench.customSounds.folder.appendingPathComponent(sound.file))
    // Otra vez abierta: falta, y la tecla cambiada sigue ahí, con su sonido propio
    let reopened = bench.makeEditor()
    #expect(reopened.missingCopies == [sound])
    #expect(reopened.settings[KeyChord(keyB)]?.customSound == sound)
}
