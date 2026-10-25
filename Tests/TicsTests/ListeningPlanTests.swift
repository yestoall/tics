//· ListeningPlanTests ·
// Qué se escucha y qué suena según las fichas, la ventana de ajustes abierta, el ratón Logitech y
// sus permisos. Sin taps ni Bluetooth: solo el plan

import Testing
@testable import Tics

@Test func conTodoApagadoNoSeEscuchaNiSuenaNada() {
    let plan = ListeningPlan()
    #expect(!plan.listensToKeyboard)
    #expect(!plan.listensToMouse)
    #expect(!plan.connectsLogitech)
    #expect(!plan.isSounding)
    #expect(!plan.sounds(.button(.left, isDown: true)))
    #expect(!plan.soundsDiverted)
}

//- Las ventanas de ajustes -

@Test func conLosAjustesDelTecladoSeEscuchaElTecladoYCallaElRaton() {
    var plan = ListeningPlan()
    plan.toggles = .init(keyboard: false, mouse: true, scroll: true, logitech: true)
    plan.hasLogitechMouse = true
    plan.openSettings = .keyboard
    #expect(plan.listensToKeyboard)
    #expect(!plan.listensToMouse)
    #expect(!plan.connectsLogitech)
}

@Test func conLosAjustesDelRatonSuenaTodoElRatonConSusFichasApagadas() {
    var plan = ListeningPlan()
    plan.hasLogitechMouse = true
    plan.toggles.logitech = false
    plan.openSettings = .mouse
    #expect(plan.listensToMouse)
    #expect(plan.sounds(.button(.right, isDown: true)))
    #expect(plan.sounds(.dragTick(volume: 1)))
    #expect(plan.sounds(.scrollTick))
    #expect(plan.soundsDiverted)
    #expect(!plan.listensToKeyboard)
}

@Test func conElPunteroSobreLosAjustesDelRatonNoSuenaNada() {
    var plan = ListeningPlan()
    plan.openSettings = .mouse
    #expect(!plan.sounds(.button(.left, isDown: true), pointerOnSettings: true))
    #expect(!plan.sounds(.scrollTick, pointerOnSettings: true))
    // Con la ventana cerrada, el puntero no cuenta
    plan.openSettings = nil
    plan.toggles.mouse = true
    #expect(plan.sounds(.button(.left, isDown: true), pointerOnSettings: true))
}

@Test func conSoloLaRuedaSeEscuchaElRatonPeroLosClicsNoSuenan() {
    var plan = ListeningPlan()
    plan.toggles.scroll = true
    #expect(plan.listensToMouse)
    #expect(plan.sounds(.scrollTick))
    #expect(!plan.sounds(.button(.left, isDown: true)))
    #expect(!plan.sounds(.dragTick(volume: 1)))
}

//- Logitech -

@Test func logitechSeConectaConSuFichaYUnRaton() {
    var plan = ListeningPlan()
    plan.toggles.logitech = true
    #expect(!plan.connectsLogitech)
    plan.hasLogitechMouse = true
    #expect(plan.connectsLogitech)
    #expect(plan.soundsDiverted)
    plan.bluetoothPermission = .denied
    #expect(!plan.connectsLogitech)
}

@Test func logitechSeConectaSoloParaVibrarSinQueSuenenLosDesviados() {
    var plan = ListeningPlan()
    plan.hasLogitechMouse = true
    plan.hasVibratingMouse = true
    plan.mouseSettings[.left].vibration = .tap
    #expect(plan.connectsLogitech)
    #expect(!plan.soundsDiverted)
    // Un ratón que no vibra no necesita la conexión
    plan.hasVibratingMouse = false
    #expect(!plan.connectsLogitech)
}

//- El panel -

@Test func conSoloLogitechYBluetoothDenegadoNoSuenaNada() {
    var plan = ListeningPlan()
    plan.toggles.logitech = true
    plan.hasLogitechMouse = true
    #expect(plan.isSounding)
    #expect(!plan.usesInputMonitoring)
    plan.bluetoothPermission = .denied
    #expect(!plan.isSounding)
}

@Test func optionsPlusSoloSeCallaSiElRatonYaContestoYSuenanLosDesviados() {
    var plan = ListeningPlan()
    plan.toggles.logitech = true
    plan.hasLogitechMouse = true
    #expect(!plan.silencesOptionsPlus)
    plan.logitechAnswered = true
    #expect(plan.silencesOptionsPlus)
    // Abierta solo para vibrar: Options+ sigue haciendo lo suyo y sonando
    plan.toggles.logitech = false
    plan.hasVibratingMouse = true
    plan.mouseSettings[.left].vibration = .tap
    #expect(!plan.silencesOptionsPlus)
}

//- Vibración -

@Test func vibraUnBotonQueSuenaYTieneVibracion() {
    var plan = ListeningPlan()
    plan.toggles.mouse = true
    plan.mouseSettings[.left].vibration = .knock
    #expect(plan.vibration(for: .left) == .knock)
    #expect(plan.vibration(for: .right) == nil)
    // Si el botón no suena, tampoco vibra
    plan.toggles.mouse = false
    #expect(plan.vibration(for: .left) == nil)
}

@Test func unDesviadoVibraSiSuena() {
    var plan = ListeningPlan()
    plan.mouseSettings[.diverted].vibration = .wave
    #expect(plan.vibration(for: .diverted) == nil)
    plan.toggles.logitech = true
    plan.hasLogitechMouse = true
    #expect(plan.vibration(for: .diverted) == .wave)
}
