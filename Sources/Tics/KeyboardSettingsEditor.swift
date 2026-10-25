//· KeyboardSettingsEditor ·
// Los ajustes del teclado y su edición: elegir una tecla o un atajo pulsándolo, elegir la tecla de
// origen de una tecla cambiada, y el pack, el tono y el volumen de los grupos y las teclas. Lo que
// pulsas para elegir no suena, ni al soltarlo ni al repetirse. Guarda los ajustes en cada cambio y
// avisa al audio; vive lo que la app, con la ventana abierta o cerrada.

import Foundation
import Observation

@MainActor @Observable
final class KeyboardSettingsEditor {
    /// Qué tecla espera la ventana: la que vas a cambiar, o la del pack de origen que va a sonar en
    /// una tecla cambiada
    enum KeyCapture: Equatable {
        case newKey
        case source(of: KeyChord)
    }

    private(set) var settings: KeyboardSettings
    /// Mientras la ventana espera una tecla, lo que pulsas no suena: se elige
    private(set) var keyCapture: KeyCapture?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let playSample: @MainActor (KeyChord) -> Void
    @ObservationIgnored private let settingsDidChange: @MainActor (KeyboardSettings) -> Void
    /// Las teclas que se eligieron al pulsarlas: su soltar tampoco suena
    @ObservationIgnored private var mutedReleases: Set<UInt16> = []
    /// Lo que llevas pulsado mientras la ventana espera una tecla o un atajo nuevo
    @ObservationIgnored private var chordCapture = ChordCapture()

    private static let key = "keyboardSettings"

    /// `playSample` hace sonar una tecla con los ajustes que tenga; `settingsDidChange` llega con
    /// cada cambio guardado, para que el audio lo rehaga
    init(
        defaults: UserDefaults,
        playSample: @escaping @MainActor (KeyChord) -> Void,
        settingsDidChange: @escaping @MainActor (KeyboardSettings) -> Void
    ) {
        self.defaults = defaults
        self.playSample = playSample
        self.settingsDidChange = settingsDidChange
        settings = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(KeyboardSettings.self, from: $0) } ?? KeyboardSettings()
    }

    //- Teclas -

    /// Si esta tecla debe sonar. Mientras se espera una, ninguna: se elige
    func letsSound(_ event: KeyEvent) -> Bool {
        if let keyCapture {
            choose(with: event, for: keyCapture)
            return false
        }
        // La tecla recién elegida: ni su soltar ni sus repeticiones, si la mantienes
        if event.isRepeat, mutedReleases.contains(event.keyCode) { return false }
        if !event.isDown, mutedReleases.remove(event.keyCode) != nil { return false }
        return true
    }

    /// Empieza a esperar una tecla, o deja de esperarla si ya era esa
    func capture(_ capture: KeyCapture) {
        mutedReleases.formUnion(chordCapture.held)
        keyCapture = keyCapture == capture ? nil : capture
        chordCapture = ChordCapture()
    }

    /// Con la ventana detrás, lo que escribes es para otra app: no se elige nada. Lo que tenías
    /// pulsado para elegir no suena al soltarlo
    func stopCapturing() {
        keyCapture = nil
        mutedReleases.formUnion(chordCapture.held)
        chordCapture = ChordCapture()
    }

    /// Al cerrar la ventana: deja de esperar y olvida lo que callaba. Lo que sigas teniendo pulsado
    /// suena al soltarlo, como con la ventana cerrada
    func endEditing() {
        stopCapturing()
        mutedReleases = []
    }

    /// Una tecla o un atajo nuevo empieza «Del pack», sonando como antes (ver ChordCapture). La
    /// tecla del pack de origen se queda y suena; la ventana sigue esperando, para probar otra.
    /// Lo que pulsas para elegir no suena, ni al soltarlo
    private func choose(with event: KeyEvent, for capture: KeyCapture) {
        if !event.isDown, event.keyCode != KeyChord.capsLock { mutedReleases.remove(event.keyCode) }
        switch capture {
        case .newKey:
            guard let chord = chordCapture.handle(event) else { return }
            stopCapturing()
            guard settings[chord] == nil else { return }
            change(ChangedKey(key: chord, packID: nil, sourceKey: chord.keyCode))
        case let .source(target):
            // Bloq Mayús «pulsa» al encenderse y «suelta» al apagarse: cualquiera de los dos la elige
            let isPress = (event.isDown || event.keyCode == KeyChord.capsLock) && !event.isRepeat
            guard isPress, var changed = settings[target] else { return }
            if event.keyCode != KeyChord.capsLock { mutedReleases.insert(event.keyCode) }
            changed.sourceKey = event.keyCode
            change(changed)
            playSample(target)
        }
    }

    //- Teclas cambiadas -

    /// Al elegir de qué pack sale una tecla cambiada: la ventana espera la tecla de ese pack. Con
    /// «Del pack», la tecla vuelve a ser la suya
    func changePack(of key: KeyChord, to packID: String?) {
        guard var changed = settings[key] else { return }
        changed.packID = packID
        if packID == nil { changed.sourceKey = key.keyCode }
        change(changed)
        if packID == nil { stopCapturing() } else { keyCapture = .source(of: key) }
        playSample(key)
    }

    func remove(_ key: KeyChord) {
        if keyCapture == .source(of: key) { stopCapturing() }
        settings.remove(key)
        save()
    }

    /// Mientras arrastras el tono o el volumen de una tecla cambiada: la ventana lo enseña, y al
    /// soltar, `tuningDidChange` lo guarda y lo hace sonar
    func tune(_ key: KeyChord, pitch: Double? = nil, volume: Double? = nil) {
        guard var changed = settings[key] else { return }
        if let pitch { changed.pitch = pitch }
        if let volume { changed.volume = volume }
        settings.change(changed)
    }

    /// Al soltar el tono o el volumen: lo guarda, rehace lo que suena y suena la tecla
    func tuningDidChange(_ key: KeyChord) {
        save()
        playSample(key)
    }

    //- Grupos de teclas -

    /// Al elegir de qué pack sale un grupo de teclas: suena una de sus teclas
    func changePack(of group: KeyGroup, to packID: String?) {
        settings[group].packID = packID
        save()
        playSample(KeyChord(group.sampleKey))
    }

    /// Como `tune` en una tecla: al soltar, `tuningDidChange` lo guarda y lo hace sonar
    func tune(_ group: KeyGroup, pitch: Double? = nil, volume: Double? = nil) {
        if let pitch { settings[group].pitch = pitch }
        if let volume { settings[group].volume = volume }
    }

    func tuningDidChange(_ group: KeyGroup) {
        save()
        playSample(KeyChord(group.sampleKey))
    }

    /// Todos los grupos y todas las teclas, otra vez como en el pack activo
    func reset() {
        stopCapturing()
        settings = KeyboardSettings()
        save()
    }

    //- Guardar -

    private func change(_ changed: ChangedKey) {
        settings.change(changed)
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key)
        settingsDidChange(settings)
    }
}
