//· KeyboardSettingsView ·
// La ventana de los ajustes del teclado: arriba, una fila por grupo de teclas, con el pack del que
// salen; debajo, una por tecla cambiada, con el pack y la tecla de ese pack que suena en ella. Cada
// fila lleva su tono y su volumen; con muchas, las filas se desplazan entre el texto y los botones.
// Las teclas se eligen pulsándolas, y lo que pulsas para elegir no suena (KeyboardSettingsEditor).
// Al soltar un ajuste suena la tecla, y mientras la ventana está abierta, el teclado suena con lo
// que pongas.

import AppKit
import SwiftUI

struct KeyboardSettingsView: View {
    @Bindable var editor: KeyboardSettingsEditor
    /// Los packs de los desplegables
    let packs: [SoundPack]
    /// Lo que miden las filas enteras: la ventana crece con ellas hasta `maxRowsHeight`
    @State private var rowsHeight: CGFloat = 0

    /// Las filas, como mucho el 60 % de la pantalla: con el texto y los botones, la ventana no pasa
    /// de unos tres cuartos. De ahí en adelante, se desplazan
    private var maxRowsHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) * 0.6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Haz que las teclas de un grupo, o una sola, suenen como las de otro pack. Vale con todos los packs, y con esta ventana abierta el teclado suena aunque lo tengas callado.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)

            rows

            HStack {
                Button { editor.capture(.newKey) } label: {
                    Group {
                        if editor.keyCapture == .newKey {
                            Label("Pulsa la tecla o el atajo que quieres cambiar…", systemImage: "keyboard")
                        } else {
                            Label("Cambiar una tecla", systemImage: "plus")
                        }
                    }
                    .textCase(.uppercase)
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 10)
                }
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .glassButton()

                Spacer()

                Button { editor.reset() } label: {
                    Text("Restablecer")
                        .textCase(.uppercase)
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 10)
                }
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .glassButton()
                .disabled(editor.settings == KeyboardSettings())
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 24)
        .frame(width: 660)
    }

    /// Los grupos y las teclas cambiadas, entre el texto y los botones, que se quedan fijos. Al
    /// cambiar una tecla nueva, baja hasta ella
    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(KeyGroup.allCases, id: \.self) { group in
                        ChangedGroupRow(editor: editor, packs: packs, group: group)
                    }

                    Divider()

                    ForEach(editor.settings.changedKeys) { changed in
                        ChangedKeyRow(editor: editor, packs: packs, changed: changed)
                    }
                }
                // Dentro del scroll, para que la barra quede en el margen y no encima de las filas
                .padding(.horizontal, 24)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowsHeight = $0 }
            }
            .frame(height: min(rowsHeight, maxRowsHeight))
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: editor.settings.changedKeys.map(\.id)) { old, new in
                guard let added = new.first(where: { !old.contains($0) }) else { return }
                withAnimation(.snappy) { proxy.scrollTo(added, anchor: .bottom) }
            }
        }
    }
}

/// Un grupo de teclas: el pack del que salen; debajo, su tono y su volumen. En «Del pack», los dos
/// ajustan lo que suena en el pack activo
private struct ChangedGroupRow: View {
    @Bindable var editor: KeyboardSettingsEditor
    let packs: [SoundPack]
    let group: KeyGroup

    private var changed: ChangedGroup { editor.settings[group] }
    private func released() { editor.tuningDidChange(group) }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text(group.title)
                    .font(.title3.bold())
                    .frame(width: rowTitleWidth, alignment: .leading)
                    // Sin texto, macOS no enseña nada
                    .help(group == .wide ? Text("Return, borrar, Tab, Mayúsculas y Bloq Mayús") : Text(verbatim: ""))
                Text(group == .space ? "suena como" : "suenan como")
                    .foregroundStyle(.secondary)
                    .linkingWords()
                Picker("Pack", selection: Binding(
                    get: { changed.packID },
                    set: { editor.changePack(of: group, to: $0) }
                )) {
                    Text("Del pack").tag(String?.none)
                    Divider()
                    ForEach(packs) { Text($0.name).tag(String?.some($0.id)) }
                }
                .labelsHidden()
                .frame(width: 170)
                Spacer()
            }
            HStack(spacing: 24) {
                SettingSlider.pitch(changed.pitch, set: { editor.tune(group, pitch: $0) }, released: released)
                SettingSlider.volume(changed.volume, set: { editor.tune(group, volume: $0) }, released: released)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 12))
    }
}

/// Lo que ocupa el nombre de un grupo o de una tecla, a la izquierda de cada fila: el mismo en
/// todas, para que los desplegables queden en columna
private let rowTitleWidth: CGFloat = 130

private extension View {
    /// «suena como» entre el nombre y el pack: en una línea, aunque falte sitio, y con el mismo
    /// ancho en singular y en plural
    func linkingWords() -> some View {
        fixedSize().frame(minWidth: 90, alignment: .leading)
    }
}

private extension KeyGroup {
    var title: LocalizedStringKey {
        switch self {
        case .normal: "Teclas normales"
        case .space: "Espacio"
        case .wide: "Teclas anchas"
        }
    }
}

/// Una tecla cambiada: la tecla, el pack del que sale su sonido y la tecla de ese pack; debajo,
/// su tono y su volumen. En «Del pack», los dos ajustan lo que suena en ella con su grupo
private struct ChangedKeyRow: View {
    @Bindable var editor: KeyboardSettingsEditor
    let packs: [SoundPack]
    let changed: ChangedKey

    private var isCapturingSource: Bool { editor.keyCapture == .source(of: changed.key) }
    private func released() { editor.tuningDidChange(changed.key) }

    var body: some View {
        VStack(spacing: 14) {
            choice
            HStack(spacing: 24) {
                SettingSlider.pitch(changed.pitch, set: { editor.tune(changed.key, pitch: $0) }, released: released)
                SettingSlider.volume(changed.volume, set: { editor.tune(changed.key, volume: $0) }, released: released)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(isCapturingSource ? 0.12 : 0.06), in: .rect(cornerRadius: 12))
    }

    /// La tecla, el pack y la tecla de ese pack
    private var choice: some View {
        HStack(spacing: 12) {
            Text(verbatim: KeyName.of(changed.key))
                .font(.title3.bold())
                .frame(width: rowTitleWidth, alignment: .leading)
            Text("suena como")
                .foregroundStyle(.secondary)
                .linkingWords()
            Picker("Pack", selection: Binding(
                get: { changed.packID },
                set: { editor.changePack(of: changed.key, to: $0) }
            )) {
                Text("Del pack").tag(String?.none)
                Divider()
                ForEach(packs) { Text($0.name).tag(String?.some($0.id)) }
            }
            .labelsHidden()
            .frame(width: 170)
            Button { editor.capture(.source(of: changed.key)) } label: {
                Group {
                    if isCapturingSource {
                        Text("Pulsa una tecla…")
                    } else {
                        Text(verbatim: KeyName.of(changed.sourceKey))
                    }
                }
                .textCase(.uppercase)
                .frame(minWidth: 90)
            }
            .buttonBorderShape(.capsule)
            .glassButton()
            .help(Text("Pulsa teclas del pack hasta dar con la que te guste"))
            .disabled(changed.packID == nil)
            Spacer()
            Button { editor.remove(changed.key) } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help(Text("Quitar"))
            .accessibilityLabel(Text("Quitar"))
        }
    }
}

//- Ventana -

@MainActor
final class KeyboardSettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private weak var editor: KeyboardSettingsEditor?
    private var onClose: (() -> Void)?
    private var keyMonitor: Any?

    /// `onClose` llega al cerrarla, con su botón o con `close()`
    func show(editor: KeyboardSettingsEditor, packs: [SoundPack], onClose: @escaping () -> Void) {
        if window == nil {
            self.editor = editor
            self.onClose = onClose
            let view = KeyboardSettingsView(editor: editor, packs: packs)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = String(localized: "Ajustes del teclado")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
            // Las teclas se eligen pulsándolas (las oye el tap, y las elige KeyboardSettingsEditor): en
            // la ventana no hacen nada, ni siquiera ⌘W, para poder elegir cualquiera
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak window] event in
                event.window === window ? nil : event
            }
        }
        // Tics vive en la barra de menús: sin activarla, la ventana se queda detrás de la app de delante
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Si está abierta, como si se cerrara con su botón
    func close() {
        window?.close()
    }

    func windowDidResignKey(_ notification: Notification) {
        editor?.stopCapturing()
    }

    func windowWillClose(_ notification: Notification) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        window = nil
        onClose?()
    }
}
