//· AppState ·
// El estado de la app y lo que la une: ajustes guardados, permisos, teclado, ratón, los botones
// desviados de los ratones Logitech, audio y los ajustes del ratón. Los del teclado los edita
// KeyboardSettingsEditor; aquí se conecta con el audio y con su ventana.
// La interfaz lee y cambia todo a través de aquí.

import AppKit
import CoreGraphics
import Observation
import ServiceManagement
import os

@MainActor @Observable
final class AppState {
    enum Permission {
        case missing
        case granted
        /// macOS ya dio el permiso, pero el tap no arranca hasta reabrir la app
        case needsRelaunch
    }

    static let defaultPackID = SoundPackLibrary.oreoID

    private(set) var packs: [SoundPack] = []
    private(set) var permission: Permission = .missing
    private(set) var selectedPackID: String
    private(set) var launchAtLogin: Bool
    /// La ventana de ajustes abierta, si hay una: cambia lo que se escucha (ver ListeningPlan)
    private var openSettings: ListeningPlan.SettingsWindow?

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            updateMonitors()
        }
    }

    /// Los clics y los arrastres del ratón
    var isMouseEnabled: Bool {
        didSet {
            defaults.set(isMouseEnabled, forKey: Keys.mouseEnabled)
            updateMonitors()
        }
    }

    /// La rueda del ratón, aparte de los clics
    var isScrollEnabled: Bool {
        didSet {
            defaults.set(isScrollEnabled, forKey: Keys.scrollEnabled)
            updateMonitors()
        }
    }

    /// Los botones desviados de un ratón Logitech, que llegan por Bluetooth. Sale
    /// apagada: encenderla la primera vez es lo que pide el permiso de Bluetooth
    var isLogitechEnabled: Bool {
        didSet {
            defaults.set(isLogitechEnabled, forKey: Keys.logitechEnabled)
            updateMonitors()
        }
    }

    /// Si hay un ratón Logitech conectado por Bluetooth: sin él, su ficha no sale
    private(set) var hasLogitechMouse = false
    /// Si ese ratón vibra (el MX Master 4): sin él, los ajustes no enseñan la vibración
    private(set) var hasVibratingMouse = false
    private(set) var bluetoothPermission = LogitechMonitor.permission

    /// El icono de la barra de menús
    var menuBarIcon: MenuBarIcon {
        didSet { defaults.set(menuBarIcon.rawValue, forKey: Keys.menuBarIcon) }
    }

    /// Si mira en GitHub, una vez al día, si hay versión nueva. Al apagarlo se olvida la que viera
    var checksForUpdates: Bool {
        didSet {
            defaults.set(checksForUpdates, forKey: Keys.checksForUpdates)
            updateChecks()
        }
    }

    /// La versión de GitHub, si es más nueva que la instalada: el panel la avisa y el icono lleva un punto
    private(set) var newVersion: AppVersion?

    /// Si TICS baja mientras otra app tiene abierta la salida de audio (música, un vídeo…)
    var lowersWithOtherAudio: Bool {
        didSet {
            defaults.set(lowersWithOtherAudio, forKey: Keys.lowersWithOtherAudio)
            updateOtherAudio()
        }
    }

    /// Las apps por las que TICS suena más bajo ahora: el panel las nombra, para ver de dónde sale
    /// una falsa alarma (una app que deja la salida abierta en silencio)
    private(set) var loweredBy: [String] = []

    /// Más bajo a mano, con el botón del panel: lo mismo que con otro audio, hasta volver a pulsarlo.
    /// No se guarda: al reabrir TICS, vuelve a su volumen
    private var isManuallyLowered = false {
        didSet { updateDuck() }
    }

    /// El botón apagado mientras bajaba por otro audio: a su volumen hasta que ese audio pare
    private var ignoresOtherAudio = false {
        didSet { updateDuck() }
    }

    /// Si baja ahora por otro audio, y el panel dice por qué apps
    var isLoweredByOtherAudio: Bool { !loweredBy.isEmpty && !ignoresOtherAudio }

    /// Si suena más bajo ahora, a mano o por otro audio. El botón «Más bajo» se enciende con los dos
    var isLowered: Bool { isManuallyLowered || isLoweredByOtherAudio }

    /// El botón «Más bajo»: apagarlo vuelve al volumen elegido aunque siga el otro audio
    func toggleLowered() {
        if isLowered {
            isManuallyLowered = false
            ignoresOtherAudio = !loweredBy.isEmpty
        } else {
            ignoresOtherAudio = false
            isManuallyLowered = true
        }
    }

    /// Lo que suena de verdad: el volumen elegido, o su parte si está más bajo. La barra del panel
    /// pinta su relleno hasta aquí
    var soundingVolume: Double { isLowered ? volume * Double(AudioEngine.duckedLevel) : volume }

    /// Callada entera con el botón del panel, sin cerrar la app ni apagar las fichas. No se guarda
    var isMuted = false {
        didSet { updateMonitors() }
    }

    /// Si suena algo: el teclado, el ratón, la rueda o los botones desviados
    var isSounding: Bool { listening.isSounding }

    /// Si la ficha de Logitech está encendida y sale en el panel, que es cuando hay un ratón
    var usesLogitech: Bool { listening.usesLogitech }

    /// Si suena algo que escucha un tap y necesita el permiso de Monitorización de entrada
    var usesInputMonitoring: Bool { listening.usesInputMonitoring }

    /// Qué se escucha y qué suena ahora mismo
    private var listening: ListeningPlan {
        ListeningPlan(
            // Callada, como con todas las fichas apagadas, pero sin tocarlas: al volver, siguen igual
            toggles: isMuted ? .init() : .init(
                keyboard: isEnabled, mouse: isMouseEnabled, scroll: isScrollEnabled, logitech: isLogitechEnabled
            ),
            openSettings: openSettings,
            hasLogitechMouse: hasLogitechMouse,
            hasVibratingMouse: hasVibratingMouse,
            bluetoothPermission: bluetoothPermission,
            mouseSettings: mouseSettingsEditor.settings,
            logitechAnswered: logitech.isListening
        )
    }

    var volume: Double {
        didSet {
            defaults.set(volume, forKey: Keys.volume)
            audio.volume = Float(volume)
        }
    }

    @ObservationIgnored private let audio: AudioEngine
    /// Los grupos y las teclas cambiadas, y su ventana
    @ObservationIgnored private let keyboardSettingsEditor: KeyboardSettingsEditor
    @ObservationIgnored private let keyboard = KeyboardMonitor()
    @ObservationIgnored private let mouse = MouseMonitor()
    @ObservationIgnored private let logitech = LogitechMonitor()
    @ObservationIgnored private let updates = UpdateChecker()
    @ObservationIgnored private let otherAudio = OtherAudioMonitor()
    /// La espera antes de bajar por otro audio (ver `otherAudioDidChange`)
    @ObservationIgnored private var lowerWait: Task<Void, Never>?
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let keyboardSettingsWindow = KeyboardSettingsWindow()
    @ObservationIgnored private let mouseSettingsWindow = MouseSettingsWindow()
    /// El tono, el volumen, el timbre y la vibración de cada sonido del ratón, y su ventana
    @ObservationIgnored private lazy var mouseSettingsEditor = MouseSettingsEditor(
        defaults: .standard,
        playSample: { [weak self] in self?.audio.playSample($0) },
        vibrate: { [weak self] in self?.logitech.vibrate($0) },
        settingsDidChange: { [weak self] in self?.mouseSettingsDidChange($0) }
    )
    @ObservationIgnored private let log = Logger(subsystem: "com.yestoall.tics", category: "AppState")

    private enum Keys {
        static let enabled = "isEnabled"
        static let mouseEnabled = "isMouseEnabled"
        static let scrollEnabled = "isScrollEnabled"
        static let logitechEnabled = "isLogitechEnabled"
        static let volume = "volume"
        static let pack = "selectedPackID"
        static let menuBarIcon = "menuBarIcon"
        static let checksForUpdates = "checksForUpdates"
        static let lowersWithOtherAudio = "lowersWithOtherAudio"
        /// La receta de «Mis tics» y su id de pack, de cuando había configurador
        static let myTicsRecipe = "myTicsRecipe"
        static let myTicsPackID = "my-tics"
    }

    init() {
        let audio = AudioEngine()
        let packs = SoundPackLibrary.loadAll()
        self.audio = audio
        keyboardSettingsEditor = KeyboardSettingsEditor(
            defaults: .standard,
            playSample: { audio.playKeySample($0) },
            settingsDidChange: { audio.useKeyboardSettings($0, packs: packs) }
        )
        defaults.register(defaults: [
            Keys.enabled: true, Keys.mouseEnabled: true, Keys.scrollEnabled: true, Keys.volume: 0.65,
            Keys.pack: Self.defaultPackID, Keys.checksForUpdates: true, Keys.lowersWithOtherAudio: true,
        ])
        isEnabled = defaults.bool(forKey: Keys.enabled)
        isMouseEnabled = defaults.bool(forKey: Keys.mouseEnabled)
        isScrollEnabled = defaults.bool(forKey: Keys.scrollEnabled)
        isLogitechEnabled = defaults.bool(forKey: Keys.logitechEnabled)
        volume = defaults.double(forKey: Keys.volume)
        selectedPackID = Self.forgetMyTics(defaults, selectedPackID: defaults.string(forKey: Keys.pack))
        menuBarIcon = defaults.string(forKey: Keys.menuBarIcon).flatMap(MenuBarIcon.init) ?? .waveform
        launchAtLogin = SMAppService.mainApp.status == .enabled
        checksForUpdates = defaults.bool(forKey: Keys.checksForUpdates)
        lowersWithOtherAudio = defaults.bool(forKey: Keys.lowersWithOtherAudio)

        self.packs = packs
        audio.volume = Float(volume)
        audio.mouseSettings = mouseSettingsEditor.settings
        loadSelectedPack()
        audio.useKeyboardSettings(keyboardSettingsEditor.settings, packs: packs)
        keyboard.onKey = { [weak self] event in self?.play(event) }
        mouse.onMouse = { [weak self] event in self?.play(event) }
        logitech.onButton = { [weak self] isDown in self?.playDiverted(isDown: isDown) }
        updateMonitors()
        askPermissionAtLaunch()
        updates.onResult = { [weak self] in self?.newVersion = $0 }
        updateChecks()
        otherAudio.onChange = { [weak self] in self?.otherAudioDidChange($0) }
        updateOtherAudio()

        // Cada 2 s: mira si ya hay permiso, si los taps siguen vivos y si hay un ratón Logitech
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMonitors() }
        }
    }

    //- Teclado, ratón y permisos -

    /// Enciende o apaga cada escucha según el plan y el permiso. Los dos taps piden el mismo
    private func updateMonitors() {
        updateLogitech()
        let plan = listening
        let wantsKeyboard = plan.listensToKeyboard
        let wantsMouse = plan.listensToMouse
        if !wantsKeyboard { keyboard.stop() }
        if !wantsMouse { mouse.stop() }
        guard wantsKeyboard || wantsMouse else { return }
        guard CGPreflightListenEventAccess() else {
            permission = .missing
            return
        }
        let keyboardReady = !wantsKeyboard || keyboard.isRunning || keyboard.start()
        let mouseReady = !wantsMouse || mouse.isRunning || mouse.start()
        permission = keyboardReady && mouseReady ? .granted : .needsRelaunch
    }

    /// La conexión con los ratones Logitech, para los botones desviados y la vibración. Lo que ve
    /// IOKit y el permiso se miran aquí; qué hacer con ellos lo dice el plan
    private func updateLogitech() {
        let (hasMouse, vibrates) = LogitechMonitor.connectedMice()
        if hasMouse != hasLogitechMouse { hasLogitechMouse = hasMouse }
        if vibrates != hasVibratingMouse { hasVibratingMouse = vibrates }
        let permission = LogitechMonitor.permission
        if permission != bluetoothPermission { bluetoothPermission = permission }
        if listening.connectsLogitech {
            logitech.start()
            logitech.connectNewMice()
        } else {
            logitech.stop()
        }
        // Después de conectar: depende de si el ratón ya ha contestado
        let silences = listening.silencesOptionsPlus
        keyboard.silencesOptionsPlus = silences
        mouse.silencesOptionsPlus = silences
    }

    private func play(_ event: KeyEvent) {
        // Lo que pulsas para elegir en los ajustes del teclado no suena
        guard keyboardSettingsEditor.letsSound(event) else { return }
        audio.play(event)
    }

    private func play(_ event: MouseEvent) {
        let plan = listening
        guard plan.sounds(event, pointerOnSettings: mouseSettingsWindow.containsPointer) else { return }
        switch event {
        case let .button(button, isDown):
            audio.playClick(button, isDown: isDown)
            if isDown, let vibration = plan.vibration(for: button) { logitech.vibrate(vibration) }
        case let .dragTick(volume):
            audio.playDragTick(volume: volume)
        case .scrollTick:
            audio.playScrollTick()
        }
    }

    /// Un botón desviado, que llega por Bluetooth
    private func playDiverted(isDown: Bool) {
        let plan = listening
        guard plan.soundsDiverted else { return }
        audio.playClick(.diverted, isDown: isDown)
        if isDown, let vibration = plan.vibration(for: .diverted) { logitech.vibrate(vibration) }
    }

    /// Al abrirla sin permiso, lo pide: TICS no tiene ventana, y sin el diálogo de macOS quien la
    /// acaba de instalar no ve nada hasta dar con el icono de la barra de menús. macOS solo lo enseña
    /// la primera vez; si se deniega, queda el aviso del panel
    private func askPermissionAtLaunch() {
        let plan = listening
        guard plan.listensToKeyboard || plan.listensToMouse, !CGPreflightListenEventAccess() else { return }
        CGRequestListenEventAccess()
    }

    /// Añade Tics a la lista del permiso y abre esa pantalla de Ajustes
    func requestPermission() {
        CGRequestListenEventAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Abre la pantalla de Bluetooth de Ajustes: si se denegó, macOS ya no vuelve a preguntar
    func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Guarda el idioma y reinicia TICS, que es cuando macOS lo aplica
    func setLanguage(_ language: Language) {
        guard language != Language.current else { return }
        if let languages = language.override(system: Language.system) {
            UserDefaults.standard.set(languages, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        relaunch()
    }

    /// Cierra Tics y la vuelve a abrir medio segundo después
    func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; open \"$0\"", Bundle.main.bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    //- Packs -

    func selectPack(_ pack: SoundPack) {
        guard pack.id != selectedPackID else { return }
        selectedPackID = pack.id
        defaults.set(pack.id, forKey: Keys.pack)
        loadSelectedPack()
        audio.playPreview()
    }

    /// Cada vez que se abre el panel. El aviso del log sirve para medir lo que tarda en salir
    func panelDidOpen() {
        log.info("Panel abierto")
    }

    private func loadSelectedPack() {
        let pack = packs.first { $0.id == selectedPackID }
            ?? packs.first { $0.id == Self.defaultPackID }
            ?? packs.first
        guard let pack else {
            log.error("No hay ningún pack de sonido")
            return
        }
        do {
            try audio.load(pack)
        } catch {
            log.error("No se pudo cargar \(pack.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    //- Mis tics -

    /// «Mis tics» salía de los duelos del configurador, que ya no está (2026-10-23): se borra su
    /// receta y, si era el pack elegido, vuelve el de serie. Devuelve el pack que queda elegido
    static func forgetMyTics(_ defaults: UserDefaults, selectedPackID: String?) -> String {
        defaults.removeObject(forKey: Keys.myTicsRecipe)
        guard selectedPackID == Keys.myTicsPackID else { return selectedPackID ?? defaultPackID }
        defaults.removeObject(forKey: Keys.pack)
        return defaultPackID
    }

    //- Ajustes del teclado -

    /// Abre su ventana, o la trae delante si ya está abierta
    func openKeyboardSettings() {
        // Una ventana a la vez: estos ajustes callan el ratón, y los suyos lo necesitan sonando
        mouseSettingsWindow.close()
        if openSettings != .keyboard {
            openSettings = .keyboard
            updateMonitors()
        }
        enterDock()
        keyboardSettingsWindow.show(editor: keyboardSettingsEditor, packs: packs) { [weak self] in
            self?.keyboardSettingsDidClose()
        }
    }

    private func keyboardSettingsDidClose() {
        if openSettings == .keyboard { openSettings = nil }
        leaveDockIfNoSettings()
        keyboardSettingsEditor.endEditing()
        updateMonitors()
    }

    //- Ajustes del ratón -

    /// Abre su ventana, o la trae delante si ya está abierta
    func openMouseSettings() {
        keyboardSettingsWindow.close()
        if openSettings != .mouse {
            openSettings = .mouse
            updateMonitors()
        }
        enterDock()
        mouseSettingsWindow.show(editor: mouseSettingsEditor, state: self) { [weak self] in
            self?.mouseSettingsDidClose()
        }
    }

    private func mouseSettingsDidClose() {
        if openSettings == .mouse { openSettings = nil }
        leaveDockIfNoSettings()
        updateMonitors()
    }

    /// Con cada cambio guardado: rehace los clics, y abre o cierra la conexión con el ratón si
    /// ahora hace falta o no para vibrar
    private func mouseSettingsDidChange(_ settings: MouseSettings) {
        audio.mouseSettings = settings
        updateMonitors()
    }

    //- El Dock -

    /// Con una ventana de ajustes abierta, TICS sale en el Dock y en ⌘Tab, y su nombre en la barra de
    /// menús de macOS, como cualquier app: sin eso, la ventana no dice de quién es
    private func enterDock() {
        NSApp.setActivationPolicy(.regular)
    }

    /// Al cerrar la última. Un momento después: al pasar de una ventana a la otra, la primera se
    /// cierra antes de que se abra la segunda, y el icono saldría y entraría del Dock
    private func leaveDockIfNoSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self, openSettings == nil else { return }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    //- Abrir al iniciar sesión -

    func setLaunchAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Abrir al iniciar sesión: \(error.localizedDescription, privacy: .public)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    //- Versión nueva -

    private func updateChecks() {
        if checksForUpdates, let current = AppVersion.current {
            updates.start(current: current)
        } else {
            updates.stop()
            newVersion = nil
        }
    }

    /// Baja el .dmg de la última versión con el navegador
    func downloadUpdate() {
        NSWorkspace.shared.open(UpdateChecker.downloadURL)
    }

    //- Más bajo con otro audio -

    /// Si este Mac puede saber qué apps tienen la salida abierta (macOS 14.2): si no, no sale el interruptor
    var canLowerWithOtherAudio: Bool { OtherAudioMonitor.isAvailable }

    private func updateOtherAudio() {
        if lowersWithOtherAudio {
            otherAudio.start()
        } else {
            otherAudio.stop()
            otherAudioDidChange([])
        }
    }

    /// Lo que tiene que durar otro audio para que TICS baje: un aviso (afplay, un mensaje) dura
    /// un segundo o dos, y bajar por él se notaba como un bache
    static let lowerDelay: Duration = .seconds(2)

    /// Baja cuando otra app lleva `lowerDelay` con la salida abierta y vuelve en cuanto la cierran
    /// todas. Al volver no espera: Dia, por ejemplo, ya la deja abierta unos 20 s tras pausar, y eso
    /// cubre los huecos entre canción y canción
    private func otherAudioDidChange(_ apps: [String]) {
        lowerWait?.cancel()
        lowerWait = nil
        // Ya más bajo, o volviendo: al momento. Lo que cambia es solo empezar a bajar
        guard loweredBy.isEmpty, !apps.isEmpty else {
            loweredBy = apps
            // Parado el otro audio, el botón apagado ya no lo ignora: con el siguiente, vuelve a bajar
            if apps.isEmpty { ignoresOtherAudio = false }
            updateDuck()
            return
        }
        lowerWait = Task { [weak self] in
            try? await Task.sleep(for: Self.lowerDelay)
            guard !Task.isCancelled, let self else { return }
            loweredBy = apps
            updateDuck()
        }
    }

    private func updateDuck() {
        audio.duck(isLowered)
    }
}
