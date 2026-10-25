//· MouseSettingsEditor ·
// Los ajustes del ratón y su edición: el tono, el volumen y el timbre de cada sonido del ratón, y la
// vibración de los botones. Mientras arrastras un ajuste solo cambia lo que ves; al soltarlo se
// guarda, se avisa al audio y suena la muestra. Funciona como KeyboardSettingsEditor.

import Foundation
import Observation

@MainActor @Observable
final class MouseSettingsEditor {
    private(set) var settings: MouseSettings

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let playSampleOf: @MainActor (MouseSound) -> Void
    @ObservationIgnored private let vibrate: @MainActor (Vibration) -> Void
    @ObservationIgnored private let settingsDidChange: @MainActor (MouseSettings) -> Void

    private static let key = "mouseSettings"

    /// `playSample` hace sonar una muestra de un sonido; `vibrate`, que el ratón haga un efecto; y
    /// `settingsDidChange` llega con cada cambio guardado, para el audio y la conexión con el ratón
    init(
        defaults: UserDefaults,
        playSample: @escaping @MainActor (MouseSound) -> Void,
        vibrate: @escaping @MainActor (Vibration) -> Void,
        settingsDidChange: @escaping @MainActor (MouseSettings) -> Void
    ) {
        self.defaults = defaults
        playSampleOf = playSample
        self.vibrate = vibrate
        self.settingsDidChange = settingsDidChange
        settings = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(MouseSettings.self, from: $0) } ?? MouseSettings()
    }

    /// Mientras arrastras el tono, el volumen o el timbre: la ventana lo enseña, y al soltar,
    /// `tuningDidChange` lo guarda y lo hace sonar
    func tune(_ sound: MouseSound, pitch: Double? = nil, volume: Double? = nil, timbre: Double? = nil) {
        if let pitch { settings[sound].pitch = pitch }
        if let volume { settings[sound].volume = volume }
        if let timbre { settings[sound].timbre = timbre }
    }

    /// Al soltar un ajuste: lo guarda, rehace los clics y suena la muestra de ese sonido
    func tuningDidChange(_ sound: MouseSound) {
        save()
        playSampleOf(sound)
    }

    /// Solo la muestra, sin cambiar nada
    func playSample(_ sound: MouseSound) {
        playSampleOf(sound)
    }

    /// Al elegir la vibración de un botón: la guarda y el ratón hace el efecto una vez
    func changeVibration(of sound: MouseSound, to vibration: Vibration) {
        settings[sound].vibration = vibration
        save()
        if vibration != .none { vibrate(vibration) }
    }

    /// Todo como suena de serie, y sin vibración
    func reset() {
        settings = MouseSettings()
        save()
        playSampleOf(.left)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key)
        settingsDidChange(settings)
    }
}
