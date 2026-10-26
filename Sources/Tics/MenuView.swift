//· MenuView ·
// El panel que se abre desde el icono de la barra de menús, por módulos como el Centro de control:
// el icono, el nombre y la versión (que abren «Acerca de TICS»), una fila con las fichas del
// teclado, el ratón, la rueda y, con un ratón Logitech conectado, sus botones desviados, el pack en
// un desplegable con el volumen debajo, abrir al iniciar sesión y buscar actualizaciones (con la
// versión nueva debajo, si la hay), una fila de iconos y la firma.
// Se eligió entre cuatro versiones; las otras están en la rama prototype/panel.
// Al abrirlo, los bloques entran uno tras otro; las fichas y los botones se hunden al pulsarlos.

import SwiftUI

struct MenuView: View {
    @Bindable var state: AppState
    /// Si los bloques ya han entrado: se pone a true al abrir el panel y vuelve a false al cerrarlo
    @State private var isShown = false

    var body: some View {
        VStack(spacing: 10) {
            Header()
                .entrance(isShown, order: 0)

            // Callada, tenues y quietas: siguen como estaban, pero ahora no suenan
            SoundToggles(state: state)
                .opacity(state.isMuted ? 0.4 : 1)
                .disabled(state.isMuted)
                .entrance(isShown, order: 1)

            Module {
                VStack(spacing: 12) {
                    PackMenu(state: state)
                    // Callar y bajar, delante de la barra. Se apagan volviendo a pulsarlos, y no se
                    // desactivan con la barra: si no, callada ya no se podría quitar
                    HStack(spacing: 8) {
                        VolumeButton(icon: "speaker.slash.fill", label: "Callar TICS", isOn: state.isMuted) {
                            state.isMuted.toggle()
                        }
                        VolumeButton(icon: "speaker.minus.fill", label: "Más bajo", isOn: state.isManuallyLowered) {
                            state.isManuallyLowered.toggle()
                        }
                        // El tirador es el volumen elegido; el relleno y las ondas, lo que suena,
                        // que más bajo es menos. Cambian con el mismo fundido que el sonido
                        CapsuleSlider(value: $state.volume, sounding: state.soundingVolume)
                            .padding(.leading, 2)
                            .disabled(!state.isSounding)
                        Image(systemName: "speaker.wave.3.fill", variableValue: state.soundingVolume)
                            .foregroundStyle(.secondary)
                            .opacity(state.isSounding ? 1 : 0.4)
                    }
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.3), value: state.isLowered)
                    if state.canLowerWithOtherAudio {
                        LowerWithOtherAudio(state: state)
                    }
                }
            }
            .entrance(isShown, order: 2)

            if state.usesInputMonitoring && state.permission != .granted {
                PermissionNotice(state: state)
                    .entrance(isShown, order: 3)
            }

            if state.usesLogitech && state.bluetoothPermission == .denied {
                BluetoothNotice(state: state)
                    .entrance(isShown, order: 3)
            }

            Module {
                // El switch a la derecha, como en Ajustes: un Toggle de macOS lo pega al texto
                VStack(spacing: 12) {
                    HStack {
                        Text("Abrir al iniciar sesión").font(.title3)
                        Spacer()
                        Toggle("Abrir al iniciar sesión", isOn: Binding(
                            get: { state.launchAtLogin },
                            set: { state.setLaunchAtLogin($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    HStack {
                        Text("Buscar actualizaciones").font(.title3)
                        Spacer()
                        Toggle("Buscar actualizaciones", isOn: $state.checksForUpdates)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    // Debajo de lo que la enciende: al apagarlo, se va con él
                    if let version = state.newVersion {
                        UpdateRow(version: version) { state.downloadUpdate() }
                    }
                }
            }
            .entrance(isShown, order: 4)

            Module {
                // El título arriba, como el de «Sonidos»: al lado no caben los cuatro
                VStack(alignment: .leading, spacing: 10) {
                    Text("Icono de la barra").font(.title3).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(MenuBarIcon.allCases, id: \.self) { icon in
                            IconChoice(icon: icon, isSelected: icon == state.menuBarIcon) {
                                withAnimation(.snappy) { state.menuBarIcon = icon }
                            }
                        }
                    }
                }
            }
            .entrance(isShown, order: 5)

            Module {
                // Con dos idiomas, botones de radio en la misma fila, sin título: ya lo dicen sus
                // nombres. Elegir el otro reinicia TICS
                HStack(spacing: 32) {
                    ForEach(Language.allCases, id: \.self) { language in
                        LanguageRadio(language: language, isSelected: language == Language.current) {
                            state.setLanguage(language)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Idioma"))
            }
            .entrance(isShown, order: 6)

            HStack(spacing: 10) {
                ModuleButton(icon: "keyboard", label: "Configurar teclado…") {
                    closePanel()
                    state.openKeyboardSettings()
                }
                ModuleButton(icon: "computermouse", label: "Configurar ratón…") {
                    closePanel()
                    state.openMouseSettings()
                }
                ModuleButton(icon: "power", label: "Salir") { NSApp.terminate(nil) }
            }
            .entrance(isShown, order: 7)

            Signature()
                .entrance(isShown, order: 8)
        }
        .padding(20)
        .frame(width: 340)
        .fontDesign(.rounded)
        .panelWindow(cornerRadius: 26) { isVisible in
            if isVisible {
                state.panelDidOpen()
                isShown = true
            } else {
                // Sin animación: los bloques quedan escondidos para la próxima vez
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { isShown = false }
            }
        }
    }
}

/// Al abrir otra ventana, el panel se cierra, como los menús de la barra. Se cierra pulsando su
/// icono: cerrando la ventana sin más, MenuBarExtra se queda creyendo que sigue abierta y el
/// siguiente clic en el icono no hace nada
@MainActor
private func closePanel() {
    let icon = NSApp.windows.lazy.compactMap { $0.contentView.flatMap(statusButton) }.first
    if let icon, let window = icon.window {
        // MenuBarExtra no escucha la acción del botón sino el ratón: se le manda un clic, pulsar y
        // soltar. El soltar va a la cola antes, porque al pulsar el botón se queda esperándolo
        let point = icon.convert(NSPoint(x: icon.bounds.midX, y: icon.bounds.midY), to: nil)
        func click(_ type: NSEvent.EventType) -> NSEvent? {
            NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            )
        }
        DispatchQueue.main.async {
            guard let down = click(.leftMouseDown), let up = click(.leftMouseUp) else { return }
            NSApp.postEvent(up, atStart: false)
            window.sendEvent(down)
        }
    } else {
        NSApp.keyWindow?.close()
    }
}

/// El botón del icono en la barra de menús, dentro de la ventanita que macOS le pone
@MainActor
private func statusButton(in view: NSView) -> NSStatusBarButton? {
    (view as? NSStatusBarButton) ?? view.subviews.lazy.compactMap(statusButton).first
}

//- Animaciones -

private extension View {
    /// Entra con un fundido, subiendo unos puntos, un poco después del bloque anterior
    func entrance(_ isShown: Bool, order: Int) -> some View {
        modifier(Entrance(isShown: isShown, order: order))
    }
}

private struct Entrance: ViewModifier {
    let isShown: Bool
    let order: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        // La animación va solo a la opacidad y al desplazamiento. Con .animation(_:value:) se
        // animaba también la primera colocación de la ventana, y los bloques llegaban volando
        // desde fuera la primera vez que se abría el panel
        content.animation(.spring(duration: 0.45, bounce: 0.25).delay(Double(order) * 0.035)) { block in
            block
                .opacity(isShown || reduceMotion ? 1 : 0)
                .offset(y: isShown || reduceMotion ? 0 : 10)
        }
    }
}

/// Se hunde un poco al pulsarlo, como una tecla
private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

//- Cabecera -

/// El icono de la app, su nombre y su versión. Al pulsarla se abre «Acerca de TICS». Quién la
/// hace va abajo, en la firma
private struct Header: View {
    private static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    var body: some View {
        Button {
            closePanel()
            About.show()
        } label: {
            HStack(spacing: 8) {
                // El icono trae su margen transparente: a 56 puntos, el cuadrado se ve de unos 45
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                // La versión, sobre la misma línea que el nombre
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "TICS").font(.largeTitle.bold())
                    if let version = Self.version {
                        Text(version)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressStyle())
        .help("Acerca de TICS")
        .accessibilityLabel("Acerca de TICS")
        .padding(.leading, -2)
        .padding(.bottom, 2)
    }
}

/// La firma de todas las apps de yestoall: «diseñado con ♥ por», con el corazón en el rojo de
/// las demás (#F22). Lleva a la web
private struct Signature: View {
    private static let website = URL(string: "https://yestoall.com")!

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Cada latido sube en uno, y eso dispara la animación del corazón
    @State private var beats = 0
    @State private var beating: Task<Void, Never>?

    var body: some View {
        Link(destination: Self.website) {
            HStack(spacing: 4) {
                Text("diseñado con")
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color(red: 1, green: 0.13, blue: 0.13))
                    // Un latido: dos golpes, el segundo más flojo
                    .phaseAnimator([1.0, 1.3, 1.0, 1.18, 1.0], trigger: beats) { heart, scale in
                        heart.scaleEffect(scale)
                    } animation: { _ in .easeInOut(duration: 0.11) }
                Text("por")
                Text(verbatim: "@yestoall")
            }
            .tracking(0.3)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .onHover { isHovered in
            beating?.cancel()
            guard isHovered, !reduceMotion else { return }
            // Late mientras el puntero está encima, uno cada 0,9 s
            beating = Task {
                while !Task.isCancelled {
                    beats += 1
                    try? await Task.sleep(for: .milliseconds(900))
                }
            }
        }
        .onDisappear { beating?.cancel() }
    }
}

//- Módulos -

/// Una caja del panel, con el fondo y las esquinas de todas
private struct Module<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 20))
    }
}

/// Las fichas de cada sonido, en una fila. La de Logitech solo sale con un ratón Logitech conectado
private struct SoundToggles: View {
    @Bindable var state: AppState

    var body: some View {
        let keyboard = ModuleToggle(icon: "keyboard.fill", title: "Teclado", isOn: $state.isEnabled)
        let mouse = ModuleToggle(icon: "pointer.arrow.motionlines", title: "Ratón", isOn: $state.isMouseEnabled)
        let scroll = ModuleToggle(icon: "scroll.fill", title: "Scroll", isOn: $state.isScrollEnabled)
        HStack(spacing: 10) {
            keyboard
            mouse
            scroll
            if state.hasLogitechMouse {
                ModuleToggle(icon: "computermouse.fill", title: "Logitech", isOn: $state.isLogitechEnabled)
            }
        }
    }
}

/// Una ficha que enciende o apaga un sonido: toda la ficha es el botón. Si suena lo dice el
/// círculo, en azul: con cuatro en una fila no cabe escribirlo
private struct ModuleToggle: View {
    let icon: String
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    private var status: LocalizedStringKey { isOn ? "Suena" : "Callado" }

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .symbolEffect(.bounce, value: isOn)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(isOn ? .white : .primary)
                    .background(isOn ? Color.accentColor : Color.primary.opacity(0.1), in: Circle())
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(status))
    }
}

/// Un botón de radio de idioma, dibujado: los de macOS no crecen con `controlSize` y a su lado se
/// quedan pequeños. Como los de serie, azul con el punto blanco el elegido
private struct LanguageRadio: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.1))
                    Circle()
                        .strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
                    if isSelected {
                        Circle().fill(.white).frame(width: 8, height: 8)
                    }
                }
                .frame(width: 20, height: 20)
                Text(verbatim: language.name).font(.title3)
            }
            .contentShape(.rect)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(Text(verbatim: language.name))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Uno de los iconos que puede llevar TICS en la barra, en un círculo como los de las fichas.
/// El elegido va en azul
private struct IconChoice: View {
    let icon: MenuBarIcon
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon.symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .help(Text(verbatim: icon.name))
        .accessibilityLabel(Text(verbatim: icon.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Un botón de la fila de abajo: solo el icono, con su nombre al dejar el puntero encima
private struct ModuleButton: View {
    let icon: String
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 16))
                .contentShape(.rect)
        }
        .buttonStyle(PressStyle())
        .help(Text(label))
        .accessibilityLabel(Text(label))
    }
}

/// Los botones de callar y bajar, junto a la barra del volumen: un círculo como el de las fichas,
/// en el color de realce mientras están encendidos
private struct VolumeButton: View {
    let icon: String
    let label: LocalizedStringKey
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: icon)
                .font(.callout)
                .symbolEffect(.bounce, value: isOn)
                .frame(width: 32, height: 32)
                .foregroundStyle(isOn ? .white : .primary)
                .background(isOn ? Color.accentColor : Color.primary.opacity(0.1), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .help(Text(label))
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

//- Pack -

/// El pack que suena y, al pulsarlo, la lista para cambiarlo
private struct PackMenu: View {
    let state: AppState

    private var current: SoundPack? { state.packs.first { $0.id == state.selectedPackID } }

    var body: some View {
        Menu {
            ForEach(state.packs) { item($0) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sonidos").font(.title3).foregroundStyle(.secondary)
                    // Al cambiar de pack, el nombre nuevo entra desde abajo
                    Text(current?.name ?? "—")
                        .font(.title2.bold())
                        .id(current?.id)
                        .transition(.push(from: .bottom))
                }
                .clipped()
                .animation(.snappy, value: current?.id)
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.title3).foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }

    private func item(_ pack: SoundPack) -> some View {
        Button { state.selectPack(pack) } label: {
            if pack.id == state.selectedPackID {
                Label(pack.name, systemImage: "checkmark")
            } else {
                Text(pack.name)
            }
        }
    }
}

//- Aviso del permiso -

struct PermissionNotice: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if state.permission == .needsRelaunch {
                Text("Ya tienes el permiso. Reinicia TICS para que empiece a sonar.")
                Button("Reiniciar TICS") { state.relaunch() }
            } else {
                Text("Para oír tus teclas y tus clics, activa TICS en Monitorización de los dispositivos de entrada.")
                Text("TICS solo mira qué pulsas y cómo arrastras, para elegir el sonido. No guarda nada de lo que escribes ni dónde haces clic.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Abrir Ajustes") { state.requestPermission() }
            }
        }
        .notice()
    }
}

/// Si se denegó el permiso de Bluetooth: macOS ya no vuelve a preguntar, hay que darlo en Ajustes
private struct BluetoothNotice: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Para oír los botones que se queda Logi Options+, activa TICS en Bluetooth.")
            Text("TICS solo escucha cuándo pulsas y sueltas esos botones. No cambia nada de tu ratón.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Abrir Ajustes") { state.openBluetoothSettings() }
        }
        .notice()
    }
}

//- Más bajo con otro audio -

/// El interruptor, debajo del volumen, y mientras está más bajo, por qué apps: así se ve de dónde
/// sale una falsa alarma
private struct LowerWithOtherAudio: View {
    @Bindable var state: AppState

    /// «Dia», «Dia y Música»…, en el idioma de la app
    private var apps: String { state.loweredBy.formatted(.list(type: .and)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Más bajo con otro audio").font(.title3)
                Spacer()
                Toggle("Más bajo con otro audio", isOn: $state.lowersWithOtherAudio)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            if !state.loweredBy.isEmpty {
                Text("Ahora más bajo por \(apps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

//- Aviso de versión nueva -

/// Cuando GitHub tiene una versión más nueva que la instalada, en el bloque de buscar
/// actualizaciones. Lo que hay de nuevo lo cuenta la release; aquí solo el número y la descarga
private struct UpdateRow: View {
    let version: AppVersion
    let download: () -> Void

    var body: some View {
        HStack {
            Text("Ya está TICS \(version.description)").font(.title3)
            Spacer()
            Button(action: download) {
                Text("Descargar").textCase(.uppercase)
            }
            // Destacado, en el color de realce como las fichas encendidas y el volumen
            .buttonStyle(.borderedProminent)
        }
    }
}

private extension View {
    /// La caja naranja de los avisos de permisos
    func notice() -> some View {
        font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12), in: .rect(cornerRadius: 14))
    }
}
