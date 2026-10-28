//· KeyboardSettingsView ·
// La ventana de los ajustes del teclado: arriba, una fila por grupo de teclas, con el pack del que
// salen; debajo, una por tecla cambiada, con el pack y la tecla de ese pack que suena en ella, o un
// sonido propio: «Fichero…» en el desplegable, o soltar un fichero de audio en la fila. Cada
// fila lleva su tono y su volumen; con muchas, las filas se desplazan entre el texto y los botones.
// Las teclas se eligen pulsándolas, y lo que pulsas para elegir no suena (KeyboardSettingsEditor).
// Al soltar un ajuste suena la tecla, y mientras la ventana está abierta, el teclado suena con lo
// que pongas.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
            HStack(spacing: 12) {
                AppIcon()
                Text("Haz que las teclas de un grupo, o una sola, suenen como las de otro pack. Vale con todos los packs, y con esta ventana abierta el teclado suena aunque lo tengas callado.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            VariesPitchRow(editor: editor)
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

/// Variar el tono de cada pulsación: vale para todas las teclas, así que va encima de los grupos
private struct VariesPitchRow: View {
    @Bindable var editor: KeyboardSettingsEditor

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Variar el tono").font(.title3.bold())
                Text("Cada tecla suena un poco distinta cada vez, como en un teclado de verdad.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("Variar el tono", isOn: Binding(
                get: { editor.settings.variesPitch },
                set: { editor.setVariesPitch($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .sectionPadding()
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 12))
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
            HStack(alignment: .packPicker, spacing: 12) {
                Text(group.title)
                    .font(.title3.bold())
                    // Sin texto, macOS no enseña nada
                    .help(group == .wide ? Text("Borrar, Tab, Mayúsculas y Bloq Mayús") : Text(verbatim: ""))
                Spacer()
                SoundPicker(
                    packID: Binding(get: { changed.packID }, set: { editor.changePack(of: group, to: $0) }),
                    packs: packs
                )
            }
            HStack(spacing: 24) {
                SettingSlider.pitch(changed.pitch, set: { editor.tune(group, pitch: $0) }, released: released)
                SettingSlider.volume(changed.volume, set: { editor.tune(group, volume: $0) }, released: released)
            }
        }
        .sectionPadding()
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 12))
    }
}

/// Una tecla cambiada, dibujada como una tecla: así se distingue de los grupos y del texto de la fila
private struct KeyCap: View {
    let name: String

    var body: some View {
        Text(verbatim: name)
            .font(.title3.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(minWidth: 44)
            .background(Color.primary.opacity(0.14), in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.28)))
            // El canto de abajo, como el de una tecla de verdad
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.2)).offset(y: 2))
    }
}

/// El pack del que sale el sonido, con «Sonido» debajo
private struct SoundPicker: View {
    @Binding var packID: String?
    let packs: [SoundPack]
    /// En las teclas cambiadas: su sonido propio, si lo tiene, y qué hacer al elegir «Fichero…».
    /// Los grupos no tienen
    var customSound: CustomSound?
    var chooseFile: (() -> Void)?

    private enum Choice: Hashable {
        case pack(String?)
        case custom
        case file
    }

    private var choice: Binding<Choice> {
        Binding(
            get: { customSound == nil ? .pack(packID) : .custom },
            set: { choice in
                switch choice {
                case let .pack(id): packID = id
                case .file: chooseFile?()
                case .custom: break
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Picker("Pack", selection: choice) {
                Text("Del pack").tag(Choice.pack(nil))
                Divider()
                ForEach(packs) { Text($0.name).tag(Choice.pack($0.id)) }
                if chooseFile != nil {
                    Divider()
                    if let customSound { Text(verbatim: customSound.name).tag(Choice.custom) }
                    Text("Fichero…").tag(Choice.file)
                }
            }
            .labelsHidden()
            // El resto de la fila se centra con el desplegable, no con el texto de debajo
            .alignmentGuide(.packPicker) { $0[VerticalAlignment.center] }
            Text("Sonido")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 170)
    }
}

extension VerticalAlignment {
    /// El centro del desplegable del pack, en cada fila
    private enum PackPicker: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[VerticalAlignment.center] }
    }

    fileprivate static let packPicker = VerticalAlignment(PackPicker.self)
}

private extension View {
    /// El aire de cada sección, de los grupos y de las teclas. Arriba, algo menos que abajo
    func sectionPadding() -> some View {
        padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 16)
    }
}

private extension KeyGroup {
    var title: LocalizedStringKey {
        switch self {
        case .normal: "Teclas normales"
        case .space: "Espacio"
        case .enter: "Return"
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

    /// Con un fichero de audio encima, la fila se resalta
    @State private var isDropTarget = false

    private var isCapturingSource: Bool { editor.keyCapture == .source(of: changed.key) }
    private func released() { editor.tuningDidChange(changed.key) }

    var body: some View {
        VStack(spacing: 14) {
            choice
            notice
            HStack(spacing: 24) {
                SettingSlider.pitch(changed.pitch, set: { editor.tune(changed.key, pitch: $0) }, released: released)
                SettingSlider.volume(changed.volume, set: { editor.tune(changed.key, volume: $0) }, released: released)
            }
        }
        .sectionPadding()
        .background(
            Color.primary.opacity(isCapturingSource || isDropTarget ? 0.12 : 0.06), in: .rect(cornerRadius: 12)
        )
        .overlay {
            if isDropTarget { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 2) }
        }
        .onDrop(of: [.fileURL], delegate: AudioFileDrop(isTargeted: $isDropTarget) { url in
            editor.setCustomSound(of: changed.key, from: url)
        })
    }

    /// Lo que se torció con el sonido propio, si algo
    @ViewBuilder private var notice: some View {
        if let file = editor.unreadableFiles[changed.key] {
            Text("No se puede leer «\(file)» como audio")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let sound = changed.customSound, editor.missingCopies.contains(sound) {
            Text("No está el fichero «\(sound.name)»: suena como en el pack")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// El selector de ficheros de audio del disco
    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = String(localized: "Elegir")
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            editor.setCustomSound(of: changed.key, from: url)
        }
    }

    /// La tecla y su papelera, a la izquierda; a la derecha, el pack y la tecla de ese pack. Así el
    /// desplegable queda en la misma columna que el de los grupos
    private var choice: some View {
        HStack(alignment: .packPicker, spacing: 12) {
            KeyCap(name: KeyName.of(changed.key))
            Button { editor.remove(changed.key) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(Text("Quitar"))
            .accessibilityLabel(Text("Quitar"))
            Spacer()
            // La tecla de ese pack que suena en esta. Solo con un pack elegido: con «Del pack» es la
            // suya, y el botón sería un duplicado
            if changed.packID != nil {
                Text("con")
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Button { editor.capture(.source(of: changed.key)) } label: {
                    Group {
                        if isCapturingSource {
                            Text("Pulsa una tecla…")
                        } else {
                            Text(verbatim: KeyName.of(changed.sourceKey))
                        }
                    }
                    .textCase(.uppercase)
                    .frame(minWidth: 70)
                }
                .buttonBorderShape(.capsule)
                .glassButton()
                .help(Text("Pulsa teclas del pack hasta dar con la que te guste"))
            }
            SoundPicker(
                packID: Binding(get: { changed.packID }, set: { editor.changePack(of: changed.key, to: $0) }),
                packs: packs,
                customSound: changed.customSound,
                chooseFile: chooseFile
            )
        }
    }
}

/// Soltar un fichero de audio en una fila. El Finder no dice de qué tipo es lo que arrastras, solo
/// que es un fichero: se mira su extensión al entrar, y la fila solo se resalta y lo coge si es audio
private struct AudioFileDrop: DropDelegate {
    @Binding var isTargeted: Bool
    let drop: @MainActor (URL) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        let isTargeted = $isTargeted
        audioFile(in: info) { isTargeted.wrappedValue = $0 != nil }
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        guard isTargeted else { return false }
        isTargeted = false
        let drop = drop
        audioFile(in: info) { url in
            if let url { drop(url) }
        }
        return true
    }

    /// El fichero que arrastras, si es audio. Llega después: el Finder lo da por detrás
    private func audioFile(in info: DropInfo, then: @escaping @MainActor @Sendable (URL?) -> Void) {
        guard let provider = info.itemProviders(for: [.fileURL]).first else { return then(nil) }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            let isAudio = url.flatMap { UTType(filenameExtension: $0.pathExtension) }?.conforms(to: .audio) ?? false
            Task { @MainActor in then(isAudio ? url : nil) }
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
            // TICS no sale en la barra de menús de macOS: que lo diga la ventana, y qué cambia
            window.title = "TICS"
            window.subtitle = String(localized: "Sonidos del teclado")
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
