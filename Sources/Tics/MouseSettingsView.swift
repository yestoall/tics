//· MouseSettingsView ·
// La ventana de los ajustes del ratón: una ficha por sonido del ratón, con su tono, su volumen y
// su timbre. Al soltar un ajuste suena una muestra de ese sonido, y mientras la ventana está
// abierta todo el ratón suena con lo que pongas (ListeningPlan). La ficha de los botones desviados
// solo sale con un ratón Logitech conectado, y la vibración de los botones, con uno que vibre.

import AppKit
import SwiftUI

struct MouseSettingsView: View {
    @Bindable var editor: MouseSettingsEditor
    /// Solo para saber qué ratón hay: si es un Logitech y si vibra
    let state: AppState

    private var sounds: [MouseSound] {
        MouseSound.allCases.filter { $0 != .diverted || state.hasLogitechMouse }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Al soltar un ajuste suena una muestra. Con esta ventana abierta, el ratón suena con lo que pongas.")
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                ForEach(sounds, id: \.self) { sound in
                    SoundCard(editor: editor, showsVibration: state.hasVibratingMouse, sound: sound)
                }
            }

            Button { editor.reset() } label: {
                Text("Restablecer")
                    .textCase(.uppercase)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 10)
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .glassButton()
        }
        .padding(24)
        .frame(width: 1000)
    }
}

/// Un sonido: su nombre, que al pulsarlo suena la muestra, y sus tres ajustes
private struct SoundCard: View {
    @Bindable var editor: MouseSettingsEditor
    /// Con un ratón que vibra
    let showsVibration: Bool
    let sound: MouseSound

    private var settings: SoundSettings { editor.settings[sound] }
    private func changed() { editor.tuningDidChange(sound) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button { editor.playSample(sound) } label: { Text(sound.title).font(.title3.bold()) }
                .buttonStyle(.plain)
                .help(Text("Oír la muestra"))
            SettingSlider.pitch(settings.pitch, set: { editor.tune(sound, pitch: $0) }, released: changed)
            SettingSlider.volume(settings.volume, set: { editor.tune(sound, volume: $0) }, released: changed)
            SettingSlider(
                title: "Timbre", low: Text("seco"), high: Text("hueco"),
                value: Binding(get: { settings.timbre }, set: { editor.tune(sound, timbre: $0) }),
                range: SoundSettings.timbreRange,
                shown: Text(verbatim: settings.timbre.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))),
                released: changed
            )
            if showsVibration {
                // Al elegir un efecto, el ratón lo hace una vez. El arrastre y la rueda no vibran,
                // pero guardan su hueco: así todas las fichas miden lo mismo
                let vibrates = sound.button != nil
                Picker("Vibración", selection: Binding(
                    get: { settings.vibration },
                    set: { editor.changeVibration(of: sound, to: $0) }
                )) {
                    ForEach(Vibration.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .font(.callout)
                .disabled(!vibrates)
                .opacity(vibrates ? 1 : 0)
                .accessibilityHidden(!vibrates)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 16))
    }
}

//- Ventana -

@MainActor
final class MouseSettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onClose: (() -> Void)?

    /// `onClose` llega al cerrarla, con su botón o con `close()`
    func show(editor: MouseSettingsEditor, state: AppState, onClose: @escaping () -> Void) {
        if window == nil {
            self.onClose = onClose
            let view = MouseSettingsView(editor: editor, state: state)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "Ajustes del ratón")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        // Tics vive en la barra de menús: sin activarla, la ventana se queda detrás de la app de delante
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Si está abierta, como si se cerrara con su botón
    func close() {
        window?.close()
    }

    /// Si el puntero está sobre la ventana: ahí, tocar un ajuste no debe sonar como un clic
    var containsPointer: Bool {
        window?.frame.contains(NSEvent.mouseLocation) ?? false
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        onClose?()
    }
}
