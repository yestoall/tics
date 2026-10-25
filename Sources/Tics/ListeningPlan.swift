//· ListeningPlan ·
// Qué se escucha y qué suena ahora mismo, según las fichas del panel, la ventana de ajustes que haya
// abierta, el ratón Logitech y sus permisos. Es solo un cálculo: AppState lo hace cada vez que lo
// necesita y enciende o apaga las escuchas según diga.
//
// Con los ajustes del teclado abiertos, el teclado suena siempre y el ratón calla; con los del
// ratón, todo el ratón suena, con sus fichas como estén.

struct ListeningPlan {
    /// Las fichas del panel
    struct Toggles {
        var keyboard = false
        var mouse = false
        var scroll = false
        var logitech = false
    }

    /// Solo hay una abierta a la vez
    enum SettingsWindow {
        case keyboard
        case mouse
    }

    var toggles = Toggles()
    var openSettings: SettingsWindow?
    /// Si hay un ratón Logitech conectado por Bluetooth
    var hasLogitechMouse = false
    /// Si ese ratón vibra
    var hasVibratingMouse = false
    var bluetoothPermission: LogitechMonitor.Permission = .notAsked
    var mouseSettings = MouseSettings()
    /// Si un ratón Logitech ya ha contestado por la conexión: hasta entonces, sus botones desviados
    /// no sonarían por ningún lado
    var logitechAnswered = false

    //- Escuchas -

    var listensToKeyboard: Bool { toggles.keyboard || openSettings == .keyboard }

    /// Un solo tap para el ratón y la rueda: basta con que suene uno de los dos
    var listensToMouse: Bool {
        (toggles.mouse || toggles.scroll || openSettings == .mouse) && openSettings != .keyboard
    }

    /// La conexión con el ratón Logitech: para el sonido de los desviados o, aunque esa ficha esté
    /// apagada, para vibrar. Si aún no se ha preguntado el permiso, conectar lo pregunta
    var connectsLogitech: Bool {
        let wanted = usesLogitech || (openSettings == .mouse && toggles.logitech && hasLogitechMouse)
            || (wantsVibration && hasVibratingMouse)
        return wanted && bluetoothPermission != .denied && openSettings != .keyboard
    }

    /// Mientras los desviados suenan como botones, se callan los clics y las teclas que inyecta
    /// Options+ al hacer su función: si no, sonarían dos veces. Solo con un ratón que ya ha
    /// contestado, y no si la conexión está abierta solo para vibrar
    var silencesOptionsPlus: Bool { logitechAnswered && soundsDiverted }

    //- El panel -

    /// Si suena algo: el teclado, el ratón, la rueda o los botones desviados
    var isSounding: Bool { usesInputMonitoring || (usesLogitech && bluetoothPermission != .denied) }

    /// Si la ficha de Logitech está encendida y sale en el panel, que es cuando hay un ratón
    var usesLogitech: Bool { toggles.logitech && hasLogitechMouse }

    /// Si suena algo que escucha un tap y necesita el permiso de Monitorización de entrada
    var usesInputMonitoring: Bool { toggles.keyboard || toggles.mouse || toggles.scroll }

    //- Eventos -

    /// Si suena un evento del ratón. En la ventana de sus ajustes, tocar un slider no suena: suena
    /// su muestra al soltarlo
    func sounds(_ event: MouseEvent, pointerOnSettings: Bool = false) -> Bool {
        if openSettings == .mouse && pointerOnSettings { return false }
        switch event {
        case .button, .dragTick: return toggles.mouse || openSettings == .mouse
        case .scrollTick: return toggles.scroll || openSettings == .mouse
        }
    }

    /// Un botón desviado, que llega por Bluetooth: suena con la ficha «Logitech» o con los ajustes
    /// del ratón abiertos. La conexión puede estar abierta solo para vibrar
    var soundsDiverted: Bool { usesLogitech || openSettings == .mouse }

    //- Vibración -

    /// La vibración de un botón al pulsarlo, si suena y tiene una elegida
    func vibration(for button: MouseButton) -> Vibration? {
        let sounds = button == .diverted ? soundsDiverted : sounds(.button(button, isDown: true))
        guard sounds, let sound = MouseSound.allCases.first(where: { $0.button == button }) else {
            return nil
        }
        let vibration = mouseSettings[sound].vibration
        return vibration == .none ? nil : vibration
    }

    /// Si algún botón tiene una vibración elegida: entonces hace falta la conexión con el ratón
    private var wantsVibration: Bool {
        MouseSound.allCases.contains { $0.button != nil && mouseSettings[$0].vibration != .none }
    }
}
